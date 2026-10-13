# Aula F108 Pro Driver for macOS 

A high-performance, native macOS driver and companion application suite for the **Aula F108 Pro** (Suoai / Sonix MCU) tri-mode mechanical keyboard.

Since the manufacturer only provides Windows binaries (`AULA F108Pro.exe`), this suite provides full control over 100% of the keyboard's features natively on macOS without requiring virtual machines, drivers, or kexts.

---

## Features

- 🖥️ **TFT Screen Studio (240 × 135 IPS Color Display)**:
  - 1-click system clock & date synchronization.
  - Upload custom animated GIFs, PNGs, and JPEGs.
  - Multi-frame GIF playback with custom frame delay encoding into 16-bit RGB565 format.
  - Fit modes: Aspect Fit, Fill / Crop, and Stretch.
  - Slot selector (1–255) with progress tracking.
- 🌈 **RGB Lighting Studio**:
  - Control all 20 hardware preset lighting effects (Rolling, Breathing, Spectrum, Ripples, Shuttle, etc.).
  - Brightness (0–5), speed (1–5), and direction (Left, Right, Up, Down) tuning.
  - Rainbow cycling toggle and custom 24-bit RGB Hex color picker.
  - Per-key custom RGB lighting matrix designer.
- ⌨️ **Apple Mac Layout Mode & Key Remapping**:
  - **Single-Click Mac Ergonomics**: Directly swaps Left Win (Cmd) and Left Alt (Opt) inside keyboard memory to match the physical Apple keyboard layout: `Control - Option - Command - Space`.
  - Full dual-layer remapping: Normal Layer and FN Layer across all 108 physical keys.
  - Map keys to standard codes, modifiers, media/consumer controls (Play, Pause, Mute, Volume), or mouse actions.
- ⚡ **Performance & Debounce**:
  - Hardware response level: Level 1 Fastest (5–6 ms) up to Level 5 Max Stability (19–21 ms).
  - Sleep timer: Never, 1 min, 5 min, 30 min.
  - Game Mode toggle (Win Lock).
- 🔋 **Battery & Dual Form Factor**:
  - Menu Bar Extra showing live battery percentage and quick controls.
  - Full desktop Dashboard window.
  - Multi-profile management (`~/Library/Application Support/AulaDriver/profiles/`) to switch between Work, Coding, and Gaming presets.
- 💻 **Terminal CLI (`aula-cli`)**:
  - Fast command-line interface for scripting, terminal power-users, and automation.

---

## Quick Start

### Build & Run

```bash
# Build release binaries
make build

# Run the test suite (38 automated unit tests)
make test

# Run the macOS SwiftUI App (Menu Bar + Dashboard)
make run-app

# Install aula-cli to ~/.local/bin
make install-cli
```

---

## CLI Usage (`aula-cli`)

```bash
# Scan and inspect connected USB & 2.4G HID endpoints
aula-cli info

# Synchronize the keyboard LCD clock to system time
aula-cli clock sync

# Configure RGB lighting
aula-cli rgb set --mode 11 --speed 3 --brightness 5 --colorful
aula-cli rgb set --mode 1 --color "#00FF88"
aula-cli rgb off
aula-cli rgb list

# Upload an image or animated GIF to the 240x135 screen
aula-cli screen upload animation.gif --slot 1 --fit fill

# Toggle Apple Mac Layout mode (swaps Left Win and Left Alt)
aula-cli remap mac-layout on
aula-cli remap mac-layout off
aula-cli remap reset

# Set debounce level and sleep timer
aula-cli perf --level 1 --sleep 1

# Query battery percentage via 2.4G receiver
aula-cli battery
```

---

## Reverse-Engineered HID Protocol Reference

- **USB Wired Identifiers**: `Vendor ID: 0x0C45` (Sonix), `Product ID: 0x800A` (AULA F108Pro).
- **2.4G Dongle Identifiers**: `Vendor ID: 0x05AC`, `Product ID: 0x024F`.
- **Endpoints**:
  - `Interface 0` (`0x01:0x06`): Standard HID Keyboard.
  - `Interface 1` (`0x0C:0x01`): Consumer Control (Rotary knob volume/media).
  - `Interface 2` (`0xFF68:0x61`): Screen stream (4096-byte Output reports, 64-byte Input ACKs).
  - `Interface 3` (`0xFF13:0x01`): Configuration (64-byte Feature reports).
- **Transaction Handshake**:
  - Begin: `04 18 00 00 ...` (with readback ACK)
  - Init: `04 13` (RGB), `04 28` (Clock), `04 11` (Normal Remap), `04 27` (FN Remap), `04 72` (Screen Header)
  - Commit / Apply: `04 02 00 00 ...` (with readback ACK)
  - Finalize: `04 F0 00 00 ...` (no readback)

---

## License

MIT License.
