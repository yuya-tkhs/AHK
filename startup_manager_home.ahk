#Requires AutoHotkey v2.0
#SingleInstance Force

; ========================================================
; 設定エリア
; ========================================================
; 監視するドライブ
TargetDrive := "W:\"

; ★起動したいアプリのリスト（配列）
TargetApps := [
    "C:\Program Files\Eagle\Eagle.exe",
    "C:\Users\yuyat\AppData\Local\Team Hasebe\TVClock\TVClock.exe",
    "W:\マイドライブ\Programming\carnac\Setup.exe"
]

; アプリごとの起動間隔（ミリ秒）
AppInterval := 1000

; ドライブ監視の最大待機時間（秒）
MaxWaitSeconds := 120

; ========================================================
; 処理開始
; ========================================================

; --- 1. ドライブ監視ループ ---
Loop MaxWaitSeconds
{
    if DirExist(TargetDrive)
    {
        ; ドライブ認識直後は不安定な場合があるため、念のため3秒待つ
        Sleep 3000

        ; 起動成功したアプリ名を記録する変数
        StartedList := ""

        ; --- 2. アプリ起動ループ ---
        for appPath in TargetApps
        {
            if FileExist(appPath)
            {
                Run appPath

                ; パスからファイル名（例: Eagle.exe）だけを取り出して記録
                SplitPath appPath, &ExeName
                StartedList .= ExeName . "`n"

                ; 次のアプリ起動まで少し待つ（負荷分散）
                Sleep AppInterval
            }
            ; ファイルが見つからない場合はスキップ（必要ならここにMsgBoxを追加）
        }

        ; --- 3. 完了通知 ---
        if (StartedList != "")
        {
            TrayTip "Wドライブ確認後、以下を起動しました：`n`n" . StartedList, "スタートアップ完了", "Iconi"
            SetTimer HideNotification, -5000 ; 5秒後に消す
        }
        else
        {
            TrayTip "Wドライブは確認できましたが、アプリが見つかりませんでした。", "エラー", "Icon!"
        }

        ExitApp
    }

    ; まだ見つからない場合は1秒待って再チェック
    Sleep 1000
}

; --- タイムアウトした場合 ---
MsgBox "指定時間内に " . TargetDrive . " が見つかりませんでした。`nアプリの自動起動を中止します。", "タイムアウト", "Icon!"
ExitApp

; --- 通知を消す関数 ---
HideNotification()
{
    TrayTip
}