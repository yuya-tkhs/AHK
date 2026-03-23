#HotIf WinActive( pr_exe )

; Ctrl+Spaceでエフェクトの検索
^Space:: Send("{vk1D}+7+f{Backspace}{vk1C}")

; グラフィックステキストを編集
+^!vk1C:: Send("{vk1C}^![^!{Enter}")


#HotIf WinActive( pr_exe ) && GetKeyState("LButton", "P")
; 位置、スケール、回転を入力状態にする
p:: Send("+1+5{Tab 4}") 
s:: Send("+1+5{Tab 7}")
r:: Send("+1+5{Tab 10}")

; 編集点を全てのトラックに追加
; (1) 最も近い編集点をリップルアウト選択して、指定した値プラストリミング
; (2) 最も近い編集点をリップルイン選択して、指定した値マイナストリミング
#HotIf WinActive( pr_exe )
+^!e:: Send("+^k")
+^!q:: Send("+^!q+^{Right}")
+^!w:: Send("+^!w+^{Left}")
; (1)(2) にターゲットの切り替えを追加したもの
; +^!q:: Send("^!0!0qq+^{Right}^!0!0^!2")
; +^!w:: Send("^!0!0ww+^{Left}^!0!0^!2")
#HotIf WinActive( pr_exe ) && GetKeyState("LButton", "P")
e::  Send("^k")
+e:: Send("+^k")
2::  Send("+{F2}")

; トラック名の変更（トラックヘッダーの位置で実行）
; トラックを追加（トラックヘッダーの位置で実行）
; 複数のトラックを削除
#HotIf WinActive( pr_exe )
+^!2:: Send("{Click Right}{Down}{Enter}")
+^!a:: Send("{Click Right}{Down 2}{Enter}2")
+^!d:: {
    MenuSelect pr_exe,, "シーケンス(S)", "トラックの削除(K)..."
    Sleep 250
    Send "{Tab 2}{Space}{Tab 2}{Space}{Enter}"
}

#HotIf WinActive( pr_exe )
; 再生ヘッドで自動選択の切り替え
+^!h:: MenuSelect pr_exe,, "シーケンス(S)", "再生ヘッド位置を自動選択(P)"

; ターゲットの移動
#HotIf WinActive( pr_exe ) && GetKeyState("LButton", "P")
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
#HotIf WinActive( pr_exe ) && GetKeyState("LButton", "P")
-:: Send("{- 3}")
vkBA:: Send("{: 3}")

#HotIf
