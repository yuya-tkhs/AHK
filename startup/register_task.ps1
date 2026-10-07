# Registers a logon task that runs startup.ps1 (re-running overwrites it).
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less UTF-8 as Shift-JIS,
# and Japanese text (even in comments) breaks parsing. See CLAUDE.md "startup".
#   powershell -NoProfile -ExecutionPolicy Bypass -File register_task.ps1

$taskName = 'AhkStartup'
$script = Join-Path $PSScriptRoot 'startup.ps1'
# Max seconds to wait for the W: drive
$waitSeconds = 600

# Wait until startup.ps1 is visible, then run it read as UTF-8
$command = "`$p = '$script'; " +
    "for (`$i = 0; `$i -lt $waitSeconds -and -not (Test-Path -LiteralPath `$p); `$i++) { Start-Sleep 1 }; " +
    "if (-not (Test-Path -LiteralPath `$p)) { exit 1 }; " +
    "& ([ScriptBlock]::Create([IO.File]::ReadAllText(`$p, [Text.Encoding]::UTF8)))"

# conhost --headless: no console window
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"$command`""
$user = "$env:USERDOMAIN\$env:USERNAME"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Description 'Wait for W: drive, then run startup.ps1 (AHK repo)' -Force | Out-Null
Write-Host "Registered task '$taskName' -> $script"
