import AulaKit
import SwiftUI
import UniformTypeIdentifiers

public struct ScreenStudioView: View {
    @ObservedObject var vm: AppViewModel
    @State private var customTitle = ""

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("TFT Screen Studio")
                        .font(.system(size: 26, weight: .bold))
                    Text("Customize the 1.14\" 240×135 IPS Display with instant GIF switching, gallery presets, and clock sync")
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
                        Label("Sync Clock", systemImage: "clock.badge.checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.wiredConnected)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // GIF Gallery Section (Multiple GIFs Quick Switcher)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Animation Gallery")
                                .font(.headline)
                            Text("Stored locally in pre-encoded format for instant 1-click activation without re-encoding.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(vm.galleryItems.count) Saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if vm.galleryItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No animations in gallery yet")
                                .font(.headline)
                            Text("Add your favorite GIFs below to switch between them anytime with a single click.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 16)], spacing: 16) {
                            ForEach(vm.galleryItems) { item in
                                galleryCard(for: item)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // New Animation / File Uploader
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add Animation to Gallery")
                        .font(.headline)

                    HStack(alignment: .top, spacing: 24) {
                        // 240x135 Screen Preview
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
                                    Image(systemName: "plus.rectangle.on.rectangle")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("240 × 135 Preview")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Form Controls
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

                            TextField("Title (e.g. Cyberpunk Cat)", text: $customTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 280)

                            Picker("Fit Mode:", selection: $vm.screenFitMode) {
                                ForEach(ScreenFitMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 300)

                            HStack(spacing: 12) {
                                Button {
                                    if let url = vm.selectedImageURL {
                                        let title = customTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : customTitle
                                        vm.addGIFToGallery(url: url, title: title, fitMode: vm.screenFitMode)
                                        customTitle = ""
                                    }
                                } label: {
                                    Label("Save to Gallery", systemImage: "plus.circle")
                                }
                                .buttonStyle(.bordered)
                                .disabled(vm.selectedImageURL == nil || vm.isWorking)

                                Button {
                                    if let url = vm.selectedImageURL {
                                        let title = customTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : customTitle
                                        vm.addGIFToGallery(url: url, title: title, fitMode: vm.screenFitMode)
                                        if let lastItem = vm.galleryItems.first {
                                            vm.activateGalleryItem(lastItem)
                                        }
                                        customTitle = ""
                                    }
                                } label: {
                                    Label("Save & Activate", systemImage: "bolt.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.selectedImageURL == nil || !vm.wiredConnected || vm.isWorking)
                            }
                        }
                    }

                    // Upload Progress Bar
                    if vm.uploadProgress.totalChunks > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Streaming to LCD Screen...")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
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

                // Info Guidelines
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Instant GIF Gallery Architecture")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("The keyboard's SPI flash holds 1 active animation slot (capped at 141 frames to protect menu graphics). The driver maintains your gallery on disk in ready-to-stream RGB565 binary format. Switching between animations sends the pre-encoded stream directly over USB-C in 1–3 seconds with 0 re-encoding delay.")
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

    @ViewBuilder
    private func galleryCard(for item: ScreenGalleryItem) -> some View {
        let originalURL = ScreenGalleryManager.shared.getOriginalURL(for: item)
        let thumbImage = NSImage(contentsOf: originalURL)

        VStack(alignment: .leading, spacing: 8) {
            // Preview Thumbnail
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(item.isActive ? Color.green : Color.secondary.opacity(0.2), lineWidth: item.isActive ? 2 : 1)
                    )

                if let thumb = thumbImage {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)
                }

                if item.isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                        .padding(6)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(item.frameCount) frames • \(item.chunkCount * 4) KB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    vm.activateGalleryItem(item)
                } label: {
                    Label(item.isActive ? "Re-stream" : "Activate", systemImage: "bolt.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.wiredConnected || vm.isWorking)

                Spacer()

                Button {
                    vm.removeGalleryItem(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.isActive ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, UTType(filenameExtension: "webp") ?? .image]

        if panel.runModal() == .OK {
            vm.selectedImageURL = panel.url
            if customTitle.isEmpty, let name = panel.url?.deletingPathExtension().lastPathComponent {
                customTitle = name
            }
        }
    }
}
