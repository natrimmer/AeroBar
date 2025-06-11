import SwiftUI

struct SettingsView: View {
    @AppStorage("showWindowTitles") private var showWindowTitles = true
    @AppStorage("autoHide") private var autoHide = false
    @AppStorage("refreshInterval") private var refreshInterval = 1.5
    @AppStorage("overlayPosition") private var overlayPosition = OverlayPosition.topRight
    @AppStorage("overlayOpacity") private var overlayOpacity = 0.9
    @AppStorage("showInAllSpaces") private var showInAllSpaces = true
    @AppStorage("aerospacePath") private var aerospacePath = "/opt/homebrew/bin/aerospace"
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                showWindowTitles: $showWindowTitles,
                autoHide: $autoHide,
                refreshInterval: $refreshInterval
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            AppearanceSettingsView(
                overlayPosition: $overlayPosition,
                overlayOpacity: $overlayOpacity,
                showInAllSpaces: $showInAllSpaces
            )
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            AdvancedSettingsView(
                aerospacePath: $aerospacePath
            )
            .tabItem {
                Label("Advanced", systemImage: "terminal")
            }
        }
        .frame(width: 500, height: 300)
    }
}

struct GeneralSettingsView: View {
    @Binding var showWindowTitles: Bool
    @Binding var autoHide: Bool
    @Binding var refreshInterval: Double
    
    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show Window Titles", isOn: $showWindowTitles)
                Toggle("Auto Hide", isOn: $autoHide)
            }
            
            Section("Performance") {
                VStack(alignment: .leading) {
                    Text("Refresh Interval: \(String(format: "%.1f", refreshInterval))s")
                    Slider(value: $refreshInterval, in: 0.5...5.0, step: 0.5)
                    Text("Shorter intervals provide faster updates but use more CPU")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @Binding var overlayPosition: OverlayPosition
    @Binding var overlayOpacity: Double
    @Binding var showInAllSpaces: Bool
    
    var body: some View {
        Form {
            Section("Position") {
                Picker("Overlay Position", selection: $overlayPosition) {
                    ForEach(OverlayPosition.allCases, id: \.self) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Toggle("Show in All Spaces", isOn: $showInAllSpaces)
            }
            
            Section("Transparency") {
                VStack(alignment: .leading) {
                    Text("Opacity: \(Int(overlayOpacity * 100))%")
                    Slider(value: $overlayOpacity, in: 0.1...1.0, step: 0.1)
                }
            }
        }
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @Binding var aerospacePath: String
    @State private var showingPathPicker = false
    
    var body: some View {
        Form {
            Section("AeroSpace Configuration") {
                HStack {
                    TextField("AeroSpace Path", text: $aerospacePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Browse...") {
                        showingPathPicker = true
                    }
                }
                
                Text("Path to the aerospace binary")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Reset") {
                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showingPathPicker,
            allowedContentTypes: [.unixExecutable],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    aerospacePath = url.path
                }
            case .failure(let error):
                print("Error selecting file: \(error)")
            }
        }
    }
    
    private func resetToDefaults() {
        aerospacePath = "/opt/homebrew/bin/aerospace"
    }
}
