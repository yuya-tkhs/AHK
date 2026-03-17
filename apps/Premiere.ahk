#HotIf WinActive( pr_exe )

; Ctrl+Spaceでエフェクトの検索
^Space:: Send("{vk1D}+7+f{Backspace}{vk1C}")

; 位置、スケール、回転を入力状態にする
+^!p:: Send("+1+5{Tab 4}")
+^!s:: Send("+1+5{Tab 7}")
+^!r:: Send("+1+5{Tab 10}")

; 編集点を全てのトラックに追加
; (1) 最も近い編集点をリップルアウト選択して、指定した値プラストリミング
; (2) 最も近い編集点をリップルイン選択して、指定した値マイナストリミング
+^!e:: Send("+^k")
+^!q:: Send("+^!q+^{Right}")
+^!w:: Send("+^!w+^{Left}")
; (1)(2) にターゲットの切り替えを追加したもの
; +^!q:: Send("^!0!0+^!q+^!q+^{Right}^!0!0^!2")
; +^!w:: Send("^!0!0+^!w+^!w+^{Left}^!0!0^!2")

; トラック名の変更（トラックヘッダーの位置で実行）
; トラックを追加（トラックヘッダーの位置で実行）
; 複数のトラックを削除
+^!2:: Send("{Click Right}{Down}{Enter}")
+^!a:: Send("{Click Right}{Down 2}{Enter}+^!2")
+^!d:: {
    MenuSelect pr_exe,, "シーケンス(S)", "トラックの削除(K)..."
    Sleep 250
    Send "{Tab 2}{Space}{Tab 2}{Space}{Enter}"
}

; 再生ヘッドで自動選択の切り替え
+^!h:: MenuSelect pr_exe,, "シーケンス(S)", "再生ヘッド位置を自動選択(P)"

; グラフィックステキストを編集
+^!Enter:: Send("^![^!{Enter}")

; ターゲットの移動
vk1D & [:: {
    if GetKeyState("Ctrl", "P") ; オーディオターゲット
        Send("!{PgDn}")
    else ; ビデオターゲット
        Send("^!{PgDn}")
}
vk1D & ]:: {
    if GetKeyState("Ctrl", "P")
        Send("!{PgUp}")
    else
        Send("^!{PgUp}")
}

; 拡大・縮小
; vk1D & -:: Send("{- 3}")
; vk1D & ::: Send("{: 3}")

; キャプションセグメントの分割
vk1D & s:: {
    if GetKeyState("Shift", "P")
        Send("+{Down}+{End}^x")
        Sleep 500
        Send("{Esc}")
        Sleep 250
        Send("!/")
        Sleep 500
        Send("{Down}")
        Sleep 250
        Send("{Enter}")
        Sleep 500
        Send("^v")
        Sleep 500
        Send("{Esc}")
}
#HotIf
