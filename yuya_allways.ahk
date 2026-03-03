#Requires AutoHotkey v2.0
#SingleInstance Force

; 参考 https://qiita.com/ryoheiszk/items/092cc5d76838cb5a13f1
; Kensingtonの管理ソフトを使って、+^!でカーソルの移動速度を遅くできる

global pr_exe := "ahk_exe Adobe Premiere Pro.exe"
global ai_exe := "ahk_exe Illustrator.exe"
global ps_exe := "ahk_exe Photoshop.exe"
global au_exe := "ahk_exe Adobe Audition.exe"
global ae_exe := "ahk_exe AfterFX.exe"
global bl_exe := "ahk_exe blender.exe"
global pureref_exe := "ahk_exe PureRef.exe"

A_MaxHotkeysPerInterval := 200
SendMode "Input"
SetWorkingDir(A_ScriptDir)





;;
;; 「ddd」と入力されたら今日の日付 (MMDD形式) を挿入
;;;;
:*C:ddd:: {
    ; 今日の日付を取得、2桁にフォーマット、MMDDを作成
    thisMonth := Format("{:02}", A_MM)
    thisDay := Format("{:02}", A_DD)
    currentDate := thisMonth . thisDay
    ; 現在のカーソル位置に日付を貼り付け
    Send(currentDate)
    return
}





;;
;; 無変換関連
;;;;

#HotIf GetKeyState("vk1D", "P")
LButton:: Click 2
vk1C::    Send("{vk1C}")
*Up::     Send("{Blind}{Up 5}")
*Down::   Send("{Blind}{Down 5}")
*Right::  Send("{Blind}{Right 5}")
*Left::   Send("{Blind}{Left 5}")
Enter:: {
    if GetKeyState("Ctrl", "P")
        Send("{Up}{End}{Enter}")
    else
        Send("{End}{Enter}")
}
;;実行しているスクリプトのReload
+^!r:: Reload
#HotIf





;;
;; 大西配列モード
;;;;

global toggle := false
imgGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
imgGui.MarginX := 0
imgGui.MarginY := 0
imgGui.Add("Picture", "w640 h-1", "カンペ.png")

; 無変換 + Spaceでリマッピングの有効/無効を切り替え
#HotIf GetKeyState("vk1D", "P")
Space:: {
    global toggle
    toggle := !toggle
    imgWidth := 640
    imgHeight := 221
    if (toggle == true) {
        Send("{vk1C}")
        xPos := A_ScreenWidth - imgWidth *1.5 - 50
        yPos := A_ScreenHeight - imgHeight *1.5 - 50
        imgGui.Show("NoActivate x" xPos " y" yPos)
    } else {
        Send("{vk1D}")
        imgGui.Hide()
    }
}
#HotIf

#HotIf toggle && GetKeyState("vk1D", "P")
i::Up
j::Left
k::Down
l::Right
#HotIf

#HotIf toggle
w::l
e::u
r::,
t::.
y::f
u::w
i::r
o::y

a::e
s::i
d::a
f::o
g::-
h::k
j::t
k::n
l::s
Up::h

b::sc027
n::g
m::d
-::m
Left::j
Down::b
#HotIf





;;
;; Adobe全般で共通の設定
;;;;
#HotIf WinActive( ai_exe ) || WinActive( ps_exe ) || WinActive( au_exe ) || WinActive( ae_exe ) || WinActive( pr_exe )
^Enter:: Send("^{Enter}{vk1D}")
#HotIf



;;
;; Illustrator
;;;;
; 10秒ごとにチェックを開始（ミリ秒指定）
SetTimer(CheckIllustrator, 10000)
CheckIllustrator() {
    ; Illustratorが実行中か確認（プロセス名で判定）
    if ProcessExist("Illustrator.exe") {
        if !ProcessExist("sppy_1_5.exe") {
            Run("W:\共有ドライブ\wc動画\sync\Assets\Illustrator\Sppy_1_5\Sppy_1_5.exe")
        }
    }
}



;;
;; Premiere Pro
;;;;
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
#HotIf

;; 無変換
#HotIf WinActive( pr_exe ) && GetKeyState( "vk1D", "P" )

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
::: Send("{: 3}")

; キャプションセグメントの分割
+s:: {
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





;;
;; 中央クリックでスクロール
;; 参考： https://yuruaki.blog.fc2.com/blog-entry-52.html
;;;;

#HotIf !GetKeyState("vk1D", "P") && !WinActive( ai_exe ) && !WinActive( ps_exe ) && !WinActive( au_exe ) && !WinActive( ae_exe ) && !WinActive( bl_exe ) && !WinActive( pureref_exe )
*MButton:: {
    ; 初期化
    Send "+^{MButton UP}"
    CoordMode "Mouse", "Screen"
    st := A_TickCount
    MouseGetPos &smx, &smy
    omx := smx
    omy := smy
    spdx := 0
    spdy := 0
    hvprm := 0
    ; スクロール処理のメインループ
    while ( GetKeyState( "MButton", "P" ) ) {
        MouseGetPos &nmx, &nmy
        if ( Abs( smy - nmy ) >= Abs( smx - nmx ) || hvprm >= 0 ) {
            ScrollAccXY( omx, omy, nmy, smy, "WheelUp", "WheelDown", &spdy )
        } else {
            ScrollAccXY( omx, omy, nmx, smx, "WheelLeft", "WheelRight", &spdx )
        }
        hvprm -= ( smx - nmx != 0 && smy - nmy == 0 && hvprm > -5 ) ? 1 : 0
        hvprm += ( smy - nmy != 0 && smx - nmx == 0 && hvprm < 5 ) ? 1 : 0
        smx := nmx
        smy := nmy
        Sleep 0
    }
}
#HotIf
ScrollAccXY( ox, oy, n, s, k1, k2, &spd ) {
    d := n - s
    c := 0
    sensitivity := 25 ; 10 小さいほど敏感
    max_speed := 15 ; 20
    flick_threshold := 20 ; 30 微少移動の蓄積閾値
    if ( Abs( d ) <= sensitivity ) {
        spd += d
        if ( Abs( spd ) >= flick_threshold ) {
            c := 1
            spd := 0
        } else {
            d := 0
        }
    } else {
        c := Abs( d ) / sensitivity
        c := ( c > max_speed ) ? max_speed : c
    }
    if ( c > 0 ) { ; 回数が0より大きい場合のみ送信
        key_to_send := ( d > 0 ) ? "{Blind}{" k1 " " . Floor( c ) . "}" : "{Blind}{" k2 " " . Floor( c ) . "}"
        Send key_to_send
    }
}





