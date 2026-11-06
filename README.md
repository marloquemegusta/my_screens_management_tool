# CRT Controller & Multi-Monitor Topology Automator for Windows 11

[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20(24H2%20%2F%20WDDM%203.x)-blue.svg)]()
[![Shell](https://img.shields.io/badge/Shell-PowerShell%205.1%2B%20%2F%20Batch-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)]()

A lightweight, zero-dependency automation toolkit for managing multi-monitor setups that combine high-end vintage **CRT monitors** (via active HDMI/DisplayPort to VGA DAC converters) with modern LCD panels under **Windows 11**.

---

## 📺 The Problem

Pairing high-end aperture grille CRT monitors (such as the *Mitsubishi Diamond Pro 91TXM*) with modern multi-monitor Windows 11 systems introduces severe friction:

1. **Broken Legacy APIs**: Windows 11 24H2 with WDDM 3.x and hybrid graphics (Intel Arc / NVIDIA RTX) causes classic display utilities (`ChangeDisplaySettingsEx`, legacy MultiMonitor tools) to return `-1` or randomly swap monitor coordinates.
2. **Missing Power Management (DPMS) via HDMI-to-VGA DACs**: Active HDMI/DP-to-VGA converters often keep sending sync rasters even when no content is shown, forcing users to reach behind the heavy CRT to turn the power switch off manually to prevent wear on the flyback transformer and phosphor.
3. **"Frequency Out of Range" Panic**: When modern Windows enables a display, it defaults to the highest detailed timing or first EDID descriptor (often 1600x1200 or 110Hz+). On vintage monitors, an H-scan frequency exceeding 90–95 kHz trips the chassis protection circuit, showing a red *"Frequency Out of Range"* screen.
4. **Desktop Layout Drift**: Every resolution change or power cycle scatters windows and swaps the logical order of monitors.

---

## ✨ Features

- **1-Click Hardware Power-Save (VESA DPMS Trigger)**: Disables the CRT display path at the WDDM level, immediately cutting digital TMDS clock signals to the active converter. The CRT detects zero sync and automatically drops into sleep / standby mode (amber LED / relay click off) without sleeping the PC.
- **Safe Native Mode Auto-Boot**: Activates the CRT directly in a flicker-free, rock-solid **`1024x768 @ 85 Hz`** mode (H-Scan: ~68 kHz, well within the 30–95 kHz spec), completely eliminating out-of-range errors.
- **Deterministic Multi-Monitor Layout**: Dynamically anchors the monitors in physical order:
  $$\text{[CRT (Left, } X < 0\text{)]} \longrightarrow \text{[Dell LCD (Center, Primary, } X=0\text{)]} \longrightarrow \text{[Laptop Panel (Right, } X > 0\text{)]}$$
- **Dedicated Isolation Modes**:
  - `Solo_CRT.bat`: Puts both LCDs to sleep and leaves solely the CRT active for retro gaming, emulators, or high-motion video.
  - `Solo_Dell.bat`: Puts CRT and Laptop panels to sleep.
  - `Solo_Portatil.bat`: Puts all external monitors into standby when moving around.
  - `Restaurar_Monitores.bat`: Wakes all displays and re-aligns the full multi-screen desktop.
- **Resolution & Refresh Rate Profiles**: Instant switching between 1600x1200 @ 75Hz, 1280x960 @ 85/75Hz, 1024x768 @ 85/75Hz, and 640x480 @ 150/75Hz.

---

## 🛠️ Hardware Setup Tested

- **CRT Monitor**: Mitsubishi Diamond Pro 91TXM 19" Aperture Grille (`MEL40E0` / `TFW9105`)
  - Horizontal Scan: 30 – 95 kHz
  - Vertical Scan: 50 – 152 Hz
  - Connection: Realtek HDMI-to-VGA active DAC (`RTK1D1A`)
- **Primary Monitor**: DELL U2422H (1920x1080 @ 60 Hz, DisplayPort)
- **Secondary Monitor**: 16" 16:10 Laptop Panel (1920x1200 @ 60 Hz, Internal eDP)
- **OS / Drivers**: Windows 11 Pro 24H2 (Intel Arc Pro Graphics + NVIDIA RTX 3000 Ada)

---

## 🚀 Usage

Double-click any `.bat` script from the folder:

| Script | Purpose |
| :--- | :--- |
| **`Activar_CRT.bat`** | Wakes CRT from standby, sets 1024x768 @ 85 Hz, and arranges `[CRT] -> [Dell] -> [Laptop]`. |
| **`Desactivar_CRT.bat`** | Cuts signal to the CRT (monitor enters sleep by itself); sets Dell as primary. |
| **`Alternar_CRT.bat`** | Toggle switch (turns CRT on if asleep, or off if active). |
| **`Solo_CRT.bat`** | Puts LCDs into power-save; runs exclusively on the CRT. |
| **`Solo_Dell.bat`** | Puts CRT and laptop panel into power-save. |
| **`Solo_Portatil.bat`** | Puts external displays into power-save; leaves only the laptop screen active. |
| **`Restaurar_Monitores.bat`** | Wakes all 3 monitors and restores default multi-monitor geometry. |
| **`Perfil_*.bat`** | Switches resolution on the CRT while maintaining multi-screen alignment. |

---

## ⚙️ Architecture & Technical Details

The backend driver is implemented in **`tools/Apply-CrtMode.ps1`** using the native Windows `SetDisplayConfig` API exposed via `MartinGC94/DisplayConfig`:

```
User Double-Click (.bat)
        │
        ▼
   Apply-CrtMode.ps1 (Self-elevates if WDDM access requires it)
        │
        ├─► GPU Status Health Check (Re-enables paused adapters if needed)
        ├─► Registry EDID Validation (Ensures 1024x768@85Hz is Preferred Mode)
        ├─► Query Display Topology (Get-DisplayConfig)
        │
        ├─► [Action: Disable / Enable / Solo / Resolution]
        ├─► Topology Positioning: Left-To-Right Display IDs Array
        ├─► Set-DisplayResolution with -ChangeAspectRatio (Invalidates target mode)
        ├─► Set-DisplayRefreshRate (Safe VESA Timings)
        │
        ▼
   Use-DisplayConfig -AllowChanges
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
