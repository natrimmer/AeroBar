import Foundation
import SwiftUI

struct AeroBarConfig {
    // Font settings
    var fontFamily: String = "Inter"
    var fontSize: CGFloat = 13
    var appFontSize: CGFloat = 10

    // Colors
    var backgroundColor: Color = .clear
    var workspaceActiveColor: Color = .accentColor
    var workspaceInactiveColor: Color = .secondary
    var textActiveColor: Color = .primary
    var textInactiveColor: Color = .secondary
    var borderColor: Color = .primary
    var shadowColor: Color = .accentColor

    // Position and layout
    var position: BarPosition = .top
    var orientation: BarOrientation = .horizontal
    var barHeight: CGFloat = 32
    var barOpacity: Double = 0.95
    var cornerRadius: CGFloat = 6

    // Padding (CSS-style: all, x/y, or individual)
    var paddingAll: CGFloat? = nil
    var paddingX: CGFloat? = nil
    var paddingY: CGFloat? = nil
    var paddingTop: CGFloat = 16
    var paddingBottom: CGFloat = 16
    var paddingLeft: CGFloat = 16
    var paddingRight: CGFloat = 16

    // Border options
    var showBottomBorder: Bool = false
    var bottomBorderHeight: CGFloat = 2.0
    var bottomBorderColor: Color = .accentColor

    // Window display options
    var autoDisplayWindowTitles: Bool = true
    var displayActiveWindowTitle: Bool = true
    var displayAllWindowTitles: Bool = false  // Show titles for all workspaces
    var maxAppsActive: Int = 6  // Max app names shown for active workspace
    var maxAppsInactive: Int = 4  // Max app names shown for inactive workspaces (on hover)
    var showAppDots: Bool = true

    // Behavior
    var hoverDelay: Double = 0.2
    var animationDuration: Double = 0.2
    
    // AeroSpace integration
    var aerospacePath: String = "/opt/homebrew/bin/aerospace"

    // Configuration errors for UI display
    var configErrors: [String] = []

    // Computed padding values (CSS-style precedence)
    var finalPaddingTop: CGFloat {
        return paddingAll ?? paddingY ?? paddingTop
    }

    var finalPaddingBottom: CGFloat {
        return paddingAll ?? paddingY ?? paddingBottom
    }

    var finalPaddingLeft: CGFloat {
        return paddingAll ?? paddingX ?? paddingLeft
    }

    var finalPaddingRight: CGFloat {
        return paddingAll ?? paddingX ?? paddingRight
    }
}

enum BarPosition: String, CaseIterable {
    case top = "top"
    case bottom = "bottom"
    case left = "left"
    case right = "right"
}

enum BarOrientation: String, CaseIterable {
    case horizontal = "horizontal"
    case vertical = "vertical"
}

class AeroBarConfigLoader {
    static let shared = AeroBarConfigLoader()
    private let configPath = NSHomeDirectory() + "/.aerobar.toml"

    private init() {}

    func loadConfig() -> AeroBarConfig {
        var config = AeroBarConfig()

        guard FileManager.default.fileExists(atPath: configPath),
            let content = try? String(contentsOfFile: configPath)
        else {
            print("📄 No ~/.aerobar.toml found, using defaults")
            createDefaultConfig()
            return config
        }

        print("📄 Loading config from ~/.aerobar.toml")
        parseConfig(content: content, config: &config)
        return config
    }

    private func createDefaultConfig() {
        let defaultConfig = """
            # AeroBar Configuration
            # Edit this file to customize your AeroBar appearance and behavior

            [font]
            family = "Inter"
            size = 16.0
            app_size = 12.0

            [colors]
            # Colors can be specified as:
            # - Named colors: "red", "blue", "green", "primary", "secondary", "accent"
            # - Hex colors: "#FF0000", "#00FF00", "#0000FF"
            # - RGB: "rgb(255, 0, 0)"
            workspace_active = "accent"
            workspace_inactive = "secondary"
            text_active = "primary"
            text_inactive = "secondary"
            border = "primary"
            shadow = "accent"
            background = "clear"

            [layout]
            position = "top"           # top, bottom, left, right
            orientation = "horizontal" # horizontal, vertical
            height = 32.0
            opacity = 0.95
            corner_radius = 6.0

            # Padding (CSS-style precedence: all > x/y > individual)
            # padding_all = 16.0       # Sets all sides (highest precedence)
            # padding_x = 16.0         # Sets left and right
            # padding_y = 8.0          # Sets top and bottom
            padding_top = 16.0         # Individual sides (lowest precedence)
            padding_bottom = 16.0
            padding_left = 16.0
            padding_right = 16.0

            [border]
            show_bottom = false        # Show bottom border (tab-like effect)
            bottom_height = 2.0
            bottom_color = "accent"

            [windows]
            auto_display_titles = true    # Show app names for active workspace automatically
            display_active_title = true   # Show current window title in bar
            display_all_titles = false   # Show app names for ALL workspaces (not just active)
            max_apps_active = 6          # Max app names shown for active workspace
            max_apps_inactive = 4        # Max app names shown when hovering inactive workspaces
            show_dots = true             # Show dots for apps when not showing names

            [behavior]
            hover_delay = 0.2
            animation_duration = 0.2
            
            [aerospace]
            path = "/opt/homebrew/bin/aerospace"
            """

        do {
            try defaultConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("📄 Created default config at ~/.aerobar.toml")
        } catch {
            print("⚠️ Failed to create default config: \(error)")
        }
    }

