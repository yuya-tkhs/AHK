; Common.ahkの^Enterハンドラから呼ばれる
; Premiere固有の追加処理はPremiere.ahkのOnCtrlEnterPremiere()に記述
OnCtrlEnterPost() {
    if WinActive(exe_ps) || WinActive(exe_ai)
        Send("{vk1D}")
    else if WinActive(exe_pr)
        OnCtrlEnterPremiere()
}
