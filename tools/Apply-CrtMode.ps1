param(
    [int]$Width = 1024,
    [int]$Height = 768,
    [int]$RefreshRate = 85,
    [switch]$Disable,
    [switch]$Toggle,
    [switch]$SoloCrt,
    [switch]$SoloDell,
    [switch]$SoloPortatil,
    [switch]$Elevated
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-SelfElevate {
    $argList = "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`" -Width $Width -Height $Height -RefreshRate $RefreshRate -Elevated"
    if ($Disable)      { $argList += " -Disable" }
    if ($Toggle)       { $argList += " -Toggle" }
    if ($SoloCrt)      { $argList += " -SoloCrt" }
    if ($SoloDell)     { $argList += " -SoloDell" }
    if ($SoloPortatil) { $argList += " -SoloPortatil" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait
    exit 0
}

# 0. Check if any GPU / Display Adapter was left disabled in Device Manager and re-enable it immediately
$disabledGpus = @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'OK' })
if ($disabledGpus.Count -gt 0) {
    if (!(Test-IsAdmin)) {
        Write-Host "Reactivando tarjetas graficas (Intel Arc / NVIDIA)..." -ForegroundColor Yellow
        Invoke-SelfElevate
    }
    foreach ($gpu in $disabledGpus) {
        Write-Host "Reactivando adaptador de pantalla: $($gpu.FriendlyName)..." -ForegroundColor Cyan
        try {
            Enable-PnpDevice -InstanceId $gpu.InstanceId -Confirm:$false -ErrorAction Stop
        } catch {
            & pnputil.exe /enable-device "$($gpu.InstanceId)" | Out-Null
        }
    }
    Write-Host "Esperando a que Windows detecte los monitores externos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

# 1. Verify if all MEL40E0 / RTK1D1A EDID_OVERRIDE keys have the Master EDID (Preferred Mode: 1024x768 @ 85Hz + 110Hz Detailed Timing)
[byte[]]$masterMelEdid = @(
    0,255,255,255,255,255,255,0,52,172,224,64,71,7,0,0,19,7,1,4,165,38,28,105,226,4,136,160,87,74,155,38,
    18,72,76,36,71,0,97,89,97,79,129,89,129,79,169,79,129,143,49,89,49,79,234,36,0,96,65,0,40,48,48,96,
    19,0,104,14,17,0,0,30,28,49,0,112,65,0,53,48,80,104,52,0,0,192,16,0,0,28,174,26,128,224,32,224,47,
    16,48,64,52,0,160,120,0,0,0,28,200,50,0,168,81,192,39,48,64,128,19,0,104,14,17,0,0,30,0,87
)

$p20 = "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\MEL40E0\4&ba29b99&0&UID20549\Device Parameters\EDID_OVERRIDE"
$needsEdidSync = $false
if (Test-Path $p20) {
    $curBytes = (Get-ItemProperty $p20 -ErrorAction SilentlyContinue)."0"
    if (!$curBytes -or $curBytes[127] -ne 87) {
        $needsEdidSync = $true
    }
} else {
    $needsEdidSync = $true
}

if ($needsEdidSync) {
    if (!(Test-IsAdmin)) {
        Write-Host "Sincronizando perfiles de CRT (1024x768@85Hz nativo + 110Hz + 640@150Hz) en el registro..." -ForegroundColor Yellow
        Invoke-SelfElevate
    }
    Write-Host "Configurando modos y perfiles en todos los puertos del CRT..." -ForegroundColor Cyan
    $melKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\MEL40E0" -ErrorAction SilentlyContinue
    foreach ($k in $melKeys) {
        $edidPath = "$($k.PSPath)\Device Parameters\EDID_OVERRIDE"
        if (!(Test-Path $edidPath)) { New-Item -Path $edidPath -Force | Out-Null }
        Set-ItemProperty -Path $edidPath -Name "0" -Value $masterMelEdid -Type Binary
        Set-ItemProperty -Path $edidPath -Name "CRU_Range_Limits" -Value ([byte[]]@(0,0,50,0,152,0,30,0,95,0,220)) -Type Binary
    }
    $rtkKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\RTK1D1A" -ErrorAction SilentlyContinue
    foreach ($k in $rtkKeys) {
        $edidPath = "$($k.PSPath)\Device Parameters\EDID_OVERRIDE"
        if (!(Test-Path $edidPath)) { New-Item -Path $edidPath -Force | Out-Null }
        [byte[]]$rtkEdid = $masterMelEdid.Clone()
        $rtkEdid[8] = 74; $rtkEdid[9] = 139; $rtkEdid[10] = 26; $rtkEdid[11] = 29
        $sum126 = ($rtkEdid[0..126] | Measure-Object -Sum).Sum
        $rtkEdid[127] = (256 - ($sum126 % 256)) % 256
        Set-ItemProperty -Path $edidPath -Name "0" -Value $rtkEdid -Type Binary
        Set-ItemProperty -Path $edidPath -Name "CRU_Range_Limits" -Value ([byte[]]@(0,0,50,0,152,0,30,0,95,0,220)) -Type Binary
    }
}

# 2. Load DisplayConfig module and detect displays
Import-Module "$scriptDir\DisplayConfigModule\DisplayConfig.psd1" -Force

$crt = $null
$dell = $null
$laptop = $null

for ($attempt = 1; $attempt -le 5; $attempt++) {
    $all = Get-DisplayInfo
    $crt = $all | Where-Object { 
        $_.DisplayName -like "*TFW9105*" -or 
        ($_.ConnectionType -ne "Internal" -and $_.DisplayName -notlike "*DELL*") 
    } | Select-Object -First 1
    $dell = $all | Where-Object { $_.DisplayName -like "*DELL*" } | Select-Object -First 1
    $laptop = $all | Where-Object { $_.ConnectionType -eq "Internal" -or ($_.DisplayId -ne $crt.DisplayId -and $_.DisplayId -ne $dell.DisplayId) } | Select-Object -First 1

    if ($crt -and $dell) { break }
    Start-Sleep -Seconds 1
}

if (!$crt) {
    Write-Host "[ERROR] No se encontro el monitor CRT conectado." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit 1
}

try {
    # CASE 1: Toggle CRT state
    if ($Toggle) {
        if ($crt.Active -eq $true) {
            $Disable = $true
        } else {
            $Width = 1024
            $Height = 768
            $RefreshRate = 85
        }
    }

    # CASE 2: Disable CRT (cuts signal -> CRT enters standby/powersave)
    if ($Disable) {
        Write-Host "Desactivando monitor CRT en Windows y fijando Dell como principal..." -ForegroundColor Yellow
        $twoOrder = [uint32[]]@($dell.DisplayId, $laptop.DisplayId)
        Get-DisplayConfig | 
            Disable-Display -DisplayId $crt.DisplayId | 
            Set-DisplayPrimary -DisplayId $dell.DisplayId | 
            Set-DisplayPosition -LeftToRightDisplayIds $twoOrder -AllowChanges | 
            Use-DisplayConfig -AllowChanges
        Write-Host "[OK] CRT desactivado. Entrara en modo suspension/ahorro en unos segundos." -ForegroundColor Green
        Start-Sleep -Seconds 2
        exit 0
    }

    # CASE 3: Activate CRT if inactive
    if ($crt.Active -eq $false -and !$SoloPortatil -and !$SoloDell) {
        Write-Host "Activando monitor CRT..." -ForegroundColor Yellow
        try {
            Enable-Display -DisplayId $crt.DisplayId -ErrorAction Stop
        } catch {
            Write-Host "Activando mediante MultiMonitorTool..." -ForegroundColor Yellow
            & "$scriptDir\MultiMonitorTool.exe" /enable "MEL40E0" 2>$null
            & "$scriptDir\MultiMonitorTool.exe" /turn_on "MEL40E0" 2>$null
        }
        Start-Sleep -Milliseconds 800
        $all = Get-DisplayInfo
        $crt = $all | Where-Object { 
            $_.DisplayName -like "*TFW9105*" -or 
            ($_.ConnectionType -ne "Internal" -and $_.DisplayName -notlike "*DELL*") 
        } | Select-Object -First 1
    }

    # CASE 4: Solo CRT (Apagar Dell y Portatil, dejar solo la CRT activa)
    if ($SoloCrt) {
        Write-Host "Dejando exclusivamente el CRT encendido (apagando Dell y Portatil)..." -ForegroundColor Yellow
        Get-DisplayConfig | 
            Set-DisplayPrimary -DisplayId $crt.DisplayId | 
            Disable-Display -DisplayId $dell.DisplayId, $laptop.DisplayId | 
            Set-DisplayResolution -DisplayId $crt.DisplayId -Width $Width -Height $Height -ChangeAspectRatio | 
            Use-DisplayConfig -AllowChanges
        try {
            Set-DisplayRefreshRate -DisplayId $crt.DisplayId -RefreshRate $RefreshRate -AllowChanges
        } catch {
            Set-DisplayRefreshRate -DisplayId $crt.DisplayId -RefreshRate 75 -AllowChanges -ErrorAction SilentlyContinue
        }
        Write-Host "[OK] Listo: Solo CRT encendido en ${Width}x${Height} @ ${RefreshRate}Hz." -ForegroundColor Green
        Write-Host "(Para recuperar todas las pantallas, usa 'Restaurar_Monitores.bat')" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
        exit 0
    }

    # CASE 5: Solo Dell (Apagar CRT y Portatil, dejar solo Dell activo)
    if ($SoloDell) {
        Write-Host "Dejando exclusivamente el monitor Dell encendido..." -ForegroundColor Yellow
        Get-DisplayConfig | 
            Set-DisplayPrimary -DisplayId $dell.DisplayId | 
            Disable-Display -DisplayId $crt.DisplayId, $laptop.DisplayId | 
            Use-DisplayConfig -AllowChanges
        Write-Host "[OK] Listo: Solo Dell encendido." -ForegroundColor Green
        Write-Host "(Para recuperar todas las pantallas, usa 'Restaurar_Monitores.bat')" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
        exit 0
    }

    # CASE 6: Solo Portatil (Apagar CRT y Dell, dejar solo Portatil activo)
    if ($SoloPortatil) {
        Write-Host "Dejando exclusivamente la pantalla del portatil encendida..." -ForegroundColor Yellow
        Get-DisplayConfig | 
            Set-DisplayPrimary -DisplayId $laptop.DisplayId | 
            Disable-Display -DisplayId $crt.DisplayId, $dell.DisplayId | 
            Use-DisplayConfig -AllowChanges
        Write-Host "[OK] Listo: Solo pantalla del portatil encendida (Dell y CRT en suspension)." -ForegroundColor Green
        Write-Host "(Para recuperar todas las pantallas, usa 'Restaurar_Monitores.bat')" -ForegroundColor Cyan
        Start-Sleep -Seconds 2
        exit 0
    }

    # Normal / Restore mode: Ensure Dell and Laptop are active too
    $inactiveDisplays = $all | Where-Object { $_.Active -eq $false -and $_.DisplayId -ne $crt.DisplayId }
    if ($inactiveDisplays) {
        foreach ($d in $inactiveDisplays) {
            Write-Host "Reactivando pantalla ID $($d.DisplayId)..." -ForegroundColor Yellow
            try {
                Enable-Display -DisplayId $d.DisplayId -ErrorAction Stop
            } catch {
                & "$scriptDir\MultiMonitorTool.exe" /enable $d.DisplayId 2>$null
            }
        }
        Start-Sleep -Milliseconds 800
        $all = Get-DisplayInfo
        $crt = $all | Where-Object { 
            $_.DisplayName -like "*TFW9105*" -or 
            ($_.ConnectionType -ne "Internal" -and $_.DisplayName -notlike "*DELL*") 
        } | Select-Object -First 1
        $dell = $all | Where-Object { $_.DisplayName -like "*DELL*" } | Select-Object -First 1
        $laptop = $all | Where-Object { $_.ConnectionType -eq "Internal" -or ($_.DisplayId -ne $crt.DisplayId -and $_.DisplayId -ne $dell.DisplayId) } | Select-Object -First 1
    }

    # Step A: Apply Resolution + Dell as Primary + LeftToRight layout [CRT -> Dell -> Laptop]
    Write-Host "Configurando disposicion: [CRT (Izquierda)] -> [Dell (Centro, Principal)] -> [Portatil (Derecha)]..." -ForegroundColor Cyan
    $order = [uint32[]]@($crt.DisplayId, $dell.DisplayId, $laptop.DisplayId)

    Get-DisplayConfig | 
        Set-DisplayResolution -DisplayId $crt.DisplayId -Width $Width -Height $Height | 
        Set-DisplayPrimary -DisplayId $dell.DisplayId | 
        Set-DisplayPosition -LeftToRightDisplayIds $order -AllowChanges | 
        Set-DisplayResolution -DisplayId $crt.DisplayId -Width $Width -Height $Height -ChangeAspectRatio | 
        Use-DisplayConfig -AllowChanges

    # Step B: Apply exact refresh rate on the active resolution (with compatible fallback)
    Write-Host "Aplicando frecuencia de refresco: ${RefreshRate} Hz..." -ForegroundColor Cyan
    try {
        Set-DisplayRefreshRate -DisplayId $crt.DisplayId -RefreshRate $RefreshRate -AllowChanges
    } catch {
        Write-Host "Nota: ${RefreshRate} Hz no disponible directamente, probando modo compatible..." -ForegroundColor Yellow
        if ($RefreshRate -eq 110) {
            Set-DisplayRefreshRate -DisplayId $crt.DisplayId -RefreshRate 100 -AllowChanges -ErrorAction SilentlyContinue
        } elseif ($RefreshRate -eq 150) {
            Set-DisplayRefreshRate -DisplayId $crt.DisplayId -RefreshRate 120 -AllowChanges -ErrorAction SilentlyContinue
        } else {
            Set-DisplayRefreshRate -DisplayId $crt.DisplayId -RefreshRate 75 -AllowChanges -ErrorAction SilentlyContinue
        }
    }

    Write-Host "[OK] Listo: CRT en ${Width}x${Height} @ ${RefreshRate}Hz a la izquierda del Dell." -ForegroundColor Green
    Start-Sleep -Seconds 2
} catch {
    if (!(Test-IsAdmin) -and !$Elevated) {
        Write-Host "Elevando permisos de Administrador para aplicar la configuracion..." -ForegroundColor Yellow
        Invoke-SelfElevate
    } else {
        Write-Host "[ERROR] $_" -ForegroundColor Red
        Start-Sleep -Seconds 4
    }
}
