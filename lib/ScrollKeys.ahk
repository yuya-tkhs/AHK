;;
;; キーによる加速スクロール（ペンタブのスクロール操作を模したもの）
;;   F22 = スクロールダウン / F23 = スクロールアップ
;;   単押し → 1ノッチだけ送る（細かい操作用）
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
    static MAX_NOTCH    := 5   ; 1回あたりの最大ノッチ数（アッパー）
    ; 上記初期値では 220 + 120*4 = 約700ms で上限に到達する
    ; -----------------------------------------------------------------

    static running := false
    ; OSのキーリピートによる多重起動を防ぐ
    if ( running )
        return
    running := true

    ; 単押し分：まず1ノッチ送る
    Send "{" . dir . "}"
    st := A_TickCount

    while ( GetKeyState( key, "P" ) ) {
        elapsed := A_TickCount - st
        ; 猶予時間内はまだリピートしない（単押しと区別するため）
        if ( elapsed < REPEAT_DELAY ) {
            Sleep 15
            continue
        }
        n := Min( MAX_NOTCH, 1 + ( elapsed - REPEAT_DELAY ) // RAMP_STEP )
        Send "{" . dir . " " . n . "}"
        Sleep INTERVAL
    }

    running := false
}
