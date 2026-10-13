import AulaKit
import SwiftUI

public struct DashboardView: View {
    @ObservedObject var vm: AppViewModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aula F108 Pro")
                            .font(.system(size: 26, weight: .bold))
                        Text("Tri-Mode Full-Size RGB Mechanical Keyboard")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if vm.isWorking {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                // Connection & Battery Status Cards
                HStack(spacing: 16) {
                    // Wired Status
                    StatusCard(
                        icon: "cable.connector",
                        title: "USB-C Wired",
                        subtitle: vm.wiredConnected ? "Connected (Full Control)" : "Disconnected",
                        isActive: vm.wiredConnected,
                        activeColor: .green
                    )

                    // 2.4G Status
                    StatusCard(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "2.4G Wireless",
                        subtitle: vm.dongleConnected ? "Dongle Active" : "No Receiver",
                        isActive: vm.dongleConnected,
                        activeColor: .blue
                    )

                    // Battery Gauge
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "battery.100")
                                .foregroundColor(batteryColor)
                            Text("Battery")
                                .font(.headline)
                        }
                        if let percent = vm.batteryPercent {
                            Text("\(percent)%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(batteryColor)
                            ProgressView(value: Double(percent), total: 100)
                                .tint(batteryColor)
                        } else {
                            Text(vm.dongleConnected ? "Querying..." : "2.4G required")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Controls")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button {
                            vm.syncClock()
                        } label: {
                            Label("Sync Clock", systemImage: "clock.arrow.circlepath")
                        }
                        .disabled(!vm.wiredConnected)
                        .buttonStyle(.borderedProminent)

                        Button {
                            vm.queryBattery()
                        } label: {
                            Label("Check Battery", systemImage: "bolt.batteryblock")
                        }
                        .disabled(!vm.dongleConnected)

                        Toggle(isOn: $vm.macLayoutEnabled) {
                            Text("Mac Layout (Cmd/Opt Swapped)")
                        }
                        .toggleStyle(.switch)
                        .onChange(of: vm.macLayoutEnabled) { _ in
                            if vm.wiredConnected {
                                vm.applyKeyRemap()
                            }
                        }

                        Toggle(isOn: $vm.gameModeEnabled) {
                            Text("Game Mode (Win Lock)")
                        }
                        .toggleStyle(.switch)
                        .onChange(of: vm.gameModeEnabled) { val in
                            vm.toggleGameMode(val)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Hardware Telemetry & Diagnostics Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Hardware Telemetry & USB Metrics", systemImage: "cpu")
                            .font(.headline)
                        Spacer()
                        Button {
                            vm.refreshTelemetry()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }

                    if let t = vm.telemetry {
                        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                            GridRow {
                                Text("Connection:")
                                    .foregroundColor(.secondary)
                                Text(t.mode.rawValue)
                                    .fontWeight(.medium)

                                Text("Bus Speed:")
                                    .foregroundColor(.secondary)
                                Text(t.usbSpeed)
                            }
                            GridRow {
                                Text("Manufacturer:")
                                    .foregroundColor(.secondary)
                                Text(t.manufacturer)

                                Text("Round-Trip Latency:")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f ms", t.roundTripLatencyMs))
                                    .foregroundColor(t.roundTripLatencyMs < 5.0 ? .green : .orange)
                                    .fontWeight(.semibold)
                            }
                            GridRow {
                                Text("USB Identifier:")
                                    .foregroundColor(.secondary)
                                Text("\(t.vendorHex):\(t.productHex)")
                                    .font(.system(.body, design: .monospaced))

                                Text("Active Endpoints:")
                                    .foregroundColor(.secondary)
                                Text("\(t.endpointCount) interfaces")
                            }
                        }
                        .font(.system(size: 13))

                        Divider()

                        HStack(spacing: 20) {
                            Text("Host Lock Keys:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            LockBadge(label: "Caps Lock", isActive: t.capsLockActive)
                            LockBadge(label: "Num Lock", isActive: t.numLockActive)
                            LockBadge(label: "Scroll Lock", isActive: t.scrollLockActive)
                        }
                    } else {
                        Text("Click refresh to capture real-time hardware telemetry.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Activity Console
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Device Activity Log")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            vm.logLines.removeAll()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(vm.logLines, id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(line.contains("❌") ? .red : line.contains("✅") ? .green : .secondary)
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: 140)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(20)
        }
    }

    private var batteryColor: Color {
        guard let p = vm.batteryPercent else { return .secondary }
        if p <= 20 { return .red }
        if p <= 50 { return .orange }
        return .green
    }
}

private struct StatusCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isActive: Bool
    let activeColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isActive ? activeColor : .secondary)
                Text(title)
                    .font(.headline)
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(isActive ? activeColor : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

private struct LockBadge: View {
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
    }
}
