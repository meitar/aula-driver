import AulaKit
import SwiftUI

public struct LightingStudioView: View {
    @ObservedObject var vm: AppViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RGB Lighting Studio")
                            .font(.system(size: 26, weight: .bold))
                        Text("Configure 20 south-facing RGB backlight effects, brightness, and colors")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        vm.applyRGB()
                    } label: {
                        Label("Apply Lighting", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.wiredConnected && !vm.dongleConnected)
                }

                // Controls Panel
                VStack(spacing: 16) {
                    HStack(spacing: 24) {
                        // Brightness
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "sun.max")
                                Text("Brightness: \(vm.rgbBrightness)")
                                    .font(.subheadline)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(vm.rgbBrightness) },
                                    set: {
                                        let intVal = Int($0)
                                        if vm.rgbBrightness != intVal {
                                            vm.rgbBrightness = intVal
                                            vm.applyRGB()
                                        }
                                    }
                                ),
                                in: 0...5,
                                step: 1
                            )
                        }

                        // Speed
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "speedometer")
                                Text("Speed: \(vm.rgbSpeed)")
                                    .font(.subheadline)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(vm.rgbSpeed) },
                                    set: {
                                        let intVal = Int($0)
                                        if vm.rgbSpeed != intVal {
                                            vm.rgbSpeed = intVal
                                            vm.applyRGB()
                                        }
                                    }
                                ),
                                in: 1...5,
                                step: 1
                            )
                        }

                        // Direction
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Direction")
                                .font(.subheadline)
                            Picker("Direction", selection: $vm.rgbDirection) {
                                Text("Right").tag(0)
                                Text("Down").tag(1)
                                Text("Left").tag(2)
                                Text("Up").tag(3)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: vm.rgbDirection) { _ in
                                vm.applyRGB()
                            }
                        }
                    }

                    Divider()

                    // Color controls
                    HStack(spacing: 20) {
                        Toggle(isOn: $vm.rgbColorful) {
                            Label("Rainbow Cycle (Colorful)", systemImage: "rainbow")
                        }
                        .toggleStyle(.checkbox)
                        .onChange(of: vm.rgbColorful) { _ in
                            vm.applyRGB()
                        }

                        if !vm.rgbColorful {
                            ColorPicker("Custom Accent Color:", selection: $vm.rgbColor)
                                .onChange(of: vm.rgbColor) { _ in
                                    vm.applyRGB()
                                }
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // 20 Preset Cards Grid
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Hardware LED Presets")
                            .font(.headline)
                        Spacer()
                        Text("Click any effect to activate instantly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(LightingController.presets) { preset in
                            Button {
                                vm.rgbMode = preset.id
                                vm.applyRGB()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: iconForPreset(preset.id))
                                        .font(.title2)
                                        .foregroundColor(vm.rgbMode == preset.id ? .accentColor : .primary)
                                    Text(preset.name)
                                        .font(.subheadline)
                                        .fontWeight(vm.rgbMode == preset.id ? .bold : .regular)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                    Text("Mode \(preset.id)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(vm.rgbMode == preset.id ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(vm.rgbMode == preset.id ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: vm.rgbMode == preset.id ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func iconForPreset(_ id: Int) -> String {
        switch id {
        case 0: return "moon.fill"
        case 1: return "lightbulb.fill"
        case 2: return "hand.tap.fill"
        case 3: return "hand.raised.fill"
        case 4: return "sparkles"
        case 5: return "cloud.rain.fill"
        case 6: return "rainbow"
        case 7: return "waveform"
        case 8: return "paintpalette.fill"
        case 9: return "arrow.up.left.and.arrow.down.right"
        case 10: return "arrow.left.arrow.right"
        case 11: return "circle.dashed"
        case 12: return "arrow.triangle.2.circlepath"
        case 13: return "burst.fill"
        case 14: return "arrow.up.forward.app.fill"
        case 15: return "water.waves"
        case 16: return "wind"
        case 17: return "heart.fill"
        case 18: return "skew"
        case 19: return "bolt.fill"
        default: return "sparkles"
        }
    }
}
