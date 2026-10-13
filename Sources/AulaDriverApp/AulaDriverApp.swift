import AppKit
import AulaKit
import SwiftUI

@main
struct AulaDriverApp: App {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // macOS Menu Bar Extra
        MenuBarExtra {
            MenuBarView(vm: viewModel) {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "keyboard")
                if let p = viewModel.batteryPercent {
                    Text("\(p)%")
                        .font(.caption2)
                }
            }
        }

        // Full Desktop Dashboard Window
        WindowGroup("Aula F108 Pro Dashboard", id: "dashboard") {
            MainWindow(vm: viewModel)
        }
        .windowResizability(.contentSize)
    }
}
