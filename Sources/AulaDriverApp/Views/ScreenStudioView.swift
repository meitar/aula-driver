import AulaKit
import SwiftUI
import UniformTypeIdentifiers

public struct ScreenStudioView: View {
    @ObservedObject var vm: AppViewModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("TFT Screen Studio")
                        .font(.system(size: 26, weight: .bold))
                    Text("Customize the 1.14\" 240×135 IPS Color Display with images, GIFs, and clock sync")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Clock Sync Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keyboard Clock")
                            .font(.headline)
                        Text("Synchronize LCD date and time with your macOS system clock.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        vm.syncClock()
                    } label: {
                        Label("Sync Now", systemImage: "clock.badge.checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.wiredConnected)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Media Uploader Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Custom Image / Animated GIF")
                        .font(.headline)

                    HStack(spacing: 24) {
                        // 240x135 Preview Screen
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black)
                                .frame(width: 240, height: 135)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                                )

                            if let url = vm.selectedImageURL, let image = NSImage(contentsOf: url) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: vm.screenFitMode == .cover ? .fill : .fit)
                                    .frame(width: 240, height: 135)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("240 × 135 Screen")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Controls
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Button("Choose File...") {
                                    chooseFile()
                                }
                                .buttonStyle(.bordered)

                                if let url = vm.selectedImageURL {
                                    Text(url.lastPathComponent)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                            }

                            Picker("Fit Mode:", selection: $vm.screenFitMode) {
                                ForEach(ScreenFitMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Stepper("Display Slot: \(vm.screenSlot)", value: $vm.screenSlot, in: 1...255)
                                    .frame(maxWidth: 200)
                            }

                            Button {
                                vm.uploadDisplayImage()
                            } label: {
                                Label("Upload to Keyboard", systemImage: "arrow.up.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.selectedImageURL == nil || !vm.wiredConnected || vm.isWorking)
                        }
                    }

                    // Progress Bar
                    if vm.uploadProgress.totalChunks > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Uploading...")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(vm.uploadProgress.percent)% (\(vm.uploadProgress.sentChunks)/\(vm.uploadProgress.totalChunks) pages)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            ProgressView(value: vm.uploadProgress.fraction)
                                .tint(.accentColor)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Info Callout
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Display Guidelines")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("The Aula F108 Pro uses a 240x135 pixel RGB565 screen. GIFs and images with a 16:9 ratio fit best. High frame-count GIFs are automatically scaled and converted into contiguous frame buffers. Note: Screen uploads require a wired USB-C connection.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .padding(20)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, UTType(filenameExtension: "webp") ?? .image]

        if panel.runModal() == .OK {
            vm.selectedImageURL = panel.url
        }
    }
}
