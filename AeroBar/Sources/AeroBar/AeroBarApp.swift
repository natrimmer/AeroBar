import AppKit
import Combine
import Foundation
import SwiftUI

@main
struct AeroBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

func handleAeroSpaceCallback() {
    guard let focusedWorkspace = ProcessInfo.processInfo.environment["AEROSPACE_FOCUSED_WORKSPACE"],
        let prevWorkspace = ProcessInfo.processInfo.environment["AEROSPACE_PREV_WORKSPACE"]
    else {
        return
    }

    let pipePath = "/tmp/aerobar_workspace_pipe"
    let message = "WORKSPACE_CHANGE:\(focusedWorkspace):\(prevWorkspace)"

    // Send to pipe if it exists
    if FileManager.default.fileExists(atPath: pipePath) {
        do {
            try message.write(toFile: pipePath, atomically: false, encoding: .utf8)
        } catch {
            // Silently fail - AeroBar might not be running
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindow: OverlayWindow?
    var aeroSpaceManager: AeroSpaceManager?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Handle CLI arguments
        if CommandLine.arguments.contains("--help") {
            print("AeroBar - Configurable status bar for AeroSpace")
            print("Usage: aerobar [options]")
            print("  --help    Show this help")
            print("  --version Show version")
            print("  --callback Handle AeroSpace callback (internal use)")
            NSApp.terminate(nil)
            return
        }

        if CommandLine.arguments.contains("--version") {
            print("AeroBar 1.0.0")
            NSApp.terminate(nil)
            return
        }

        if CommandLine.arguments.contains("--callback") {
            handleAeroSpaceCallback()
            NSApp.terminate(nil)
            return
        }

        // Set high performance mode
        ProcessInfo.processInfo.disableSuddenTermination()

        // Initialize AeroSpace manager
        aeroSpaceManager = AeroSpaceManager()

        // Set initial update interval from settings (default 2 seconds for better performance)
        let updateInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        aeroSpaceManager?.setUpdateInterval(updateInterval > 0 ? updateInterval : 1.5)

        // Create status bar item
        setupStatusBar()

        // Create overlay window
        setupOverlayWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProcessInfo.processInfo.enableSuddenTermination()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusBarTitle()
            // Remove direct action - let menu handle everything
            button.action = nil
            button.target = nil

            // Create menu
            let menu = NSMenu()
            menu.addItem(
                NSMenuItem(
                    title: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "")
            )
            menu.addItem(
                NSMenuItem(
                    title: "Force Refresh", action: #selector(forceRefresh), keyEquivalent: "r"))
            menu.addItem(
                NSMenuItem(
                    title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "l"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(
                NSMenuItem(
                    title: "Edit Config", action: #selector(openConfig), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(
                NSMenuItem(title: "Quit AeroBar", action: #selector(quitApp), keyEquivalent: "q"))

            // Set menu as default - no need for right-click
            statusItem?.menu = menu
        }
    }

    private func setupOverlayWindow() {
        overlayWindow = OverlayWindow()
        overlayWindow?.aeroSpaceManager = aeroSpaceManager
        overlayWindow?.updateContentView()
        overlayWindow?.makeKeyAndOrderFront(nil)
        overlayWindow?.level = .floating
        
        // Update status bar when workspace changes
        aeroSpaceManager?.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusBarTitle()
            }
        }.store(in: &cancellables)
    }
    
    private func updateStatusBarTitle() {
        guard let button = statusItem?.button,
              let currentWorkspace = aeroSpaceManager?.currentWorkspace else { return }
        
        // Create boxed number
        let boxedNumber = "[\(currentWorkspace)]"
        button.title = boxedNumber
    }

    @objc private func toggleOverlay() {
        overlayWindow?.toggleVisibility()
    }

    @objc private func forceRefresh() {
        aeroSpaceManager?.forceUpdate()
    }

    @objc private func reloadConfig() {
        // Reload config and update UI
        aeroSpaceManager?.config = AeroBarConfigLoader.shared.loadConfig()
        overlayWindow?.updateContentView()
        print("✅ Configuration reloaded")
    }

    @objc private func openConfig() {
        let configPath = NSHomeDirectory() + "/.aerobar.toml"
        
        // Create config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configPath) {
            _ = AeroBarConfigLoader.shared.loadConfig()
        }
        
        // Use system default editor
        NSWorkspace.shared.open(URL(fileURLWithPath: configPath))
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
