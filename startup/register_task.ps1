# Registers a logon task that runs startup.ps1 (re-running overwrites it).
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less UTF-8 as Shift-JIS,
# and Japanese text (even in comments) breaks parsing. See CLAUDE.md "startup".
#   powershell -NoProfile -ExecutionPolicy Bypass -File register_task.ps1

$taskName = 'AhkStartup'
$script = Join-Path $PSScriptRoot 'startup.ps1'
$repo = Split-Path $PSScriptRoot
$log = Join-Path $env:LOCALAPPDATA 'AhkStartup\startup.log'
# Max seconds to wait for the W: drive
$waitSeconds = 600

# Wait until startup.ps1 is visible, then run it read as UTF-8
$command = "`$p = '$script'; " +
    "for (`$i = 0; `$i -lt $waitSeconds -and -not (Test-Path -LiteralPath `$p); `$i++) { Start-Sleep 1 }; " +
    "if (-not (Test-Path -LiteralPath `$p)) { `$l = '$log'; New-Item -ItemType Directory -Force (Split-Path `$l) | Out-Null; " +
    "Add-Content -LiteralPath `$l -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' W: wait timed out ($waitSeconds s)'); exit 1 }; " +
    "& ([ScriptBlock]::Create([IO.File]::ReadAllText(`$p, [Text.Encoding]::UTF8)))"

# Apps started by the task inherit its priority. The default (7) is BelowNormal for CPU and
# low for I/O, so use 4 (Normal).
$priority = 4

# conhost --headless: no console window
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"$command`""
$user = "$env:USERDOMAIN\$env:USERNAME"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew -Priority $priority
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Description 'Wait for W: drive, then run startup.ps1 (AHK repo)' -Force | Out-Null
Write-Host "Registered task '$taskName' -> $script"

# Remove Startup-folder shortcuts that startup.ps1 now launches (or that point to files removed
# from this repo, e.g. the old startup_manager.ahk). Leaving them would start the app twice, and
# Explorer would still touch W: right after logon.
# Keep $appSuffixes in sync with $apps in startup.ps1 (ASCII parts of the paths only).
$appSuffixes = @('\Eagle.exe', '\TVClock.exe', '\carnac\Setup.exe')
$startup = [Environment]::GetFolderPath('Startup')
$shell = New-Object -ComObject WScript.Shell
Get-ChildItem -LiteralPath $startup -Filter *.lnk | ForEach-Object {
    $target = $shell.CreateShortcut($_.FullName).TargetPath
    $inRepo = $target.StartsWith($repo + '\',[StringComparison]::OrdinalIgnoreCase)
    $isApp = $appSuffixes | Where-Object { $target.EndsWith($_, [StringComparison]::OrdinalIgnoreCase) }
    if ($inRepo -or $isApp) {
        Remove-Item -LiteralPath $_.FullName
        Write-Host "Removed startup shortcut '$($_.Name)' -> $target"
    }
}
