# My Screens Management Tool (CRT + Multi-Monitor Setup)

> **⚠️ Note / Disclaimer**: This repository is **not** a plug-and-play or universal tool intended for arbitrary setups. It is tailored and **hardcoded for my specific 3-monitor workstation** (exact display names, converter IDs, EDID binary overrides, and physical ordering). It is shared publicly as personal portfolio work, documentation, and inspiration for anyone wrestling with retro CRT monitors, active HDMI-to-VGA DACs, and modern Windows 11 display management.

---

## 💡 Why this exists

I use a vintage 19" aperture grille CRT monitor alongside a modern Dell IPS display and a laptop panel on Windows 11 (24H2 with hybrid Intel Arc / NVIDIA RTX graphics). 

While it looks fantastic for retro games and text, modern Windows display settings and legacy third-party tools constantly misbehave:
- Old utilities relying on `ChangeDisplaySettingsEx` fail with error `-1` under WDDM 3.x.
- Changing resolutions frequently scrambles the physical layout order of the three screens.
- Active HDMI-to-VGA converters often keep the sync signals alive even when no image is shown, preventing the CRT from going into power save mode.
- Turning on the CRT or extending the desktop without precautions can cause Windows to send an out-of-spec timing (such as 1600x1200 or 110Hz+), triggering the monitor's red *"Frequency Out of Range"* protection screen.

This repo contains the set of scripts I built to automate my daily workflow into 1-click batch files on my desktop.

---

## 🖥️ My Specific Hardware & Layout

The script logic in `tools/Apply-CrtMode.ps1` explicitly expects and identifies:

| Monitor | Physical Identity | Role & Position in my setup |
| :--- | :--- | :--- |
| **Mitsubishi Diamond Pro 91TXM** | `MEL40E0` / `TFW9105` (via Realtek HDMI-to-VGA DAC `RTK1D1A`) | **Left screen** ($X < 0$), retro/CRT tasks |
| **DELL U2422H** | Display name matching `*DELL*` | **Center screen** ($X = 0$), Primary display |
| **Laptop Panel** | Identified by `ConnectionType -eq "Internal"` | **Right screen** ($X > 0$), secondary LCD |

```
┌────────────────────────┐  ┌────────────────────────┐  ┌────────────────────────┐
│  Mitsubishi 91TXM CRT  │  │      DELL U2422H       │  │     Laptop Screen      │
│   (Left / Auxiliary)   │  │   (Center / Primary)   │  │   (Right / Secondary)  │
└────────────────────────┘  └────────────────────────┘  └────────────────────────┘
```

---

## ⚙️ What the scripts actually do

1. **True VESA DPMS Power-Saving for the CRT**:
   - `Desactivar_CRT.bat` disables the display path at the WDDM level (`Disable-Display` via `MartinGC94/DisplayConfig`). This cuts digital TMDS clock signals to the HDMI-to-VGA converter, causing it to drop analog H/V-sync. The CRT detects loss of signal and clicks off into standby by itself (amber LED, flyback off).
2. **Safe Wake-up & Order Enforcement**:
   - `Activar_CRT.bat` wakes the CRT, forces a safe native mode (`1024x768 @ 85 Hz`, H-Scan ~68 kHz) to prevent out-of-range errors, and enforces the physical order `[CRT] -> [Dell (Primary)] -> [Laptop]`.
3. **Single-Display Focus Modes**:
   - `Solo_CRT.bat`: Puts both modern LCDs into standby and runs solely on the CRT.
   - `Solo_Dell.bat`: Puts CRT and Laptop to sleep; runs solely on the Dell.
   - `Solo_Portatil.bat`: Puts external monitors to sleep when stepping away.
   - `Restaurar_Monitores.bat`: Wakes all three displays and re-aligns the multi-screen desktop.
4. **Resolution Switchers**:
   - Batch scripts for switching CRT profiles (`1600x1200 @ 75Hz`, `1280x960 @ 85/75Hz`, `1024x768 @ 85/75Hz`, `640x480 @ 150/75Hz`) while keeping the desktop geometry pinned in place.

---

## 🔍 Hardcoded Aspects & Taking Inspiration

If you are looking at this for your own multi-monitor or CRT setup, keep in mind:

- **Display IDs & String Matching**: Inside `tools/Apply-CrtMode.ps1`, displays are filtered with patterns like `DisplayName -like "*TFW9105*"` and `DisplayName -like "*DELL*"`. You will need to inspect your displays via `Get-DisplayInfo` and adjust those conditions for your hardware.
- **EDID Overrides**: The script injects a custom 128-byte EDID binary array into registry paths under `HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\MEL40E0` and `RTK1D1A` to guarantee that Windows recognizes the CRT's VESA range limits and uses `1024x768 @ 85 Hz` as the preferred timing (Descriptor 0). Do not apply these bytes to an LCD panel or a monitor with different chassis limits.
- **WDDM Display API**: The core solution uses the PowerShell module `MartinGC94/DisplayConfig` (wrapping `SetDisplayConfig`), which is significantly more reliable on modern Windows 11 than legacy Win32 display APIs.

---

## 📄 License

MIT. Use any part of the logic or scripts as inspiration for your own setup.
