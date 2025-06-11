import AppKit
import Foundation

class AeroSpacePipeMonitor {
    weak var aeroSpaceManager: AeroSpaceManager?
    private let pipePath = "/tmp/aerobar_workspace_pipe"
    private var pipeHandle: FileHandle?
    private let backgroundQueue = DispatchQueue(label: "pipe.monitor", qos: .userInitiated)

    init() {
        setupPipe()
        startMonitoring()
    }

    deinit {
        cleanup()
    }

    private func setupPipe() {
        // Remove existing pipe if it exists
        if FileManager.default.fileExists(atPath: pipePath) {
            try? FileManager.default.removeItem(atPath: pipePath)
        }

        // Create named pipe (FIFO)
        let result = mkfifo(pipePath, 0o644)
        if result == 0 {
            print("📡 Created AeroSpace communication pipe at \(pipePath)")
        } else {
            print("⚠️ Failed to create pipe, error: \(result)")
        }
    }

    private func startMonitoring() {
        backgroundQueue.async {
            self.monitorPipe()
        }
        print("🚀 AeroSpace pipe monitoring started - workspace detection active!")
    }

    private func monitorPipe() {
        guard let pipeHandle = FileHandle(forReadingAtPath: pipePath) else {
            print("❌ Failed to open pipe for reading")
            return
        }

        self.pipeHandle = pipeHandle

        // Monitor for data
        pipeHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            if data.count > 0 {
                if let message = String(data: data, encoding: .utf8) {
                    self?.handlePipeMessage(message.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        print("📡 Pipe monitoring active - waiting for AeroSpace callbacks...")
    }

    private func handlePipeMessage(_ message: String) {
        let components = message.components(separatedBy: ":")

        if components.count >= 3 && components[0] == "WORKSPACE_CHANGE" {
            let newWorkspace = components[1]
            let prevWorkspace = components[2]

            print("⚡ workspace change detected: \(prevWorkspace) → \(newWorkspace)")

            DispatchQueue.main.async {
                self.aeroSpaceManager?.handleInstantWorkspaceChange(
                    newWorkspace, from: prevWorkspace)
            }
        }
    }

    private func cleanup() {
        pipeHandle?.readabilityHandler = nil
        pipeHandle?.closeFile()

        // Clean up pipe file
        if FileManager.default.fileExists(atPath: pipePath) {
            try? FileManager.default.removeItem(atPath: pipePath)
        }

        print("📡 Pipe monitoring stopped")
    }
}
