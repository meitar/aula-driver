import AulaKit
import SwiftUI

public struct ProfileView: View {
    @ObservedObject var vm: AppViewModel
    @State private var newProfileName = ""
    @State private var showCreateDialog = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile Management")
                            .font(.system(size: 26, weight: .bold))
                        Text("Store, export, and switch between customized keyboard presets on macOS")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Save Current Settings") {
                        vm.saveCurrentProfile()
                    }
                    .buttonStyle(.bordered)

                    Button("New Profile...") {
                        newProfileName = "Custom Profile \(vm.profiles.count + 1)"
                        showCreateDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Profile Cards
                LazyVStack(spacing: 12) {
                    ForEach(vm.profiles) { profile in
                        HStack(spacing: 16) {
                            Image(systemName: "keyboard.fill")
                                .font(.title2)
                                .foregroundColor(vm.selectedProfile?.id == profile.id ? .accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(profile.name)
                                        .font(.headline)
                                    if vm.selectedProfile?.id == profile.id {
                                        Text("ACTIVE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.2))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(4)
                                    }
                                }

                                Text("RGB Mode: \(profile.rgbMode) | Mac Layout: \(profile.macLayoutEnabled ? "Yes" : "No") | Debounce: \(profile.responseLevel)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Activate") {
                                vm.selectProfile(profile)
                            }
                            .buttonStyle(.bordered)
                            .disabled(vm.selectedProfile?.id == profile.id)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(vm.selectedProfile?.id == profile.id ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vm.selectedProfile?.id == profile.id ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                }

                // Application Auto-Switching Rules
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Application Auto-Switching Rules")
                                .font(.headline)
                            Text("Automatically apply keyboard profiles when specific macOS applications become active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm.isAppWatcherActive },
                            set: { _ in vm.toggleAppWatcher() }
                        ))
                        .toggleStyle(.switch)
                    }

                    if vm.appRules.isEmpty {
                        VStack(spacing: 8) {
                            Text("No application rules configured yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                Button("+ Rule for Xcode") {
                                    vm.addAppRule(bundleID: "com.apple.dt.Xcode", name: "Xcode", profileName: vm.selectedProfile?.name ?? "Standard Mac")
                                }
                                .buttonStyle(.bordered)
                                Button("+ Rule for Terminal") {
                                    vm.addAppRule(bundleID: "com.apple.Terminal", name: "Terminal", profileName: vm.selectedProfile?.name ?? "Standard Mac")
                                }
                                .buttonStyle(.bordered)
                                Button("+ Rule for Steam") {
                                    vm.addAppRule(bundleID: "com.valvesoftware.steam", name: "Steam", profileName: "Gaming (5ms, Win Locked)")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(vm.appRules) { rule in
                                HStack {
                                    Image(systemName: "app.badge")
                                        .foregroundColor(.accentColor)
                                    Text(rule.applicationName)
                                        .fontWeight(.semibold)
                                    Text("(\(rule.bundleIdentifier))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("→  \(rule.profileName)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Button {
                                        vm.removeAppRule(bundleID: rule.bundleIdentifier)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(20)
        }
        .sheet(isPresented: $showCreateDialog) {
            VStack(spacing: 16) {
                Text("Create New Profile")
                    .font(.headline)
                TextField("Profile Name", text: $newProfileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)

                HStack {
                    Button("Cancel") {
                        showCreateDialog = false
                    }
                    Button("Create") {
                        vm.createNewProfile(name: newProfileName)
                        showCreateDialog = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
    }
}
