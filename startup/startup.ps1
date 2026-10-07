# ログイン後、W:ドライブの準備を待ってからアプリを起動する本体。
# タスクスケジューラ（register_task.ps1 で登録）から呼ばれる。タスク側でこのファイルが見えるまで待ってから、
# UTF-8 として読み込んで実行する（Windows PowerShell 5.1 は BOM無しUTF-8 を Shift-JIS として読むため）。
# そのため $PSScriptRoot は空になる。パスはすべて絶対パスで書く。

# 起動するアプリ。無いものは飛ばす（TVClock は自宅PCにしか無い）
# Process … 起動済みか調べるプロセス名。exe名と違うときだけ書く
$apps = @(
    @{ Path = 'C:\Program Files\Eagle\Eagle.exe' }
    @{ Path = "$env:LOCALAPPDATA\Team Hasebe\TVClock\TVClock.exe" }
    @{ Path = 'W:\マイドライブ\Programming\carnac\Setup.exe'; Process = 'Carnac' }
)

# ドライブが見えた直後は不安定なことがあるので少し待つ
$settleSeconds = 3
# アプリごとの起動間隔（負荷分散）
$intervalSeconds = 1

$logPath = Join-Path $env:LOCALAPPDATA 'AhkStartup\startup.log'

function Write-Log([string]$message) {
    $dir = Split-Path $logPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
    Add-Content -LiteralPath $logPath -Encoding UTF8 -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $message)
}

function Show-Toast([string]$title, [string]$body) {
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $texts = $xml.GetElementsByTagName('text')
        $texts.Item(0).AppendChild($xml.CreateTextNode($title)) | Out-Null
        $texts.Item(1).AppendChild($xml.CreateTextNode($body)) | Out-Null
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
    } catch {
        Write-Log "通知に失敗: $_"
    }
}

Start-Sleep -Seconds $settleSeconds

$started = @()
$failed = @()
foreach ($app in $apps) {
    $path = $app.Path
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $name = if ($app.Process) { $app.Process } else { [IO.Path]::GetFileNameWithoutExtension($path) }
    if (Get-Process -Name $name -ErrorAction SilentlyContinue) {
        Write-Log "起動済みのため飛ばす: $name"
        continue
    }
    try {
        Start-Process -FilePath $path -WorkingDirectory (Split-Path $path)
        $started += $name
        Write-Log "起動: $path"
        Start-Sleep -Seconds $intervalSeconds
    } catch {
        $failed += $name
        Write-Log "起動に失敗: $path $_"
    }
}

if ($failed) {
    Show-Toast 'スタートアップ' ("起動に失敗しました: " + ($failed -join ', '))
} elseif ($started) {
    Show-Toast 'スタートアップ完了' ("W:ドライブ確認後に起動しました: " + ($started -join ', '))
}
