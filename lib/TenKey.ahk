;;
;; テンキーモード
;;;;
global Tenkey := false
tenGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
tenGui.MarginX := 0
tenGui.MarginY := 0
tenTargetWidth := Integer(A_ScreenWidth * 0.125)
tenGui.Add("Picture", "w" . tenTargetWidth . " h-1", "Tenkey.png")
tenGui.Show("Hide")


toggleTenkeyMode() {
    global Tenkey
    SetTenkeyMode(!Tenkey) ; 現在のトグル状態の「逆」をセットする
}
SetTenkeyMode(state) {
    global Tenkey
    Tenkey := state
    if (Tenkey == true) {
        tenGui.GetPos(,, &guiW, &guiH)
        xPos := A_ScreenWidth - guiW - 25
        yPos := A_ScreenHeight - guiH - 25
        tenGui.Show("NoActivate x" xPos " y" yPos)
    } else {
        tenGui.Hide()
    }
}

#HotIf Tenkey
Tab::NumLock
q::NumpadDiv
w::Numpad7
e::Numpad8
r::Numpad9
t::NumpadSub

LCtrl::Tab
a::NumpadMult
s::Numpad4
d::Numpad5
f::Numpad6
g::NumpadAdd

LShift::BS
z::Numpad0
x::Numpad1
c::Numpad2
v::Numpad3
b::,

LAlt::NumpadDot
Space::NumpadEnter
#HotIf
