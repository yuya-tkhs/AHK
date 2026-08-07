;;
;; キーによる加速スクロール（ペンタブのスクロール操作を模したもの）
;;   F22 = 下 / F23 = 上
;;   単押し → MIN_NOTCH ぶんだけ送る（細かい操作用）
;;   長押し → 一定時間ごとに1回あたりのノッチ数が増え、MAX_NOTCH で頭打ちになる
;;
;; 送信先はマウスカーソル下のウィンドウ（Windowsの標準挙動）
;; 速度の調整は AccelScroll() 冒頭の static 定数で行う
;;;;

F22:: AccelScroll( "F22", "WheelDown" )
F23:: AccelScroll( "F23", "WheelUp" )

AccelScroll( key, dir ) {
    ; --- 調整用パラメータ -------------------------------------------
    static REPEAT_DELAY := 220 ; 長押し判定までの猶予(ms)。これ未満で離せば単押し
    static INTERVAL     := 40  ; 長押し中のリピート周期(ms)
    static RAMP_STEP    := 120 ; この時間(ms)経過ごとに1回あたりのノッチ数が+1
    static MIN_NOTCH    := 2   ; 1回あたりの最小ノッチ数（単押しもこの量。小数可）
    static MAX_NOTCH    := 5   ; 1回あたりの最大ノッチ数（アッパー）
    ; 上記初期値では 220 + 120*3 = 約580ms で上限に到達する
    ; -----------------------------------------------------------------

    ; OSのキーリピートによる多重起動を防ぐ
    ; static は上下で共有されるため、同時に走るスクロールは常に1方向だけになる
    static running := false
    if ( running )
        return
    running := true

    ; 単押し分：まず最小量を送る
    SendWheel( dir, MIN_NOTCH )
    st := A_TickCount

    while ( GetKeyState( key, "P" ) ) {
        elapsed := A_TickCount - st
        ; 猶予時間内はまだリピートしない（単押しと区別するため）
        if ( elapsed < REPEAT_DELAY ) {
            Sleep 15
            continue
        }
        n := Min( MAX_NOTCH, MIN_NOTCH + ( elapsed - REPEAT_DELAY ) // RAMP_STEP )
        SendWheel( dir, n )
        Sleep INTERVAL
    }

    running := false
}

; ホイールイベントを生のデルタ値で送る（1ノッチ = 120単位）。
; Send "{WheelDown n}" は n が整数のみだが、こちらは 1.5 のような小数ノッチを送れる。
; 小数デルタを解さない古いアプリでも、内部で余りを累積するため平均量は指定どおりになる。
SendWheel( dir, notches ) {
    static MOUSEEVENTF_WHEEL := 0x0800 ; 垂直ホイール
    sign := ( dir = "WheelUp" ) ? 1 : -1 ; 正の値 = 上、負の値 = 下
    DllCall( "mouse_event", "UInt", MOUSEEVENTF_WHEEL, "Int", 0, "Int", 0, "Int", Round( sign * notches * 120 ), "UPtr", 0 )
}
