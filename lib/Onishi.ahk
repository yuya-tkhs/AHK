;;
;; 大西配列モード
;;;;
global onishi := false
imgGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
imgGui.MarginX := 0
imgGui.MarginY := 0
imgGui.Add("Picture", "w640 h-1", "カンペ.png")

; ① 現在の状態を反転（トグル）させる関数
onishiOhnishiMode() {
    global onishi
    SetOhnishiMode(!onishi) ; 現在のトグル状態の「逆」をセットする
}
; ② ON/OFFを明示的に指定して適用する関数
SetOhnishiMode(state) {
    global onishi
    onishi := state
    imgWidth := 640
    imgHeight := 221
    if (onishi == true) {
        ; --- 大西配列 ON ---
        Send("{vk1C}")
        xPos := A_ScreenWidth - (imgWidth * 1.5) - 50
        yPos := A_ScreenHeight - (imgHeight * 1.5) - 50
        imgGui.Show("NoActivate x" xPos " y" yPos)
        WinSetAlwaysOnTop(1, imgGui.Hwnd)
    } else {
        ; --- 大西配列 OFF ---
        Send("{vk1D}")
        imgGui.Hide()
    }
}

; 無変換 + Spaceでリマッピングの有効/無効を切り替え
vk1D & Space:: onishiOhnishiMode()

#HotIf onishi
vk1D & i::  Send("{Blind}{Up}")
vk1D & j::  Send("{Blind}{Down}")
vk1D & k::  Send("{Blind}{Right}")
vk1D & l::  Send("{Blind}{Left}")
vk1D & o::  Send("{Blind}{Up 5}")
vk1D & -::  Send("{Blind}{Down 5}")
vk1D & Up:: Send("{Blind}{Right 5}")
vk1D & h::  Send("{Blind}{Left 5}")

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

^Enter:: {
    Send("^{Enter}")
    ; Send("{vk1D}")
    SetOhnishiMode(false)
}