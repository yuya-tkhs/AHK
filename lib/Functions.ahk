; 引数 text の初期値を "" にすることで、 MyTooltip() と空で呼べるようにします
MyTooltip(text := "", duration := 300) {
    static followTimer := ""
    static clearTimer := ""
    static prevX := "", prevY := ""
    static ttHwnd := 0  ; ツールチップのウィンドウIDを記憶する変数

    ; ==========================================================
    ; ★ 追加：即時消去モード（text が空っぽの時）
    ; ==========================================================
    if (text = "") {
        if (followTimer) {
            SetTimer(followTimer, 0) ; 追従タイマーを強制停止
            SetTimer(clearTimer, 0)  ; 消去タイマーを強制停止
        }
        ToolTip()             ; 画面上のツールチップを消去
        followTimer := ""     ; 状態を完全にリセット
        clearTimer := ""
        ttHwnd := 0
        return                ; これより下の「描画処理」は行わずに終わる
    }

    ; --- 以前の処理をリセット ---
    if (followTimer) {
        SetTimer(followTimer, 0)
        SetTimer(clearTimer, 0)
    }

    ; --- 準備段階 ---
    savedMouse := A_CoordModeMouse
    savedToolTip := A_CoordModeToolTip
    CoordMode("Mouse", "Screen")
    CoordMode("ToolTip", "Screen")

    ; 1. 最初に「1回だけ」正規のToolTipを描画して画面に出す
    MouseGetPos(&mX, &mY)
    ToolTip(text, mX + 16, mY + 16)

    ; 2. 出現したToolTipの「ウィンドウID（HWND）」をこっそり取得する
    scriptPID := WinGetPID(A_ScriptHwnd)
    ttHwnd := WinExist("ahk_class tooltips_class32 ahk_pid " scriptPID)

    ; 設定を元に戻す
    CoordMode("Mouse", savedMouse)
    CoordMode("ToolTip", savedToolTip)

    ; --- 追従ループ（10ミリ秒ごと） ---
    FollowCursor() {
        savedMouseTemp := A_CoordModeMouse
        CoordMode("Mouse", "Screen")

        MouseGetPos(&mX, &mY)

        if (mX == prevX && mY == prevY) {
            CoordMode("Mouse", savedMouseTemp)
            return
        }
        prevX := mX, prevY := mY

        if (ttHwnd) {
            WinMove(mX + 16, mY + 16,,, ttHwnd)
        }

        CoordMode("Mouse", savedMouseTemp)
    }

    ; --- 終了処理 ---
    ClearTooltip() {
        SetTimer(followTimer, 0)
        ToolTip() 
        followTimer := ""
        clearTimer := ""
        ttHwnd := 0
    }

    followTimer := FollowCursor
    clearTimer := ClearTooltip

    SetTimer(followTimer, 10)
    SetTimer(clearTimer, -duration)
}

toggleOnishiAndTenkey() {
    toggleTenkeyMode()
    toggleOnishiMode()
}