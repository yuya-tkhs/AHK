F23:: {
    if (onishi) {
        toggleOnishiAndTenkey()
    } else {
        toggleTenkeyMode()
    }
}

F24:: {
    if (tenkey) {
        toggleOnishiAndTenkey()
    } else {
        toggleOnishiMode()
    }
}

vk1D & Space:: {
    MyTooltip("
    (
    2ストローク待機中（5秒）
    - - - - - - - - - - - - - - - -
    Space: Enter
    - - - - - - - - - - - - - - - -
    矢印: Window操作
    - - - - - - - - - - - - - - - -
    e: Explorer
    s: Screen Short
    f: 検索
    c: Color Picker
    v: Clipboard
    x: Windows Menu
    r: Reload
    )", 5000)
    ih := InputHook("L1 T2") ; 次の1文字を待機 (L1: 1文字入力で終了, T2: 2秒でタイムアウト)
    ih.KeyOpt("{Space}{Escape}{vk1D}{Numpad5}{NumpadEnter}{Up}{Down}{Right}{Left}", "E")
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
        case "Space":      Send("{Enter}")
        case "Up":         Send("#{Up}")
        case "Down":       Send("#{Down}")
        case "Right":      Send("#{Right}")
        case "Left":       Send("#{Left}")
        case "e":          Send("#e")
        case "r":          Reload              ; 実行しているスクリプトのReload
        case "s":          Send("#+s")
        case "f":          Send("{LWin}")
        case "v":          Send("#v")
        case "x":          Send("#x")
        case "c":          Send("#+c")
        default:           MyTooltip("無効なキーです", 500)
    }
}

vk1D:: {
    Send("{vk1D}")
    SetOnishiMode(false)
}
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

vk1D & BS:: Send("{Home}+{End}+{Right}{BS}") ;;行削除
+^BS::      Send("+{Home}{BS}") ;;前方削除
+^Del::     Send("+{End}{BS}")  ;;後方削除

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

; * 他の修飾キー（Ctrl・Shift・Alt等）が押されていても発火する
; ~ AHKが処理した後、元のキーイベントをOSにも渡す（Escが通常通り機能する）
*~Esc:: {
    if ( WinActive( exe_pr ) || WinActive( exe_ps ) || WinActive( exe_ai ) ) {
        SetOnishiMode( false )
        SetTenkeyMode( false )
    }
}

OnClipboardChange(OnClipChanged)
OnClipChanged(DataType) { ; DataTypeには 0(空), 1(テキスト), 2(画像などのファイル) が入る
    MyTooltip("コピー", 1500)
}

^Enter:: {
    Send("^{Enter}")
    KeyWait("Ctrl")  ; Ctrlが離されてからモード処理・IME操作を実行（スタック防止）
    if (onishi)
        SetOnishiMode(false)
    else if ( WinActive( exe_pr ) || WinActive( exe_ps ) || WinActive( exe_ai ) )
        Send("{vk1D}")
}

~^s:: {
    MyTooltip("上書き保存", 1500)
}