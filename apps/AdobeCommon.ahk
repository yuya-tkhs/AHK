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

; 待ちはすべて「起きるはずのことを観測して、起きたら即進む」方式にした。
; 上限は従来の固定待ち（判定120ms＋Esc後40ms＋無変換後40ms＝約200ms）と同じなので、
; 最悪でも従来と同じ速さで、通常はそれより速く終わる（実測で窓が出るのは約60ms後）。
global AdobeImeRescueDelay    := 30    ; 打鍵から最初に窓を見に行くまで
global AdobeImeRescuePoll     := 15    ; 窓が出るまでの再確認間隔
global AdobeImeRescueTimeout  := 180   ; ここまで出なければ「変換中ではない」と諦める
global AdobeImeRescueStep     := 40    ; Esc後・無変換後の待ちの上限
global AdobeImeRescueCooldown := 150   ; 救済直後に次の救済を始めない時間

global _imeRescueBusy := false         ; 救済の実行中か（Sleep中に別の打鍵が割り込むため）
global _imeRescueDoneTick := 0         ; 直前の救済が終わった時刻

; 打鍵の直後はまだ窓が無いので、少し待ってから判定する
; shift: Shift併用で押されたか（Shift+M のようなツールキーも救済対象のため）
ScheduleImeRescue(key, shift, *) {
    global AdobeImeRescueDelay
    SetTimer(ImeRescueCheck.Bind(key, shift, A_TickCount), -AdobeImeRescueDelay)
}

; 窓が出ていれば救済する。まだなら AdobeImeRescueTimeout まで再確認を繰り返す。
; 固定待ちを止めて短い間隔で覗きに行くことで、窓が出た時点ですぐ動ける。
; pressedTick: 打鍵時刻（諦めるまでの猶予を打鍵からの経過で測るため）
ImeRescueCheck(key, shift, pressedTick) {
    global _imeRescueBusy, _imeRescueDoneTick
    ; 救済中とその直後は何もしない。Esc→無変換→キー の間に押されたキーの確認が
    ; 割り込むと、消えかけの窓を見て二重に救済してしまうため
    if _imeRescueBusy || (A_TickCount - _imeRescueDoneTick < AdobeImeRescueCooldown)
        return
    if !IsAdobeApp()
        return
    pid := WinGetPID("A")
    ; 可視の窓だけを探したいので DetectHiddenWindows は既定(Off)のまま使う
    if !ImeRescueComposing(pid) {
        if (A_TickCount - pressedTick < AdobeImeRescueTimeout)
            SetTimer(ImeRescueCheck.Bind(key, shift, pressedTick), -AdobeImeRescuePoll)
        return
    }
    _imeRescueBusy := true
    Send("{Escape}")        ; 未確定文字列を破棄（これが無いと ｖ が残る）
    ImeRescueWaitUntil(() => !ImeRescueComposing(pid), AdobeImeRescueStep)
    Send("{vk1D}")          ; 半角英数へ。変換中に送るとカタカナ変換に食われるのでEscの後
    ImeRescueWaitUntil(() => !IsImeOn(), AdobeImeRescueStep)
    Send((shift ? "+" : "") "{" key "}")    ; 本来やりたかったツール切り替え
    _imeRescueDoneTick := A_TickCount
    _imeRescueBusy := false
    MyTooltip("日本語入力をOFFにして " (shift ? "Shift+" : "") ImeRescueKeyLabel(key) " を送りました", 1200)
}

; テキスト入力先が無いまま変換中か（未確定文字列の浮動窓が出ているか）
ImeRescueComposing(pid) {
    return WinExist("ahk_class CiceroUIWndFrame ahk_pid " pid) != 0
}

; cond が成立するまで待つ。timeout(ms) に達したら成立していなくても返る。
; 上限を従来の固定待ちと同じにしてあるので、観測が空振りしても遅くはならない。
ImeRescueWaitUntil(cond, timeout) {
    endTick := A_TickCount + timeout
    loop {
        if cond()
            return true
        if (A_TickCount >= endTick)
            return false
        Sleep(5)
    }
}

; ツールチップに出す表記。記号キーは "vkBA" のままだと何のことか分からないので、
; MapVirtualKey で実際の文字（: ; @ ^ など）に直す。対応表を手書きすると
; キーを足したときにずれるため、OSに引かせる。
ImeRescueKeyLabel(key) {
    if (SubStr(key, 1, 2) != "vk")
        return StrUpper(key)
    code := DllCall("MapVirtualKeyW", "UInt", Integer("0x" SubStr(key, 3)), "UInt", 2, "UInt")
    return code ? Chr(code & 0x7FFF) : key
}

; 対象は文字を生むキーすべて（英字・数字・記号）。判定が厳密なのでキーを絞る必要がない。
; 英字だけにしていたら記号のツールキーが救済されなかったため広げた。
; 記号は「^」がAHKの修飾キー記号と紛れるので、JIS配列で位置が決まる vk コードで指定する。
AdobeImeRescueKeys() {
    keys := []
    for k in StrSplit("abcdefghijklmnopqrstuvwxyz")
        keys.Push(k)
    Loop 10                                     ; 0〜9
        keys.Push("vk" Format("{:X}", 0x30 + A_Index - 1))
    ; JIS配列の記号キー（括弧内は無シフト時の文字）
    ; BA(:) BB(;) BC(,) BD(-) BE(.) BF(/) C0(@) DB([) DC(¥) DD(]) DE(^) E2(\)
    for vk in ["BA", "BB", "BC", "BD", "BE", "BF", "C0", "DB", "DC", "DD", "DE", "E2"]
        keys.Push("vk" vk)
    return keys
}

; 修飾キー付き（Ctrl+S など）はIMEに吸われないので対象外＝「*」は付けない。
; 「-」「:」などはPremiere側にも定義があるが、あちらは左ボタン押下中限定の
; 別バリアントなので競合しない（先に登録された側が条件成立時だけ優先される）。
; Shift併用（Shift+M など）もツールキーとして使われ、同じようにIMEに吸われるので
; 両方を登録する。Ctrl/Alt併用はIMEに吸われないため対象外。
HotIf((*) => IsAdobeApp())
for _imeKey in AdobeImeRescueKeys() {
    Hotkey("~" _imeKey, ScheduleImeRescue.Bind(_imeKey, false))
    Hotkey("~+" _imeKey, ScheduleImeRescue.Bind(_imeKey, true))
}
HotIf()
