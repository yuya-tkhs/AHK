vk1D & Space:: {
    ToolTip("【2ストローク待機中】`nC: コピー`nV: ペースト`n(2秒以内に押してください)")
    
    ih := InputHook("L1 T2") ; 次の1文字を待機 (L1: 1文字入力で終了, T2: 2秒でタイムアウト)
    ih.KeyOpt("{Space}{Escape}{vk1D}{Numpad5}{NumpadEnter}", "E")
    ih.Start()
    ih.Wait()
    ToolTip() ; ツールチップを消す
    
    if (ih.EndReason = "Timeout") {
        return 
    }

    capturedKey := (ih.EndReason = "EndKey") ? ih.EndKey : ih.Input
    switch capturedKey {
        case "Space":      toggleOnishiMode()  ; 大西配列モードに入る
        case "Escape":     return              ; Escが押されたら安全にキャンセル
        case "Up":         Send("#{Up}")
        case "Down":       Send("#{Down}")
        case "Right":      Send("#{Right}")
        case "Left":       Send("#{Left}")

        case "Numpad5":    SetTenkeyMode(false)
        case "NumpadEnter":toggleOnishiAndTenkey()

        case "1":          Send("^!{F1}")
        case "2":          Send("^!{F2}")

        case "e":          Send("#e")
        case "r":          Reload               ; 実行しているスクリプトのReload

        case "a":          
            if (onishi) { 
                toggleOnishiAndTenkey() 
            }
        case "s":          Send("#+s")
        case "d":          SetTenkeyMode(true)
        case "f":          Send("{LWin}")

        case "v":          Send("#v")
        case "x":          Send("#x")
        case "c":          Send("#+c")

        default:           my_tooltip_function("無効なキーです", 500)
    }
}

vk1D::Send("{vk1D}")
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

*~Esc:: {
    ; よくスタックする修飾キーの「離す(up)」信号をOSに連打して強制解除
    Send("{LControl up}{RControl up}{LAlt up}{RAlt up}{LShift up}{RShift up}{LWin up}{RWin up}")
    Send("{vk1D up}")
    SetOnishiMode(false)
    SetTenkeyMode(false)
    my_tooltip_function("🔄 キー状態をリセットしました", 500)
}

OnClipboardChange(OnClipChanged)
OnClipChanged(DataType) { ; DataTypeには 0(空), 1(テキスト), 2(画像などのファイル) が入る
    my_tooltip_function("コピー", 600)
}

~^s:: {
    my_tooltip_function("上書き保存", 600)
}