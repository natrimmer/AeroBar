import SwiftUI
import AppKit

class OverlayWindow: NSWindow {
    var aeroSpaceManager: AeroSpaceManager?
    private var overlayVisible = true
    
    init() {
        // Initial size - will be updated with config
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 32),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isOpaque = false
        self.ignoresMouseEvents = false
        self.canHide = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.allowsConcurrentViewDrawing = true
        
        // Additional optimizations for overlay window
        self.isMovableByWindowBackground = false
        self.acceptsMouseMovedEvents = true
        
        setupContentView()
    }
    
    private func setupContentView() {
        if let manager = aeroSpaceManager {
            let hostingView = NSHostingView(rootView: ConfigurableAeroBarView(aeroSpaceManager: manager))
            self.contentView = hostingView
            positionWindow(with: manager.config)
        }
    }
    
    func updateContentView() {
        guard let manager = aeroSpaceManager else { return }
        let hostingView = NSHostingView(rootView: ConfigurableAeroBarView(aeroSpaceManager: manager))
        self.contentView = hostingView
        positionWindow(with: manager.config)
    }
    
    private func positionWindow(with config: AeroBarConfig) {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let barSize = calculateBarSize(config: config, screenFrame: screenFrame)
        
        let position = calculatePosition(config: config, screenFrame: screenFrame, barSize: barSize)
        
        print("📍 Positioning bar: \(config.position.rawValue), frame: \(NSRect(x: position.x, y: position.y, width: barSize.width, height: barSize.height))")
        
        self.setFrame(NSRect(x: position.x, y: position.y, width: barSize.width, height: barSize.height), display: true)
    }
    
    private func calculateBarSize(config: AeroBarConfig, screenFrame: NSRect) -> NSSize {
        switch config.orientation {
        case .horizontal:
            return NSSize(width: screenFrame.width, height: config.barHeight)
        case .vertical:
            return NSSize(width: config.barHeight, height: screenFrame.height)
        }
    }
    
    private func calculatePosition(config: AeroBarConfig, screenFrame: NSRect, barSize: NSSize) -> NSPoint {
        switch config.position {
        case .top:
            return NSPoint(x: screenFrame.minX, y: screenFrame.maxY - barSize.height)
        case .bottom:
            return NSPoint(x: screenFrame.minX, y: screenFrame.minY)
        case .left:
            return NSPoint(x: screenFrame.minX, y: screenFrame.minY)
        case .right:
            return NSPoint(x: screenFrame.maxX - barSize.width, y: screenFrame.minY)
        }
    }
    
    func toggleVisibility() {
        overlayVisible.toggle()
        if overlayVisible {
            self.orderFront(nil)
        } else {
            self.orderOut(nil)
        }
    }
}

struct ConfigurableAeroBarView: View {
    @ObservedObject var aeroSpaceManager: AeroSpaceManager
    
    var body: some View {
        let config = aeroSpaceManager.config
        
        VStack(spacing: 0) {
            // Simple error indicator (just a thin red line if errors exist)
            if !config.configErrors.isEmpty {
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
            }
            
            // Main bar content
            Group {
                if config.orientation == .horizontal {
                    HorizontalBarView(aeroSpaceManager: aeroSpaceManager, config: config)
                } else {
                    VerticalBarView(aeroSpaceManager: aeroSpaceManager, config: config)
                }
            }
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial.opacity(config.barOpacity))
                    .overlay(
                        Rectangle()
                            .stroke(config.borderColor.opacity(0.1), lineWidth: 0.5)
                            .blur(radius: 0.5)
                    )
            )
            
            // Bottom border (tab-like effect)
            if config.showBottomBorder {
                Rectangle()
                    .fill(config.bottomBorderColor)
                    .frame(height: config.bottomBorderHeight)
            }
        }
    }
}

struct HorizontalBarView: View {
    @ObservedObject var aeroSpaceManager: AeroSpaceManager
    let config: AeroBarConfig
    
