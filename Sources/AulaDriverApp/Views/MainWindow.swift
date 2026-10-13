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
        .frame(minWidth: 800, minHeight: 550)
    }
}
