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
                    Button("Create Macro") {
                        let newMacro = KeyboardMacro(name: "New Macro \(macros.count + 1)")
                        macros.append(newMacro)
                        selectedMacro = newMacro
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(alignment: .top, spacing: 20) {
                    // Macro List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Onboard Macros (\(macros.count)/100)")
                            .font(.headline)

                        List(macros, selection: $selectedMacro) { macro in
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
                    if let macro = selectedMacro {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Event Sequence for '\(macro.name)'")
                                .font(.headline)

                            if macro.events.isEmpty {
                                Text("No events in this macro.")
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
