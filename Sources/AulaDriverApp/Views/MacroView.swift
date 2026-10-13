import AulaKit
import SwiftUI

public struct MacroView: View {
    @ObservedObject var vm: AppViewModel
    @State private var macros: [KeyboardMacro] = [
        KeyboardMacro(name: "Spotlight Search", events: [
            MacroEvent(type: .keyDown, value: 0xE3), // Cmd
            MacroEvent(type: .keyDown, value: 0x2C), // Space
            MacroEvent(type: .delay, delayMs: 50),
            MacroEvent(type: .keyUp, value: 0x2C),
            MacroEvent(type: .keyUp, value: 0xE3)
        ])
    ]
    @State private var selectedMacro: KeyboardMacro?

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Macro Studio")
                            .font(.system(size: 26, weight: .bold))
                        Text("Record, sequence, and synchronize onboard keyboard macros")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        if vm.isMacroRecording {
                            Button {
                                vm.stopMacroRecording()
                            } label: {
                                Label("Stop Recording", systemImage: "stop.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button {
                                vm.startMacroRecording()
                            } label: {
                                Label("Record Macro", systemImage: "record.circle")
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("New Empty") {
                            let newMacro = KeyboardMacro(name: "Macro \(vm.activeMacros.count + 1)")
                            vm.activeMacros.append(newMacro)
                            selectedMacro = newMacro
                        }
                        .buttonStyle(.bordered)

                        Button {
                            vm.uploadMacrosToDevice()
                        } label: {
                            Label("Flash to Keyboard", systemImage: "bolt.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!vm.wiredConnected || vm.activeMacros.isEmpty)
                    }
                }

                HStack(alignment: .top, spacing: 20) {
                    // Macro List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Onboard Macros (\(vm.activeMacros.count)/100)")
                            .font(.headline)

                        List(vm.activeMacros, selection: $selectedMacro) { macro in
                            VStack(alignment: .leading) {
                                Text(macro.name)
                                    .fontWeight(.semibold)
                                Text("\(macro.events.count) events | \(macro.playTimes)x")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(macro)
                        }
                        .frame(minWidth: 200, minHeight: 250)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                    }

                    // Macro Event Timeline
                    if let macro = selectedMacro ?? vm.activeMacros.first {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Sequence for '\(macro.name)'")
                                    .font(.headline)
                                Spacer()
                                Button("Add 50ms Delay") {
                                    if let idx = vm.activeMacros.firstIndex(where: { $0.id == macro.id }) {
                                        vm.activeMacros[idx].events.append(MacroEvent(type: .delay, delayMs: 50))
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)

                                Button("Clear Events") {
                                    if let idx = vm.activeMacros.firstIndex(where: { $0.id == macro.id }) {
                                        vm.activeMacros[idx].events.removeAll()
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundColor(.red)
                            }

                            if macro.events.isEmpty {
                                Text(vm.isMacroRecording ? "Recording active... Type keys on keyboard." : "No events recorded yet. Click 'Record Macro' to start.")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 180)
                            } else {
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(macro.events.enumerated()), id: \.offset) { index, event in
                                            HStack {
                                                Text("#\(index + 1)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 30)
                                                Text(event.displayString)
                                                    .font(.system(size: 13, design: .monospaced))
                                                Spacer()
                                                Button {
                                                    if let mIdx = vm.activeMacros.firstIndex(where: { $0.id == macro.id }) {
                                                        vm.activeMacros[mIdx].events.remove(at: index)
                                                    }
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .buttonStyle(.borderless)
                                            }
                                            .padding(6)
                                            .background(Color(NSColor.textBackgroundColor))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                                .frame(height: 250)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(20)
        }
    }
}
