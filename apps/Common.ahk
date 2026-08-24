; メニューの文言は関数にまとめる。ショートカット一覧（ShortcutList.ahk）が
; この文字列をそのまま読んで並べるので、ここを直せば一覧も追随する。
GlobalMenuText() {
    return "
    (
    2ストローク待機中（5秒）
    - - - - - - - - - - - - - - - -
    e: Explorer
    s: Screen Short
    S: Gyazo
    f: 検索
    c: Color Picker
    v: Clipboard
    x: Windows Menu
    h: 音声入力
    a: オーディオ切り替え
    k: ショートカット一覧
    r: Reload
    )"
}

; Gyazoの範囲キャプチャを開始する。常駐中でも起動し直すとその都度キャプチャが始まる。
; 見つからないときにRunの例外ダイアログを出さないよう、ツールチップに落とす。
RunGyazo() {
    path := "C:\Program Files (x86)\Gyazo\Gyazowin.exe"
    try
        Run(path)
    catch
        MyTooltip("Gyazoが見つかりません`n" path, 2000)
}

vk1D & Space:: {
    MyTooltip(GlobalMenuText(), 5000)
    ih := InputHook("L1 T2") ; 次の1文字を待機 (L1: 1文字入力で終了, T2: 2秒でタイムアウト)
    ih.KeyOpt("{Space}{Escape}{vk1D}{Numpad5}{NumpadEnter}", "E")
    ih.Start()
    ih.Wait()
    MyTooltip()
    if (ih.EndReason = "Timeout") {
        return
    }
    capturedKey := (ih.EndReason = "EndKey") ? ih.EndKey : ih.Input
    ; 物理キーから指が離れるまで待機（Sendと物理キーの衝突を防ぐ）
    if (capturedKey != "") {
        KeyWait(StrLower(capturedKey))
    }
    switch capturedKey {
        case "Escape":     return              ; Escが押されたら安全にキャンセル
        case "e":          Send("#e")
        case "r":          Reload              ; 実行しているスクリプトのReload
        case "s":          Send("#+s")
        case "S":          RunGyazo()             ; switch は既定で大文字小文字を区別する（実測確認済み）
        case "f":          Send("{LWin}")
        case "v":          Send("#v")
        case "x":          Send("#x")
        case "c":          Send("#+c")
        case "h":          Send("#h")             ; Windows 音声入力
        case "a":          Send("#^v")            ; オーディオ出力先の切り替え
        case "k":          ShowShortcutList()     ; Escで閉じるまで出しっぱなし
        default:           MyTooltip("無効なキーです", 500)
    }
}

vk1D:: Send("{vk1D}")
vk1D & LButton:: Click 2
vk1D & vk1C::    Send("{vk1C}")
vk1D & Up::      Send("{Blind}{Up 5}")
vk1D & Down::    Send("{Blind}{Down 5}")
vk1D & Right::   Send("{Blind}{Right 5}")
vk1D & Left::    Send("{Blind}{Left 5}")
vk1D & Enter:: {
    if GetKeyState("Ctrl", "P")
        Send("{Up}{End}{Enter}")
    else
        Send("{End}{Enter}")
}

vk1D & BS::  Send("+{Home}{BS}") ;;前方削除（行頭まで）
vk1D & Del:: Send("+{End}{BS}")  ;;後方削除（行末まで）
+^BS::       Send("{Home}+{End}+{Right}{BS}") ;;行削除

; スタックした修飾キーを自動検出・解除する関数
; 「論理状態ON・物理状態OFF」= ユーザーが押していないのにOSが押下中と認識している状態をスタックとみなす
; SetTimer により1500ms間隔でバックグラウンド実行される
ResetStuckKeys() {
    modifiers := ["LControl", "RControl", "LAlt", "RAlt", "LShift", "RShift", "LWin", "RWin"]
    stuckKeys := ""
    for key in modifiers {
        if (GetKeyState(key) && !GetKeyState(key, "P")) ; 論理ON・物理OFF = スタック
            stuckKeys .= key " "
    }
    if (stuckKeys != "") {
        Send("{LControl up}{RControl up}{LAlt up}{RAlt up}{LShift up}{RShift up}{LWin up}{RWin up}")
        Send("{vk1D up}")
        MyTooltip("🔄 自動リセット: " stuckKeys, 1500)
    }
}
SetTimer(ResetStuckKeys, 1500)

OnClipboardChange(OnClipChanged)
OnClipChanged(DataType) { ; DataTypeには 0(空), 1(テキスト), 2(画像などのファイル) が入る
    static ignoreNext := false
    if (ignoreNext) {           ; 自分でセットした整形結果によるイベントは無視（無限ループ防止）
        ignoreNext := false
        return
    }
    if (DataType = 1 && IsUrl(A_Clipboard)) {
        cleaned := CleanUrl(A_Clipboard)
        if (cleaned != A_Clipboard) {
            ignoreNext := true
            A_Clipboard := cleaned
            MyTooltip("URL整形: " cleaned, 1500)
            return
        }
    }
    MyTooltip("コピー", 1500)
}

; アプリ別の追加処理はAdobeCommon.ahkのOnCtrlEnterPost()に記述
^Enter:: {
    Send("^{Enter}")
    KeyWait("Ctrl")  ; Ctrlが離されてからIME操作を実行（スタック防止）
    OnCtrlEnterPost()
}

~^s:: {
    MyTooltip("上書き保存", 1500)
}