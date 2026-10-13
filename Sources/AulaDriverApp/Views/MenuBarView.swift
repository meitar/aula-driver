import AulaKit
import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var vm: AppViewModel
    var onOpenDashboard: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Aula F108 Pro")
                    .font(.headline)
                HStack(spacing: 8) {
                    Circle()
                        .fill(vm.wiredConnected ? Color.green : vm.dongleConnected ? Color.blue : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(vm.wiredConnected ? "USB-C Connected" : vm.dongleConnected ? "2.4G Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let p = vm.batteryPercent {
                        Text("•  🔋 \(p)%")
                            .font(.caption)
                            .foregroundColor(p <= 20 ? .red : .primary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Quick Actions
            Button {
                vm.syncClock()
            } label: {
                Label("Sync Clock", systemImage: "clock.arrow.circlepath")
            }
            .disabled(!vm.wiredConnected)
            .keyboardShortcut("s", modifiers: .command)

            Toggle(isOn: $vm.macLayoutEnabled) {
                Text("Mac Layout (Swap Cmd/Opt)")
            }
            .onChange(of: vm.macLayoutEnabled) { _ in
                if vm.wiredConnected {
                    vm.applyKeyRemap()
                }
            }

            // Quick Lighting Menu
            Menu("RGB Preset") {
                ForEach(LightingController.presets) { preset in
                    Button(preset.name) {
                        vm.rgbMode = preset.id
                        vm.applyRGB()
                    }
                }
            }

            // Screen Animation Switcher
            if !vm.galleryItems.isEmpty {
                Menu("Screen Animation") {
                    ForEach(vm.galleryItems) { item in
                        Button {
                            vm.activateGalleryItem(item)
                        } label: {
                            HStack {
                                Text(item.title)
                                if item.isActive {
                                    Text("✓")
                                }
                            }
                        }
                        .disabled(!vm.wiredConnected || vm.isWorking)
                    }
                }
            }

            // Profile Switcher
            Menu("Switch Profile") {
                ForEach(vm.profiles) { profile in
                    Button(profile.name) {
                        vm.selectProfile(profile)
                    }
                }
            }

            Divider()

            Button {
                onOpenDashboard()
            } label: {
                Label("Open Dashboard...", systemImage: "macwindow")
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("Quit Aula Driver") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
