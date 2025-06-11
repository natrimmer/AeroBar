import AppKit
import Foundation

class AeroSpaceManager: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var currentWorkspace: String = ""
    @Published var windows: [WindowInfo] = []
    @Published var config: AeroBarConfig

    private var updateTimer: Timer?
    private var lastUpdateTime: Date = Date.distantPast
    private let minimumUpdateInterval: TimeInterval = 1.0
    private let backgroundQueue = DispatchQueue(label: "aerobar.background", qos: .userInitiated)

    // Optimistic state tracking
    private var pendingWorkspaceSwitch: String?
    private var pendingWindowFocus: String?
    private var pendingWindowMove: String?

    // Instant AeroSpace communication via pipe
    private var pipeMonitor: AeroSpacePipeMonitor?

    // Cache for aerospace binary path
    private var aerospacePath: String = "/opt/homebrew/bin/aerospace"

    init() {
        // Load configuration first
        self.config = AeroBarConfigLoader.shared.loadConfig()
        
        // Use config aerospace path
        self.aerospacePath = config.aerospacePath
        // Faster updates with rapid detection - 3 seconds
        startPeriodicUpdates(interval: 3.0)
        updateDataAsync()

        // Setup instant AeroSpace communication
        pipeMonitor = AeroSpacePipeMonitor()
        pipeMonitor?.aeroSpaceManager = self
    }

    // INSTANT AEROSPACE COMMUNICATION
    func handleInstantWorkspaceChange(_ newWorkspace: String, from prevWorkspace: String) {
        // Only update if it's actually different from our current state
        guard newWorkspace != currentWorkspace else { return }

        // Perform optimistic update immediately
        performOptimisticWorkspaceSwitch(newWorkspace)

        // Schedule immediate window data sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.updateDataAsync()
        }
    }

    // WORKSPACE CHANGE DETECTION
    func handleDetectedWorkspaceChange(_ newWorkspace: String) {
        // Only update if it's actually different from our current state
        guard newWorkspace != currentWorkspace else { return }

        // Perform optimistic update immediately
        performOptimisticWorkspaceSwitch(newWorkspace)

        // Schedule immediate data refresh to sync window info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            self.updateDataAsync()
        }
    }

    deinit {
        updateTimer?.invalidate()
    }

    private func findAerospaceBinary() {
        let possiblePaths = [
            "/opt/homebrew/bin/aerospace",
            "/usr/local/bin/aerospace",
            "/usr/bin/aerospace",
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                aerospacePath = path
                return
            }
        }
    }

    func startPeriodicUpdates(interval: TimeInterval = 1.5) {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.updateDataAsync()
        }
    }

    func updateDataAsync() {
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval else { return }

        lastUpdateTime = now

        backgroundQueue.async {
            self.performUpdate()
        }
    }

    private func performUpdate() {
        // Fetch real data
        let newCurrentWorkspace = fetchCurrentWorkspace()
        let (newWorkspaces, newWindows) = fetchWorkspacesAndWindows(
            currentWorkspace: newCurrentWorkspace)

        // Update UI on main thread
        DispatchQueue.main.async {
            self.currentWorkspace = newCurrentWorkspace
            self.workspaces = newWorkspaces
            self.windows = newWindows

            // Clear optimistic state after real update
            self.pendingWorkspaceSwitch = nil
            self.pendingWindowFocus = nil
            self.pendingWindowMove = nil
        }
    }

    private func fetchCurrentWorkspace() -> String {
        runAeroSpaceCommand(["list-workspaces", "--focused"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fetchWorkspacesAndWindows(currentWorkspace: String) -> ([Workspace], [WindowInfo])
    {
        // Get all workspaces
        let workspaceOutput = runAeroSpaceCommand(["list-workspaces", "--all"])
        let workspaceNames = workspaceOutput.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        // Get all windows in one call
        let windowOutput = runAeroSpaceCommand([
            "list-windows", "--all",
            "--format", "%{window-id}|%{app-name}|%{window-title}|%{workspace}",
        ])

        let windows = windowOutput.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line -> WindowInfo? in
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 4 else { return nil }

                return WindowInfo(
                    id: parts[0],
                    appName: parts[1],
                    title: parts[2],
                    workspace: parts[3]
                )
            }

        // Count windows per workspace
        let windowCounts = Dictionary(grouping: windows, by: { $0.workspace })
            .mapValues { $0.count }

        let workspaces = workspaceNames.map { name in
            Workspace(
                name: name,
                windowCount: windowCounts[name] ?? 0,
                isActive: name == currentWorkspace
            )
        }

        return (workspaces, windows)
    }

    private func runAeroSpaceCommand(_ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: aerospacePath)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    // OPTIMISTIC UI UPDATES
    func switchToWorkspace(_ workspace: String) {
        // Immediate optimistic update
        performOptimisticWorkspaceSwitch(workspace)

        // Execute command in background
        backgroundQueue.async {
            _ = self.runAeroSpaceCommand(["workspace", workspace])

            // Schedule quick verification update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateDataAsync()
            }
        }
    }

    func focusWindow(_ windowId: String) {
        // Find the window and switch workspace optimistically
        if let window = windows.first(where: { $0.id == windowId }) {
            performOptimisticWindowFocus(windowId, workspace: window.workspace)
        }

        // Execute command in background
        backgroundQueue.async {
            _ = self.runAeroSpaceCommand(["focus", "--window-id", windowId])

            // Schedule quick verification update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateDataAsync()
            }
        }
    }

    private func performOptimisticWorkspaceSwitch(_ targetWorkspace: String) {
        pendingWorkspaceSwitch = targetWorkspace

        // Update current workspace immediately
        currentWorkspace = targetWorkspace

        // Update workspace active states
        workspaces = workspaces.map { workspace in
            Workspace(
                name: workspace.name,
                windowCount: workspace.windowCount,
                isActive: workspace.name == targetWorkspace
            )
        }
    }

    private func performOptimisticWindowFocus(_ windowId: String, workspace: String) {
        pendingWindowFocus = windowId

        // If window is in different workspace, switch there first
        if workspace != currentWorkspace {
            performOptimisticWorkspaceSwitch(workspace)
        }
    }

    // Public methods for UI
    func forceUpdate() {
        lastUpdateTime = Date.distantPast
        updateDataAsync()
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        startPeriodicUpdates(interval: max(0.5, interval))
    }

    // Get optimistic state for UI
    var optimisticCurrentWorkspace: String {
        return pendingWorkspaceSwitch ?? currentWorkspace
    }

    var optimisticWorkspaces: [Workspace] {
        if let pending = pendingWorkspaceSwitch {
            return workspaces.map { workspace in
                Workspace(
                    name: workspace.name,
                    windowCount: workspace.windowCount,
                    isActive: workspace.name == pending
                )
            }
        }
        return workspaces
    }
}

struct Workspace: Hashable {
    let name: String
    let windowCount: Int
    let isActive: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.name == rhs.name && lhs.windowCount == rhs.windowCount && lhs.isActive == rhs.isActive
    }
}

struct WindowInfo: Identifiable, Hashable {
    let id: String
    let appName: String
    let title: String
    let workspace: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id && lhs.appName == rhs.appName && lhs.workspace == rhs.workspace
    }
}
