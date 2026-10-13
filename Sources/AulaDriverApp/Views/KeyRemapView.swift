import AulaKit
import SwiftUI

public struct KeyRemapView: View {
    @ObservedObject var vm: AppViewModel
    @State private var selectedKey: KeyDefinition?

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key Remapper & Dual Layers")
                            .font(.system(size: 26, weight: .bold))
                        Text("Remap all 108 keys across Normal and FN layers, or activate Apple Mac layout")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        if vm.remapLayer == .fn {
                            vm.applyFNKeyRemap()
                        } else {
                            vm.applyKeyRemap()
                        }
                    } label: {
                        Label("Save \(vm.remapLayer == .fn ? "FN Layer" : "Normal Layer") to Keyboard", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.wiredConnected)
                }

                // Mac Layout & Layer Switcher
                HStack(spacing: 20) {
                    Toggle(isOn: $vm.macLayoutEnabled) {
                        VStack(alignment: .leading) {
                            Text("Apple Mac Ergonomic Layout")
                                .fontWeight(.semibold)
                            Text("Logically swaps Left Win (Cmd) and Left Alt (Opt) to match MacBook / Magic Keyboard order: Control - Option - Command - Space")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    Spacer()

                    HStack(spacing: 8) {
                        Text("Active Layer:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Picker("Active Layer", selection: $vm.remapLayer) {
                            Text("Normal Layer").tag(KeyRemapLayer.normal)
                            Text("FN Layer").tag(KeyRemapLayer.fn)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 220)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Visual Keyboard Layout
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Interactive 108-Key Layout (Click any key to inspect or customize)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Active Layer: \(vm.remapLayer == .fn ? "FN Layer (Secondary)" : "Normal Layer (Base)")")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(vm.remapLayer == .fn ? .orange : .accentColor)
                    }

                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(0...5, id: \.self) { row in
                                HStack(spacing: 5) {
                                    ForEach(KeyCatalog.allKeys.filter { $0.row == row }, id: \.keyIndex) { key in
                                        let activeTable = vm.remapLayer == .fn ? vm.fnRemapTable : vm.currentRemapTable
                                        KeyButton(
                                            key: key,
                                            isSelected: selectedKey?.keyIndex == key.keyIndex,
                                            isRemapped: activeTable.actions[key.keyIndex] != nil,
                                            actionText: activeTable.actions[key.keyIndex]?.displayDescription
                                        ) {
                                            selectedKey = key
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.15))
                        .cornerRadius(12)
                    }
                }

                // Selected Key Inspector
                if let key = selectedKey {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Key: \(key.name)")
                                .font(.headline)
                            Text("(\(vm.remapLayer == .fn ? "FN Layer" : "Normal Layer"))")
                                .font(.subheadline)
                                .foregroundColor(vm.remapLayer == .fn ? .orange : .accentColor)
                            Spacer()
                            Text("Key Index: \(key.keyIndex) | Scancode: 0x\(String(key.code, radix: 16))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 16) {
                            Button("Reset to Default") {
                                if vm.remapLayer == .fn {
                                    vm.fnRemapTable.resetKey(key.keyIndex)
                                } else {
                                    vm.currentRemapTable.resetKey(key.keyIndex)
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Media: Play / Pause") {
                                if vm.remapLayer == .fn {
                                    vm.fnRemapTable.setAction(.consumer(code: 0xCD), for: key.keyIndex)
                                } else {
                                    vm.currentRemapTable.setAction(.consumer(code: 0xCD), for: key.keyIndex)
                                }
                            }

                            Button("Media: Mute") {
                                if vm.remapLayer == .fn {
                                    vm.fnRemapTable.setAction(.consumer(code: 0xE2), for: key.keyIndex)
                                } else {
                                    vm.currentRemapTable.setAction(.consumer(code: 0xE2), for: key.keyIndex)
                                }
                            }

                            Button("Mouse: Left Click") {
                                if vm.remapLayer == .fn {
                                    vm.fnRemapTable.setAction(.mouse(button: 1), for: key.keyIndex)
                                } else {
                                    vm.currentRemapTable.setAction(.mouse(button: 1), for: key.keyIndex)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
            }
            .padding(20)
        }
    }
}

private struct KeyButton: View {
    let key: KeyDefinition
    let isSelected: Bool
    let isRemapped: Bool
    let actionText: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(key.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                if let actionText {
                    Text(actionText)
                        .font(.system(size: 8))
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                }
            }
            .frame(width: max(32, CGFloat(key.width * 36)), height: 38)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.3) : isRemapped ? Color.orange.opacity(0.2) : Color(NSColor.controlColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
