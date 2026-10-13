import AppKit
import AulaKit
import SwiftUI

public struct AboutView: View {
    @ObservedObject var vm: AppViewModel

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.2"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private let repoURL = URL(string: "https://github.com/meitar/aula-driver")!
    private let issuesURL = URL(string: "https://github.com/meitar/aula-driver/issues")!
    private let tapURL = URL(string: "https://github.com/meitar/homebrew-tap")!

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header / Branding Card
                VStack(spacing: 14) {
                    if let appIcon = NSApp.applicationIconImage {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 110, height: 110)
                            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                    } else {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 70))
                            .foregroundColor(.accentColor)
                    }

                    VStack(spacing: 4) {
                        Text("Aula Driver")
                            .font(.system(size: 26, weight: .bold))

                        Text("macOS Companion Driver for Aula F108 Pro")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            Text("Version \(appVersion)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(6)

                            Text("Universal (Apple Silicon & Intel)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(14)

                // Credits & Developer Info Card
                VStack(alignment: .leading, spacing: 14) {
                    Label("Credits & Development", systemImage: "person.circle.fill")
                        .font(.headline)

                    Divider()

                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Created with ❤️ by")
                                    .foregroundColor(.secondary)
                                Link("Meitar", destination: repoURL)
                                    .fontWeight(.bold)
                                    .foregroundColor(.accentColor)
                            }
                            .font(.body)

                            Text("Dedicated macOS reverse-engineered driver & companion suite.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("GitHub Repository")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Link(destination: repoURL) {
                            HStack {
                                Image(systemName: "link")
                                Text("https://github.com/meitar/aula-driver")
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .font(.callout)
                            .foregroundColor(.accentColor)
                        }
                    }

                    Divider()

                    // Homebrew Tap info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installation & Updates")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Install or update anytime via Homebrew:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("brew update && brew upgrade --cask aula-driver")
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("brew update && brew upgrade --cask aula-driver", forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .help("Copy command to clipboard")
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(14)

                // Links & Actions
                HStack(spacing: 14) {
                    Link(destination: repoURL) {
                        Label("View Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Link(destination: issuesURL) {
                        Label("Report an Issue", systemImage: "exclamationmark.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                // License note
                Text("Released under the MIT License • Open Source")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)
            }
            .padding(24)
        }
    }
}
