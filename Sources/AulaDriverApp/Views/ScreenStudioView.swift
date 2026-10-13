import AulaKit
import SwiftUI
import UniformTypeIdentifiers

public struct ScreenStudioView: View {
    @ObservedObject var vm: AppViewModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("TFT Screen Studio")
                        .font(.system(size: 26, weight: .bold))
                    Text("Flash animations to the 1.14\" IPS display (~15–30s upload), manage GIF gallery presets, and sync clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Screen Display Mode Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Mode")
                        .font(.headline)
                    Picker("Display Mode", selection: $vm.liveLCDMode) {
                        Text("GIF Gallery").tag("gallery")
                        Text("Live Mac System Monitor").tag("monitor")
                        Text("Now Playing Music Widget").tag("nowPlaying")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.liveLCDMode) { mode in
                        vm.setLiveLCDMode(mode)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                if vm.liveLCDMode == "monitor" {
                    // System Monitor Active Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.cyan)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Mac System Monitor Active")
                                    .font(.headline)
                                Text("Pushed to keyboard screen • Refreshes every 30s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !vm.liveLCDStatus.isEmpty {
                                Text(vm.liveLCDStatus)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.cyan.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }

                        // Live Metrics Display
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CPU LOAD")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f%%", vm.liveCPUPercent))
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("RAM USAGE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f / %.0f GB", vm.liveRAMUsedGB, vm.liveRAMTotalGB))
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .foregroundColor(.purple)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("KEYBOARD SCREEN")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text("240 × 135 LCD")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 6)

                        HStack(spacing: 12) {
                            Button {
                                vm.refreshLiveLCD()
                            } label: {
                                Label("Refresh Screen Now", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Stop Stream") {
                                vm.setLiveLCDMode("gallery")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    .cornerRadius(12)
                } else if vm.liveLCDMode == "nowPlaying" {
                    // Now Playing Active Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.green)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Now Playing Widget Active")
                                    .font(.headline)
                                Text("Pushed to keyboard screen • Automatically updates on song change")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if !vm.liveLCDStatus.isEmpty {
                                Text(vm.liveLCDStatus)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }

                        // Live Track Display
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "waveform")
                                    .font(.title2)
                                    .foregroundColor(.green)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(vm.nowPlayingTitle)
                                    .font(.system(size: 18, weight: .bold))
                                    .lineLimit(1)
                                Text(vm.nowPlayingArtist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                if vm.nowPlayingProgress > 0 {
                                    ProgressView(value: vm.nowPlayingProgress)
                                        .tint(.green)
                                        .frame(maxWidth: 240)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            Button {
                                vm.refreshLiveLCD()
                            } label: {
                                Label("Push to Screen Now", systemImage: "bolt.fill")
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Stop Stream") {
                                vm.setLiveLCDMode("gallery")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
                    .cornerRadius(12)
                }

                // GIF Gallery Section (Multiple GIFs Quick Switcher)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Screen Animation Gallery")
                                .font(.headline)
                            Text("Stored locally in ready-to-stream format. Activating streams the animation directly to keyboard SPI flash (~15–30s).")
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
                                        let title = url.deletingPathExtension().lastPathComponent
                                        vm.addGIFToGallery(url: url, title: title, fitMode: vm.screenFitMode)
                                    }
                                } label: {
                                    Label("Save to Gallery", systemImage: "plus.circle")
                                }
                                .buttonStyle(.bordered)
                                .disabled(vm.selectedImageURL == nil || vm.isScreenUploading)

                                Button {
                                    if let url = vm.selectedImageURL {
                                        let title = url.deletingPathExtension().lastPathComponent
                                        vm.addGIFToGallery(url: url, title: title, fitMode: vm.screenFitMode)
                                        if let lastItem = vm.galleryItems.first {
                                            vm.activateGalleryItem(lastItem)
                                        }
                                    }
                                } label: {
                                    Label("Save & Activate", systemImage: "bolt.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.selectedImageURL == nil || !vm.wiredConnected || vm.isScreenUploading)
                            }
                        }
                    }

                    // Upload Progress Bar
                    if vm.uploadProgress.totalChunks > 0 && vm.uploadProgress.sentChunks < vm.uploadProgress.totalChunks {
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
                        Text("Hardware SPI Flash Animation Storage")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("The keyboard's onboard SPI flash holds 1 active animation slot (up to 141 frames). Because animations are written directly to physical flash memory over USB HID with hardware ACK verification, streaming an animation takes ~15–30 seconds depending on frame count. Once stored, playback runs autonomously on-hardware at smooth 30 FPS.")
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
                .disabled(!vm.wiredConnected || vm.isScreenUploading)

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
        }
    }
}
