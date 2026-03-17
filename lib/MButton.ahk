;;
;; 中央クリックでスクロール
;; 参考： https://yuruaki.blog.fc2.com/blog-entry-52.html
;;;;

#HotIf GetKeyState("MButton", "P")
a:: Send("^a")
s:: {
    Send("^s")
    my_tooltip_function("上書き保存", 600)
}
x:: Send("^x")
c:: Send("^c")
v:: Send("^v")
#HotIf

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