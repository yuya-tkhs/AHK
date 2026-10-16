# ログイン後、W:ドライブの準備を待ってからアプリを起動する本体。
# タスクスケジューラ（register_task.ps1 で登録）から呼ばれる。タスク側でこのファイルが見えるまで待ってから、
# UTF-8 として読み込んで実行する（Windows PowerShell 5.1 は BOM無しUTF-8 を Shift-JIS として読むため）。
# そのため $PSScriptRoot は空になる。パスはすべて絶対パスで書く。

# AutoHotkey本体。関連付け（AutoHotkeyUX のランチャー）を経由せず直接起動する
$ahkDir = (Get-ItemProperty 'HKLM:\SOFTWARE\AutoHotkey' -ErrorAction SilentlyContinue).InstallDir
if (-not $ahkDir) { $ahkDir = 'C:\Program Files\AutoHotkey' }

# 起動するアプリ。上から順に起動し、無いものは飛ばす（TVClock は自宅PCにしか無い）
# Path    … 実行ファイル。配列なら最初に見つかったものを使う（PCによってインストール先が違うもの）
# Args    … 起動時の引数
# Process … 起動済みか調べるプロセス名。exe名と違うときだけ書く
# Match   … 起動済みかをコマンドラインで調べるときの文字列。同じexeで別物が動くもの（AHK）に使う
# Check   … 起動済みかを自前で調べる処理（結果が空なら未起動）。プロセスの有無では分からないものに使う
$apps = @(
    # ホットキーは体感に直結するので最初に起動する
    @{ Path = Join-Path $ahkDir 'v2\AutoHotkey64.exe'
       Args = '"W:\マイドライブ\Programming\AHK\yuya_allways.ahk"'
       Match = 'yuya_allways.ahk' }
    @{ Path = 'C:\Program Files\Eagle\Eagle.exe' }
    @{ Path = "$env:LOCALAPPDATA\Team Hasebe\TVClock\TVClock.exe" }
    @{ Path = 'W:\マイドライブ\Programming\carnac\Setup.exe'; Process = 'Carnac' }
    # Chrome は窓を閉じても裏でプロセスが残ることがあるので、窓があるかで見る
    @{ Path = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
       Check = { Get-Process chrome -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0 } }
    # GPU合成を切って起動する（デスクトップ・スタートメニューのショートカットと同じ引数）
    @{ Path = "$env:LOCALAPPDATA\Programs\orca\Orca.exe"; Args = '--disable-gpu-compositing' }
    @{ Path = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe", 'C:\Program Files\Microsoft VS Code\Code.exe') }
    # Notion は自前の自動起動（HKCU\...\Run）もある。先に起動していれば飛ばされる
    @{ Path = "$env:LOCALAPPDATA\Programs\Notion\Notion.exe" }
    # explorer.exe はシェルとして常に動いているので、エクスプローラーの窓があるかで見る
    @{ Path = "$env:WINDIR\explorer.exe"; Process = 'エクスプローラー'
       Check = { @((New-Object -ComObject Shell.Application).Windows()) | Where-Object { $_.FullName -like '*\explorer.exe' } } }
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

# アプリはコンソールを持たない親（WMI の WmiPrvSE.exe）から起動する。
# Electron 製のアプリ（Eagle・VSCode・Notion・Orca）は起動時に親プロセスのコンソールへ自分からつなぐ（AttachConsole）。
# Start-Process で起動すると、タスクの見えないコンソール（conhost --headless）につながったままになり、ps が終わっても
# conhost が残ってタスクが「実行中」のままになり、その間はタスクを手動で実行しても無視される（MultipleInstances IgnoreNew）。
# 15分の上限で conhost が落とされても、つながっていたプロセス（VSCode の拡張など）は生き残った（実測）。
# DETACHED_PROCESS でも親のコンソールにはつなげてしまうので効かない（実測）。WMI から起動したプロセスの環境変数はユーザーの通常のもの（PATH 含む）で、優先度も Normal
function Start-Detached([string]$path, [string]$arguments) {
    $cmd = '"' + $path + '"' + $(if ($arguments) { ' ' + $arguments })
    $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create `
        -Arguments @{ CommandLine = $cmd; CurrentDirectory = (Split-Path $path) }
    if ($r.ReturnValue -ne 0) { throw "Win32_Process.Create の戻り値 $($r.ReturnValue)" }
}

Start-Sleep -Seconds $settleSeconds

$started = @()
$failed = @()
foreach ($app in $apps) {
    $path = @($app.Path) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $path) { continue }
    $name = if ($app.Process) { $app.Process } else { [IO.Path]::GetFileNameWithoutExtension($path) }
    $running = if ($app.Check) {
        & $app.Check
    } elseif ($app.Match) {
        $exe = [IO.Path]::GetFileName($path)
        Get-CimInstance Win32_Process -Filter "Name = '$exe'" | Where-Object { $_.CommandLine -like "*$($app.Match)*" }
    } else {
        Get-Process -Name $name -ErrorAction SilentlyContinue
    }
    if ($app.Match) { $name = $app.Match }
    if ($running) {
        Write-Log "起動済みのため飛ばす: $name"
        continue
    }
    try {
        Start-Detached $path $app.Args
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
