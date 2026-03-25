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
; 修飾キーと組み合わせると元のキーとして動く（単押しは2、Alt+CはAlt+C）
q:: Send("{NumpadDiv}")
w:: Send("{Numpad7}")
e:: Send("{Numpad8}")
r:: Send("{Numpad9}")
t:: Send("{NumpadSub}")

a:: Send("{NumpadMult}")
s:: Send("{Numpad4}")
d:: Send("{Numpad5}")
f:: Send("{Numpad6}")
g:: Send("{NumpadAdd}")

z:: Send("{Numpad0}")
x:: Send("{Numpad1}")
c:: Send("{Numpad2}")
v:: Send("{Numpad3}")
b:: Send("{NumpadDot}")

[:: Send("{NumLock}")

; 修飾キーと組み合わせてもNumpadEnterとして動く
Space:: NumpadEnter
#HotIf
