# CRT Multi-Monitor Automation & Topology Controller

Instrucciones y especificaciones técnicas para agentes y desarrolladores que mantengan o extiendan este proyecto.

---

## 1. Contexto de Hardware y Topología

El sistema controla una configuración de triple monitor heterogénea bajo Windows 11 (WDDM 3.x / Build 24H2) con GPUs híbridas (Intel Arc Pro Graphics + NVIDIA RTX Ada):

| Monitor | Tipo / Conexión | Resolución Física / Modos | Posición Relativa |
| :--- | :--- | :--- | :--- |
| **Mitsubishi Diamond Pro 91TXM** (`MEL40E0` / `TFW9105`) | CRT Aperture Grille 19" conectado vía conversor activo HDMI a VGA Realtek (`RTK1D1A`) | 640x480 hasta 1600x1200 (H-Scan: 30-95 kHz, V-Scan: 50-152 Hz) | **Izquierda** ($X = -\text{Width}, Y = 0$) |
| **DELL U2422H** (`DELA1B8`) | LCD IPS 24" (DisplayPort) | 1920x1080 @ 60 Hz | **Centro / Pantalla Principal** ($X = 0, Y = 0$) |
| **Panel Interno Portátil** (`BOE0CFC`) | LCD 16" 16:10 (Internal eDP) | 1920x1200 @ 60 Hz | **Derecha** ($X = 1920, Y = 0$) |

---

## 2. Decisiones Técnicas y Lecciones Aprendidas

1. **Gestión de Topología con WDDM 3.x (Windows 11 24H2):**
   - Las APIs clásicas (`ChangeDisplaySettingsEx`, utilidades antiguas basadas en GDI) devuelven error `-1` o descolocan las pantallas al mezclar monitores modernos eDP/DP con salidas convertidas a VGA.
   - La solución estándar y estable es la API nativa `SetDisplayConfig` de Windows (usando el módulo PowerShell `MartinGC94/DisplayConfig`).

2. **Control de Energía VESA DPMS en CRT vía HDMI:**
   - La pantalla CRT Mitsubishi entra en suspensión por sí sola (apagando el tubo de rayos catódicos y el relé de alta tensión) cuando se desactiva la ruta de pantalla en Windows (`Disable-Display | Use-DisplayConfig`). Al cesar la señal digital HDMI hacia el conversor Realtek, este corta las señales de sincronismo analógicas H/V-Sync, activando el modo DPMS del monitor sin necesidad de suspender o apagar el PC.

3. **Prevención de *"Frequency Out of Range"*:**
   - Al reactivar una pantalla, Windows consulta el **Descriptor 0 (Preferred Timing Mode)** del EDID.
   - El Descriptor 0 debe ser siempre **`1024x768 @ 85 Hz`** (H-Scan: 68.68 kHz, PClk: 94.5 MHz) como modo de encendido/arranque seguro.
   - El Descriptor 1 define **`1024x768 @ 110 Hz`** (H-Scan: 90.32 kHz, PClk: 125.72 MHz) para cambio de perfil manual ultra-fluido una vez el monitor está encendido.
   - NUNCA fijar 110 Hz ni 1600x1200 como modo preferido (Descriptor 0) en el arranque, ya que durante el apretón de manos inicial de Windows puede disparar la protección de frecuencia antes de inicializar la topología.

4. **Prohibición de reinicio forzado de drivers:**
   - NUNCA llamar a `restart64.exe` con terminaciones de proceso forzadas (`Stop-Process`). Interrumpir el reinicio del driver de vídeo deja los adaptadores gráficos en estado `CM_PROB_DISABLED` en el Administrador de dispositivos.

---

## 3. Estructura de Scripts y Archivos

- **`tools/Apply-CrtMode.ps1`**: Núcleo de automatización en PowerShell. Detecta pantallas, auto-eleva privilegios si es necesario, reactiva GPUs si estuviesen desactivadas, aplica resoluciones y ajusta topología.
- **`Activar_CRT.bat`**: Enciende el CRT a 1024x768 @ 85 Hz y lo coloca a la izquierda del Dell.
- **`Desactivar_CRT.bat`**: Corta la señal del CRT; el monitor entra en reposo y el Dell queda como principal con el portátil a la derecha.
- **`Alternar_CRT.bat`**: Conmutador (toggle) encendido / apagado para el CRT.
- **`Solo_CRT.bat`**: Apaga Dell y Portátil; deja únicamente encendida la pantalla CRT.
- **`Solo_Dell.bat`**: Apaga CRT y Portátil; deja únicamente el Dell LCD.
- **`Solo_Portatil.bat`**: Apaga monitores externos; deja solo el panel del portátil.
- **`Restaurar_Monitores.bat`**: Enciende los 3 monitores y restablece `[CRT] -> [Dell Principal] -> [Portátil]`.
- **`Perfil_*.bat`**: Perfiles de resolución dedicados para el CRT (1600x1200, 1280x960, 1024x768, 640x480).
