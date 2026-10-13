import AulaKit
import SwiftUI

public enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case screen = "TFT Screen"
    case lighting = "RGB Lighting"
    case remap = "Key Remap"
    case macros = "Macros"
    case profiles = "Profiles"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .dashboard: return "gauge"
        case .screen: return "display"
        case .lighting: return "sparkles"
        case .remap: return "keyboard"
        case .macros: return "command"
        case .profiles: return "folder.fill"
        }
    }
}

public struct MainWindow: View {
    @ObservedObject var vm: AppViewModel
    @State private var selectedTab: NavigationTab = .dashboard

    public var body: some View {
        NavigationSplitView {
            List(NavigationTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
            .navigationTitle("Aula F108 Pro")
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .dashboard:
                        DashboardView(vm: vm)
                    case .screen:
                        ScreenStudioView(vm: vm)
                    case .lighting:
                        LightingStudioView(vm: vm)
                    case .remap:
                        KeyRemapView(vm: vm)
                    case .macros:
                        MacroView(vm: vm)
                    case .profiles:
                        ProfileView(vm: vm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Persistent Background Screen Streaming Banner
                if vm.isScreenUploading {
                    HStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(0.8)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Streaming to LCD Screen: \(vm.uploadingTitle)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(vm.uploadProgress.percent)% (\(vm.uploadProgress.sentChunks)/\(vm.uploadProgress.totalChunks) pages)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            ProgressView(value: vm.uploadProgress.fraction)
                                .tint(.accentColor)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(Rectangle().frame(height: 1).foregroundColor(Color.secondary.opacity(0.2)), alignment: .top)
                }
            }
        }
        .overlay(alignment: .top) {
            if vm.showKnobHUD, let event = vm.recentKnobEvent {
                HStack(spacing: 12) {
                    Image(systemName: iconForKnob(event))
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text(titleForKnob(event))
                        .font(.headline)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                .padding(.top, 20)
                .animation(.easeInOut, value: vm.showKnobHUD)
            }
        }
        .frame(minWidth: 800, minHeight: 550)
    }

    private func iconForKnob(_ event: KnobEvent) -> String {
        switch event {
        case .volumeUp: return "speaker.wave.3.fill"
        case .volumeDown: return "speaker.wave.1.fill"
        case .mute: return "speaker.slash.fill"
        case .playPause: return "playpause.fill"
        case .unknown: return "dial.low.fill"
        }
    }

    private func titleForKnob(_ event: KnobEvent) -> String {
        switch event {
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .mute: return "Mute Toggled"
        case .playPause: return "Play / Pause"
        case .unknown(let code): return "Knob Code 0x\(String(format: "%02X", code))"
        }
    }
}