    private func parseConfig(content: String, config: inout AeroBarConfig) {
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        config.configErrors = []

        for (lineNumber, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.hasPrefix("#") || trimmed.isEmpty {
                continue
            }

            // Section headers
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                continue
            }

            // Key-value pairs
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count == 2 else {
                config.configErrors.append("Line \(lineNumber + 1): Invalid syntax '\(trimmed)'")
                continue
            }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let rawValue = parts[1].trimmingCharacters(in: .whitespaces)

            
            // Handle comments while preserving # in hex colors
            let value: String
            if rawValue.contains("#") && (rawValue.hasPrefix("#") || rawValue.hasPrefix("\"#")) {
                // For hex colors like "#00FF88" or "#00FF88"
                let unquoted = rawValue.replacingOccurrences(of: "\"", with: "")
                if let spaceIndex = unquoted.firstIndex(of: " ") {
                    value = String(unquoted[..<spaceIndex])
                } else {
                    value = unquoted
                }
            } else {
                // For other values, remove quotes then comments
                let unquoted = rawValue.replacingOccurrences(of: "\"", with: "")
                value = unquoted.components(separatedBy: "#")[0].trimmingCharacters(
                    in: .whitespaces)
            }

            
            // Skip if value is empty after comment removal
            guard !value.isEmpty else {
                config.configErrors.append("Line \(lineNumber + 1): Empty value for key '\(key)'")
                continue
            }

            do {
                try parseConfigValue(
                    section: currentSection, key: key, value: value, config: &config)
            } catch {
                config.configErrors.append(
                    "Line \(lineNumber + 1): \(error.localizedDescription)")
            }
        }

