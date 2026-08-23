; Common.ahkの^Enterハンドラから呼ばれる
; Premiere固有の追加処理はPremiere.ahkのOnCtrlEnterPremiere()に記述
OnCtrlEnterPost() {
    if WinActive(exe_ps) || WinActive(exe_ai)
        Send("{vk1D}")
    else if WinActive(exe_pr)
        OnCtrlEnterPremiere()
}

;;
;; 日本語入力のままツールのショートカットを押したときの救済
;;;;
; Adobe系では、IMEがONのままツールキー（V など）を押すと打鍵が未確定文字列に
; 吸われ、ツールが切り替わらない。押した本人は「効かない」としか分からない。
; これを自動で救済する。
;
; 「テキスト入力先が無いまま変換中」であることは、変換用の浮動窓
; CiceroUIWndFrame の存在で判定する。実測で出方がきれいに分かれた：
;   キャンバス上のテキスト編集中     … ATOK36Cand のみ（CiceroUIWndFrame は出ない）
;   パネルの入力欄（レイヤー名など） … MSCTFIME Composition（同上）
;   テキスト入力先が無い             … CiceroUIWndFrame が出る ← ここだけ救済する
; この窓は未確定文字列を表示するもので、幅が1文字あたり約11px増えるのを確認済み。
;
; この判定なら、ローマ字の子音2連打（って=tt / かっこ=kk など）を正規に入力して
; いる最中に誤爆しない。そのため「2回連打したら」のような打鍵回数の条件は不要で、
; 1打目から救済でき、対象キーを英字すべてに広げられる。
; 判定コストは実測 0.07ms/回（IsImeOn() の 0.013ms と同程度）。
; 常駐 InputHook は使わない（体感遅延が出るため廃止済み）。

global AdobeImeRescueDelay := 120   ; 打鍵から窓が出るまで実測約60ms。余裕をみる

; 打鍵の直後はまだ窓が無いので、少し待ってから判定する
ScheduleImeRescue(key, *) {
    global AdobeImeRescueDelay
    SetTimer(ImeRescueCheck.Bind(key), -AdobeImeRescueDelay)
}

ImeRescueCheck(key) {
    if !IsAdobeApp()
        return
    ; 可視の窓だけを探したいので DetectHiddenWindows は既定(Off)のまま使う
    if !WinExist("ahk_class CiceroUIWndFrame ahk_pid " WinGetPID("A"))
        return
    Send("{Escape}")        ; 未確定文字列を破棄（これが無いと ｖ が残る）
    Sleep(40)
    Send("{vk1D}")          ; 半角英数へ。変換中に送るとカタカナ変換に食われるのでEscの後
    Sleep(40)
    Send("{" key "}")       ; 本来やりたかったツール切り替え
    MyTooltip("日本語入力をOFFにして " StrUpper(key) " を送りました", 1200)
}

; 対象は英字すべて。判定が厳密なのでキーを絞る必要がない。
; 修飾キー付き（Ctrl+S など）はIMEに吸われないので対象外＝「*」は付けない。
HotIf((*) => IsAdobeApp())
for _imeKey in StrSplit("abcdefghijklmnopqrstuvwxyz")
    Hotkey("~" _imeKey, ScheduleImeRescue.Bind(_imeKey))
HotIf()