    var body: some View {
        HStack(spacing: 0) {
            // Left padding
            Spacer().frame(width: config.finalPaddingLeft)
            
            // Workspace items
            HStack(spacing: 4) {
                ForEach(aeroSpaceManager.workspaces, id: \.name) { workspace in
                    ConfigurableWorkspaceItem(
                        workspace: workspace,
                        windows: aeroSpaceManager.windows.filter { $0.workspace == workspace.name },
                        config: config
                    ) {
                        aeroSpaceManager.switchToWorkspace(workspace.name)
                    }
                }
            }
            
            // Active window title (if enabled)
            if config.displayActiveWindowTitle {
                Spacer()
                ActiveWindowTitle(aeroSpaceManager: aeroSpaceManager, config: config)
                    .padding(.trailing, 12)
            } else {
                // Fill remaining space
                Spacer()
            }
            
            // Right padding  
            Spacer().frame(width: config.finalPaddingRight)
        }
        .frame(maxWidth: .infinity)
        .frame(height: config.barHeight)
        .padding(.top, config.finalPaddingTop)
        .padding(.bottom, config.finalPaddingBottom)
    }
}

struct VerticalBarView: View {
    @ObservedObject var aeroSpaceManager: AeroSpaceManager
    let config: AeroBarConfig
    
    var body: some View {
        VStack(spacing: 0) {
            // Top padding
            Spacer().frame(height: config.finalPaddingTop)
            
            // Workspace items
            VStack(spacing: 4) {
                ForEach(aeroSpaceManager.workspaces, id: \.name) { workspace in
                    ConfigurableWorkspaceItem(
                        workspace: workspace,
                        windows: aeroSpaceManager.windows.filter { $0.workspace == workspace.name },
                        config: config
                    ) {
                        aeroSpaceManager.switchToWorkspace(workspace.name)
                    }
                }
            }
            
            // Fill remaining space
            Spacer()
            
            // Active window title (if enabled and vertical has space)
            if config.displayActiveWindowTitle {
                ActiveWindowTitle(aeroSpaceManager: aeroSpaceManager, config: config)
                    .rotationEffect(.degrees(-90))
                    .padding(.bottom, 12)
            }
            
            // Bottom padding  
            Spacer().frame(height: config.finalPaddingBottom)
        }
        .frame(maxHeight: .infinity)
        .frame(width: config.barHeight)
        .padding(.leading, config.finalPaddingLeft)
        .padding(.trailing, config.finalPaddingRight)
    }
}

struct ActiveWindowTitle: View {
    @ObservedObject var aeroSpaceManager: AeroSpaceManager
    let config: AeroBarConfig
    
    var activeWindow: WindowInfo? {
        // Find the focused window in the current workspace
        aeroSpaceManager.windows.first { window in
            window.workspace == aeroSpaceManager.currentWorkspace
        }
    }
    
    var body: some View {
        if let window = activeWindow, !window.title.isEmpty {
            Text(window.title)
                .font(.custom(config.fontFamily, size: config.appFontSize))
                .foregroundColor(config.textActiveColor.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, config.finalPaddingLeft / 2)
        }
    }
}