        if !config.configErrors.isEmpty {
            print("⚠️ Configuration errors found:")
            for error in config.configErrors {
                print("   \(error)")
            }
        }
    }

    private func parseConfigValue(
        section: String, key: String, value: String, config: inout AeroBarConfig
    ) throws {
        switch section {
        case "font":
            switch key {
            case "family": config.fontFamily = value
            case "size":
                guard let size = Double(value) else { throw ConfigError.invalidNumber(key, value) }
                config.fontSize = CGFloat(size)
            case "app_size":
                guard let size = Double(value) else { throw ConfigError.invalidNumber(key, value) }
                config.appFontSize = CGFloat(size)
            default: throw ConfigError.unknownKey(section, key)
            }

        case "colors":
            let color = try parseColor(value)
            switch key {
            case "workspace_active": config.workspaceActiveColor = color
            case "workspace_inactive": config.workspaceInactiveColor = color
            case "text_active": config.textActiveColor = color
            case "text_inactive": config.textInactiveColor = color
            case "border": config.borderColor = color
            case "shadow": config.shadowColor = color
            case "background": config.backgroundColor = color
            default: throw ConfigError.unknownKey(section, key)
            }

        case "layout":
            switch key {
            case "position":
                guard let pos = BarPosition(rawValue: value) else {
                    throw ConfigError.invalidEnum(
                        key, value, BarPosition.allCases.map { $0.rawValue })
                }
                config.position = pos
            case "orientation":
                guard let orient = BarOrientation(rawValue: value) else {
                    throw ConfigError.invalidEnum(
                        key, value, BarOrientation.allCases.map { $0.rawValue })
                }
                config.orientation = orient
            case "height":
                guard let height = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.barHeight = CGFloat(height)
            case "opacity":
                guard let opacity = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.barOpacity = opacity
            case "corner_radius":
                guard let radius = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.cornerRadius = CGFloat(radius)
            case "padding_all":
                guard let padding = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.paddingAll = CGFloat(padding)
            case "padding_x":
                guard let padding = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.paddingX = CGFloat(padding)
            case "padding_y":
                guard let padding = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.paddingY = CGFloat(padding)
            case "padding_top":
                guard let padding = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.paddingTop = CGFloat(padding)
            case "padding_bottom":
                guard let padding = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.paddingBottom = CGFloat(padding)
            case "padding_left":
                guard let padding = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.paddingLeft = CGFloat(padding)
            case "padding_right":
                guard let padding = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.paddingRight = CGFloat(padding)
            default: throw ConfigError.unknownKey(section, key)
            }

        case "border":
            switch key {
            case "show_bottom": config.showBottomBorder = Bool(value) ?? false
            case "bottom_height":
                guard let height = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.bottomBorderHeight = CGFloat(height)
            case "bottom_color": config.bottomBorderColor = try parseColor(value)
            default: throw ConfigError.unknownKey(section, key)
            }

        case "windows":
            switch key {
            case "auto_display_titles": config.autoDisplayWindowTitles = Bool(value) ?? true
            case "display_active_title": config.displayActiveWindowTitle = Bool(value) ?? true
            case "display_all_titles": config.displayAllWindowTitles = Bool(value) ?? false
            case "max_apps_active":
                guard let max = Int(value) else { throw ConfigError.invalidNumber(key, value) }
                config.maxAppsActive = max
            case "max_apps_inactive":
                guard let max = Int(value) else { throw ConfigError.invalidNumber(key, value) }
                config.maxAppsInactive = max
            case "show_dots": config.showAppDots = Bool(value) ?? true
            default: throw ConfigError.unknownKey(section, key)
            }

        case "behavior":
            switch key {
            case "hover_delay":
                guard let delay = Double(value) else { throw ConfigError.invalidNumber(key, value) }
                config.hoverDelay = delay
            case "animation_duration":
                guard let duration = Double(value) else {
                    throw ConfigError.invalidNumber(key, value)
                }
                config.animationDuration = duration
            default: throw ConfigError.unknownKey(section, key)
            }
            
        case "aerospace":
            switch key {
            case "path": config.aerospacePath = value
            default: throw ConfigError.unknownKey(section, key)
            }

        default:
            throw ConfigError.unknownSection(section)
        }
    }

    private func parseColor(_ value: String) throws -> Color {
        let lowercased = value.lowercased()

        // Named colors
        switch lowercased {
        case "primary": return .primary
        case "secondary": return .secondary
        case "accent", "accentcolor": return .accentColor
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "black": return .black
        case "white": return .white
        case "gray", "grey": return .gray
        case "clear": return .clear
        default: break
        }

        // Hex colors
        if value.hasPrefix("#") {
            if let color = parseHexColor(value) {
                return color
            } else {
                throw ConfigError.invalidColor(value, "Invalid hex format")
            }
        }

        // RGB colors
        if value.hasPrefix("rgb(") {
            if let color = parseRGBColor(value) {
                return color
            } else {
                throw ConfigError.invalidColor(value, "Invalid RGB format")
            }
        }

        throw ConfigError.invalidColor(value, "Unknown color format")
    }

    private func parseHexColor(_ hex: String) -> Color? {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    private func parseRGBColor(_ rgb: String) -> Color? {
        let rgb = rgb.replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let components = rgb.components(separatedBy: ",")

        guard components.count == 3,
            let r = Double(components[0].trimmingCharacters(in: .whitespaces)),
            let g = Double(components[1].trimmingCharacters(in: .whitespaces)),
            let b = Double(components[2].trimmingCharacters(in: .whitespaces))
        else {
            return nil
        }

        return Color(
            .sRGB,
            red: r / 255,
            green: g / 255,
            blue: b / 255
        )
    }
}

enum ConfigError: LocalizedError {
    case invalidNumber(String, String)
    case invalidColor(String, String)
    case invalidEnum(String, String, [String])
    case unknownKey(String, String)
    case unknownSection(String)

    var errorDescription: String? {
        switch self {
        case .invalidNumber(let key, let value):
            return "Invalid number for '\(key)': '\(value)'"
        case .invalidColor(let value, let reason):
            return "Invalid color '\(value)': \(reason)"
        case .invalidEnum(let key, let value, let valid):
            return
                "Invalid value for '\(key)': '\(value)'. Valid options: \(valid.joined(separator: ", "))"
        case .unknownKey(let section, let key):
            return "Unknown key '\(key)' in section '[\(section)]'"
        case .unknownSection(let section):
            return "Unknown section '[\(section)]'"
        }
    }
}
