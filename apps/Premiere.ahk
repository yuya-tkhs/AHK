#HotIf WinActive( exe_pr )

; グラフィックステキストを編集
+^!vk1C:: Send("{vk1C}^![^!{Enter}")

; 2ストローク
^Space:: {
    MyTooltip("
    (
    2ストローク待機中（5秒）
    - - - - - - - - - - - - - - - -
    p, s, r: 入力状態
    f: エフェクトの検索
    d: 空のトラックを削除
    h: 再生ヘッド位置を自動選択
    - - - ヘッダーにマウスオン - - - 
    a: トラックの追加
    e: トラック名の変更
    )", 5000)
    ih := InputHook("L1 T5") ; 次の1文字を待機 (L1: 1文字入力で終了, T2: 2秒でタイムアウト)
    ih.KeyOpt("{Escape}{Space}", "E")
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
        case "Escape": return
        case "Space":  Send("{vk1D}+7+f{Backspace}{vk1C}")
        case "p":      Send("+1+5{Tab 4}") 
        case "s":      Send("+1+5{Tab 7}")  
        case "r":      Send("+1+5{Tab 10}")
        case "d": 
            MenuSelect(exe_pr,, "シーケンス(S)", "トラックの削除(K)...")
            Sleep(250)
            Send("{Tab 2}{Space}{Tab 2}{Space}{Enter}")
        case "h":      MenuSelect(exe_pr,, "シーケンス(S)", "再生ヘッド位置を自動選択(P)")
        case "e":      Send("{Click Right}{Down}{Enter}")
        case "a":      Send("{Click Right}{Down 2}{Enter}")
        default:       MyTooltip("無効なキーです", 500)
    }
}

; 編集点を全てのトラックに追加
; (1) 最も近い編集点をリップルアウト選択して、指定した値プラストリミング
; (2) 最も近い編集点をリップルイン選択して、指定した値マイナストリミング
; (1)(2) にターゲットの切り替えを追加したもの
; +^!q:: Send("^!0!0qq+^{Right}^!0!0^!2")
; +^!w:: Send("^!0!0ww+^{Left}^!0!0^!2")
#HotIf WinActive( exe_pr )
+^!e:: Send("+^k")
+^!q:: Send("+^!q+^{Right}")
+^!w:: Send("+^!w+^{Left}")

#HotIf WinActive( exe_pr ) && GetKeyState("LButton", "P")
; 編集点の追加やクリップ名の変更
e::  Send("^k")
+e:: Send("+^k")
2::  Send("+{F2}")
; ターゲットの移動
[:: {
    if GetKeyState("Ctrl", "P") ; オーディオターゲット
        Send("!{PgDn}")
    else ; ビデオターゲット
        Send("^!{PgDn}")
}
]:: {
    if GetKeyState("Ctrl", "P")
        Send("!{PgUp}")
    else
        Send("^!{PgUp}")
}
; 拡大・縮小
-:: Send("{- 3}")
vkBA:: Send("{: 3}")

#HotIf
