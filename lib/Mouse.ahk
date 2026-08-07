;;
;; 中央クリックでスクロール（ドラッグ式・スムーズスクロール）
;; 参考： https://yuruaki.blog.fc2.com/blog-entry-52.html
;;
;;   マウスを動かした向きへ中身がついてくる（手のひらツールと同じ操作感）
;;   移動量をローパスフィルタでならし、固定周期で小数ノッチのホイールイベントを送る
;;
;; 滑らかさの上限は送信先アプリ依存。Chrome / Edge / Electron / Firefox など
;; 高精度ホイールに対応したアプリではピクセル単位で滑らかに動く。
;; 旧来の Win32 アプリ（エクスプローラーのリスト等）はアプリ側が 120 単位に溜めてから
;; 動かすため段差は残るが、送信が等間隔・細粒度になるぶん従来より均一になる。
;;
;; 速度の調整は SmoothScroll() 冒頭の static 定数で行う。
;;;;
#HotIf !GetKeyState("vk1D", "P") && !WinActive( exe_ai ) && !WinActive( exe_ps ) && !WinActive( exe_au ) && !WinActive( exe_ae ) && !WinActive( exe_bl ) && !WinActive( exe_pureref )
*MButton:: SmoothScroll()
#HotIf

SmoothScroll() {
    ; --- 調整用パラメータ -------------------------------------------
    static TICK             := 10   ; ループ周期(ms)。出力間隔を一定に保つ
    static PIXELS_PER_NOTCH := 20.0 ; 1ノッチ(≒3行)ぶん動かすのに必要なマウス移動量(px)。小さいほど敏感
    static SMOOTH           := 0.25 ; 追従のなめらかさ 0<..<=1。小さいほど遅れてぬるっと追従する
    static MAX_NOTCH        := 4.0  ; 1ティックあたりの上限ノッチ数（カーソル飛びによる暴走止め）
    static AXIS_HYST        := 3    ; 縦横の切り替わりにくさ。このティック数ぶん優勢が続くと反対の軸へ移る
    ; -----------------------------------------------------------------

    ; 中クリック本来の動作（新しいタブで開く・OS標準のオートスクロール）を抑止する
    Send "+^{MButton UP}"
    CoordMode "Mouse", "Screen"

    MouseGetPos &px, &py
    velx := 0.0, vely := 0.0 ; ならしたあとの速度(px/tick)
    accx := 0.0, accy := 0.0 ; 未送信のデルタ(120 = 1ノッチ)。端数を持ち越して取りこぼさない
    hvprm := 0               ; 縦横どちらを優先するかのヒステリシス（0以上=縦）

    while ( GetKeyState( "MButton", "P" ) ) {
        MouseGetPos &cx, &cy
        dx := cx - px, dy := cy - py
        px := cx, py := cy

        ; 生の移動量をそのまま使わず、目標値へ少しずつ寄せる（＝ローパスフィルタ）。
        ; 手のブレやカーソル座標の飛び飛びの更新がならされ、手を止めた瞬間も指数的に減速する。
        velx += ( dx - velx ) * SMOOTH
        vely += ( dy - vely ) * SMOOTH

        ; そのティックで優勢だった軸へカウンタを寄せ、符号が変わるまで軸を維持する。
        ; 縦に流している最中の横ブレで横スクロールに化けるのを防ぐため。
        hvprm += ( Abs( vely ) >= Abs( velx ) ) ? 1 : -1
        hvprm := Max( -AXIS_HYST, Min( AXIS_HYST, hvprm ) )

        if ( hvprm >= 0 ) {
            ; マウスを下へ動かすと中身が下へついてくる ＝ WheelUp ＝ 正のデルタ
            SendWheelDelta( 0x0800, vely, &accy, PIXELS_PER_NOTCH, MAX_NOTCH )
        } else {
            ; マウスを右へ動かすと中身が右へついてくる ＝ WheelLeft ＝ 負のデルタ
            SendWheelDelta( 0x1000, -velx, &accx, PIXELS_PER_NOTCH, MAX_NOTCH )
        }

        Sleep TICK
    }
}

; ホイールイベントを生のデルタ値で送る（1ノッチ = 120単位）。
; flag は 0x0800 = 垂直ホイール / 0x1000 = 水平ホイール。
; Send "{WheelDown n}" は整数ノッチしか送れないが、こちらは 0.15 のような小数を送れる。
; 1未満に丸められて消えないよう、端数は acc に残して次のティックへ持ち越す。
SendWheelDelta( flag, pixels, &acc, pixels_per_notch, max_notch ) {
    notches := pixels / pixels_per_notch
    notches := Max( -max_notch, Min( max_notch, notches ) )
    acc += notches * 120
    delta := Round( acc )
    if ( delta = 0 )
        return
    acc -= delta
    DllCall( "mouse_event", "UInt", flag, "Int", 0, "Int", 0, "Int", delta, "UPtr", 0 )
}
