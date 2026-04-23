; DPI非依存の相対マウス移動（モニター跨ぎ対応）
_RawMouseMove(dx, dy) {
    static cbSize := 40  ; 64bit: sizeof(INPUT)
    INPUT := Buffer(cbSize, 0)
    NumPut("UInt", 0,    INPUT,  0)   ; type = INPUT_MOUSE
    NumPut("Int",  dx,   INPUT,  8)   ; MOUSEINPUT.dx
    NumPut("Int",  dy,   INPUT, 12)   ; MOUSEINPUT.dy
    NumPut("UInt", 0x01, INPUT, 20)   ; dwFlags = MOUSEEVENTF_MOVE
    DllCall("SendInput", "UInt", 1, "Ptr", INPUT, "Int", cbSize)
}

global mouseMode := false
global _mm_left := false, _mm_right := false, _mm_up := false, _mm_down := false
global _mm_steps := 0

_MouseMoveStep() {
    global _mm_left, _mm_right, _mm_up, _mm_down, _mm_steps
    dx := (_mm_right ? 1 : 0) - (_mm_left ? 1 : 0)
    dy := (_mm_down  ? 1 : 0) - (_mm_up   ? 1 : 0)
    if (dx = 0 && dy = 0) {
        _mm_steps := 0
        return
    }
    _mm_steps += 1
    if GetKeyState("Space", "P")
        speed := 2
    else
        speed := Min(10 + _mm_steps * 1.6, 60)
    factor := (dx != 0 && dy != 0) ? 0.707 : 1  ; 斜め移動の速度を正規化
    _RawMouseMove(Round(dx * speed * factor), Round(dy * speed * factor))
}

_SetMM(key, val) {
    global _mm_left, _mm_right, _mm_up, _mm_down, _mm_steps
    switch key {
        case "left":
            if (val && !_mm_left)   ; キーリピートでは既にtrueなのでリセットしない
                _mm_steps := 0
            _mm_left  := val
        case "right":
            if (val && !_mm_right)
                _mm_steps := 0
            _mm_right := val
        case "up":
            if (val && !_mm_up)
                _mm_steps := 0
            _mm_up    := val
        case "down":
            if (val && !_mm_down)
                _mm_steps := 0
            _mm_down  := val
    }
}

EnterMouseMode() {
    global mouseMode
    mouseMode := true
    MyTooltip("
    (
    マウスモード
    - - - - - - - - - - - - - -
    w e r: Click 2 3 1
    s f: Wheel ↓ ↑
    x c d v: ← ↓ ↑ →
    Space: Slow
    - - - - - - - - - - - - - -
    Esc / F22: 終了
    )", 99999)
    SetTimer(_MouseMoveStep, 16)
}

ExitMouseMode() {
    global mouseMode, _mm_left, _mm_right, _mm_up, _mm_down, _mm_steps
    mouseMode := false
    _mm_left  := false
    _mm_right := false
    _mm_up    := false
    _mm_down  := false
    _mm_steps := 0
    SetTimer(_MouseMoveStep, 0)
    MyTooltip()
}

F22:: EnterMouseMode()

#HotIf mouseMode

x::    _SetMM("left",  true)
x up:: _SetMM("left",  false)
c::    _SetMM("down",  true)
c up:: _SetMM("down",  false)
d::    _SetMM("up",    true)
d up:: _SetMM("up",    false)
v::    _SetMM("right", true)
v up:: _SetMM("right", false)

Space:: return  ; キー入力を抑制しつつGetKeyStateで低速モード判定に使う

s:: Send("{WheelDown}")
f:: Send("{WheelUp}")

w:: Click("Left")
e:: Click("Middle")
r:: Click("Right")

Esc:: ExitMouseMode()
F22:: ExitMouseMode()

#HotIf
