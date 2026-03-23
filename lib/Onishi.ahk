;;
;; 大西配列モード
;;;;
global onishi := false
onishiGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
onishiGui.MarginX := 0
onishiGui.MarginY := 0
onishiTargetWidth := Integer(A_ScreenWidth * 0.25)
onishiGui.Add("Picture", "w" . onishiTargetWidth . " h-1", "Onishi.png")
onishiGui.Show("Hide")

toggleOnishiMode() {
    global onishi
    SetOnishiMode(!onishi) ; 現在のトグル状態の「逆」をセットする
}
SetOnishiMode(state) {
    global onishi
    onishi := state
    if (onishi == true) {
        Send("{vk1C}")
        onishiGui.GetPos(,, &guiW, &guiH)
        xPos := A_ScreenWidth - guiW - 25
        yPos := A_ScreenHeight - guiH - 25
        onishiGui.Show("NoActivate x" xPos " y" yPos)
    } else {
        Send("{vk1D}")
        onishiGui.Hide()
    }
}

#HotIf onishi
vk1D & i::  Send("{Blind}{Up}")
vk1D & k::  Send("{Blind}{Down}")
vk1D & j::  Send("{Blind}{Left}")
vk1D & l::  Send("{Blind}{Right}")

vk1D & o::  Send("{Blind}{Up 5}")
vk1D & -::  Send("{Blind}{Down 5}")
vk1D & h::  Send("{Blind}{Left 5}")
vk1D & Up:: Send("{Blind}{Right 5}")

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
    SetOnishiMode(false)
}