struct ConfigurableWorkspaceItem: View {
    let workspace: Workspace
    let windows: [WindowInfo]
    let config: AeroBarConfig
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: config.animationDuration)) {
                isPressed = true
            }
            onTap()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + config.animationDuration) {
                withAnimation(.easeOut(duration: config.animationDuration)) {
                    isPressed = false
                }
            }
        }) {
            workspaceContent
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: config.hoverDelay)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var workspaceContent: some View {
        if config.orientation == .horizontal {
            HStack(spacing: 6) {
                workspaceIndicator
                appDisplay
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundShape)
        } else {
            VStack(spacing: 4) {
                workspaceIndicator
                if !windows.isEmpty && config.showAppDots {
                    Circle()
                        .fill(config.workspaceActiveColor.opacity(workspace.isActive ? 0.8 : 0.4))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(6)
            .background(backgroundShape)
        }
    }
    
    private var workspaceIndicator: some View {
        Text(workspace.name)
            .font(.custom(config.fontFamily, size: config.fontSize))
            .fontWeight(workspace.isActive ? .semibold : .medium)
            .foregroundColor(workspace.isActive ? config.textActiveColor : config.textInactiveColor)
            .frame(minWidth: 20, minHeight: 20)
    }
    
    @ViewBuilder
    private var appDisplay: some View {
        if config.orientation == .horizontal {
            // Show app names based on config and state
            let shouldShowNames = config.displayAllWindowTitles || 
                                (workspace.isActive && config.autoDisplayWindowTitles) || 
                                isHovered
            
            if shouldShowNames {
                if !windows.isEmpty {
                    ConfigurableAppNames(windows: windows, config: config, isActive: workspace.isActive)
                }
            } else if !windows.isEmpty && config.showAppDots {
                ConfigurableAppDots(windows: windows, config: config, isActive: workspace.isActive)
            }
        }
    }
    
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: config.cornerRadius)
            .fill(backgroundGradient)
            .overlay(
                RoundedRectangle(cornerRadius: config.cornerRadius)
                    .stroke(borderColor, lineWidth: workspace.isActive ? 1 : 0.5)
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
            .shadow(
                color: workspace.isActive ? config.shadowColor.opacity(0.3) : .clear,
                radius: workspace.isActive ? 3 : 0
            )
    }
    
    private var backgroundGradient: LinearGradient {
        if workspace.isActive {
            return LinearGradient(
                colors: [
                    config.workspaceActiveColor.opacity(0.4),
                    config.workspaceActiveColor.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    config.workspaceInactiveColor.opacity(isHovered ? 0.12 : 0.06),
                    config.workspaceInactiveColor.opacity(isHovered ? 0.08 : 0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var borderColor: Color {
        if workspace.isActive {
            return config.workspaceActiveColor.opacity(0.6)
        } else {
            return config.borderColor.opacity(isHovered ? 0.2 : 0.1)
        }
    }
}

struct ConfigurableAppNames: View {
    let windows: [WindowInfo]
    let config: AeroBarConfig
    let isActive: Bool
    
    private var maxApps: Int {
        isActive ? config.maxAppsActive : config.maxAppsInactive
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(windows.count, maxApps), id: \.self) { index in
                Text(windows[index].appName)
                    .font(.custom(config.fontFamily, size: config.appFontSize))
                    .fontWeight(isActive ? .semibold : .medium)
                    .foregroundColor(isActive ? config.textActiveColor : config.textInactiveColor)
                    .padding(.horizontal, isActive ? 5 : 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(config.workspaceInactiveColor.opacity(isActive ? 0.2 : 0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(
                                        isActive ? config.workspaceActiveColor.opacity(0.3) : Color.clear,
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            // Overflow indicator
            if windows.count > maxApps {
                Text("+\(windows.count - maxApps)")
                    .font(.custom(config.fontFamily, size: config.appFontSize - 1))
                    .fontWeight(.medium)
                    .foregroundColor(config.textInactiveColor)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(config.workspaceInactiveColor.opacity(0.1))
                    )
            }
        }
    }
}

struct ConfigurableAppDots: View {
    let windows: [WindowInfo]
    let config: AeroBarConfig
    let isActive: Bool
    
    private let maxDots = 5
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(windows.count, maxDots), id: \.self) { index in
                Circle()
                    .fill(dotColor)
                    .frame(width: 4, height: 4)
            }
            
            // Overflow indicator
            if windows.count > maxDots {
                Text("+\(windows.count - maxDots)")
                    .font(.custom(config.fontFamily, size: 8))
                    .fontWeight(.medium)
                    .foregroundColor(config.textInactiveColor)
            }
        }
    }
    
    private var dotColor: Color {
        if isActive {
            return config.textActiveColor.opacity(0.8)
        } else {
            return config.textInactiveColor.opacity(0.6)
        }
    }
}
