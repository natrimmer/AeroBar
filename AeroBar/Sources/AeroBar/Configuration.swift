import Foundation

class Configuration: ObservableObject {
    static let shared = Configuration()
    
    @Published var showWindowTitles: Bool = true
    @Published var autoHide: Bool = false
    @Published var refreshInterval: TimeInterval = 1.5
    @Published var overlayPosition: OverlayPosition = .topRight
    @Published var overlayOpacity: Double = 0.9
    @Published var showInAllSpaces: Bool = true
    @Published var aerospacePath: String = "/opt/homebrew/bin/aerospace"
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        showWindowTitles = userDefaults.bool(forKey: "showWindowTitles")
        autoHide = userDefaults.bool(forKey: "autoHide")
        refreshInterval = userDefaults.double(forKey: "refreshInterval")
        overlayOpacity = userDefaults.double(forKey: "overlayOpacity")
        showInAllSpaces = userDefaults.bool(forKey: "showInAllSpaces")
        
        if let path = userDefaults.string(forKey: "aerospacePath"), !path.isEmpty {
            aerospacePath = path
        }
        
        if let positionString = userDefaults.string(forKey: "overlayPosition"),
           let position = OverlayPosition(rawValue: positionString) {
            overlayPosition = position
        }
        
        // Set defaults if not previously set
        if refreshInterval == 0 {
            refreshInterval = 1.5
        }
        if overlayOpacity == 0 {
            overlayOpacity = 0.9
        }
    }
    
    func saveConfiguration() {
        userDefaults.set(showWindowTitles, forKey: "showWindowTitles")
        userDefaults.set(autoHide, forKey: "autoHide")
        userDefaults.set(refreshInterval, forKey: "refreshInterval")
        userDefaults.set(overlayPosition.rawValue, forKey: "overlayPosition")
        userDefaults.set(overlayOpacity, forKey: "overlayOpacity")
        userDefaults.set(showInAllSpaces, forKey: "showInAllSpaces")
        userDefaults.set(aerospacePath, forKey: "aerospacePath")
    }
}

enum OverlayPosition: String, CaseIterable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    case center = "Center"
}
