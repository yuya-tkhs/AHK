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
global AdobeImeRescueMaxKeys  := 8     ; 一度に送り直す打鍵数の上限（暴走よけ）

; IMEに吸われた可能性のある打鍵を、救済されるか時間切れになるまで持っておく。
; 連打のうち窓が出る前（実測60ms）に入った分は Esc でまとめて消えるため、
; 1回だけ送り直すと打鍵数が減ってしまう。溜めた分をまとめて送り直す。
global _imeRescuePending := []
global _imeRescueBusy := false         ; 救済の実行中か（Sleep中に別の打鍵が割り込むため）

; 打鍵の直後はまだ窓が無いので、少し待ってから判定する
; shift: Shift併用で押されたか（Shift+M のようなツールキーも救済対象のため）
ScheduleImeRescue(key, shift, *) {
    global _imeRescuePending
    ImeRescuePrune()
    entry := { key: key, shift: shift, tick: A_TickCount, done: false }
    _imeRescuePending.Push(entry)
    SetTimer(ImeRescueCheck.Bind(entry), -AdobeImeRescueDelay)
}

; 窓が出ていれば救済する。まだなら AdobeImeRescueTimeout まで再確認を繰り返す。
; 固定待ちを止めて短い間隔で覗きに行くことで、窓が出た時点ですぐ動ける。
ImeRescueCheck(entry) {
    global _imeRescueBusy
    if entry.done                       ; 直前の救済でまとめて送り直された
        return
    if !IsAdobeApp() {                  ; フォーカスが離れた。もう送り直さない
        entry.done := true
        return
    }
    pid := WinGetPID("A")
    ; 可視の窓だけを探したいので DetectHiddenWindows は既定(Off)のまま使う
    ; 救済の実行中も判断を保留する。Esc→無変換→キー の途中で覗くと、消えかけの窓を
    ; 見て二重に救済してしまうため。保留した打鍵は終わってから改めて判断される
    if (_imeRescueBusy || !ImeRescueComposing(pid)) {
        if (A_TickCount - entry.tick < AdobeImeRescueTimeout)
            SetTimer(ImeRescueCheck.Bind(entry), -AdobeImeRescuePoll)
        else
            entry.done := true          ; 時間切れ＝吸われずにアプリへ届いていた
        return
    }
    ImeRescueRun(pid)
}

; 溜まっている打鍵をまとめて送り直す
ImeRescueRun(pid) {
    global _imeRescuePending, _imeRescueBusy
    batch := []
    for e in _imeRescuePending {
        if !e.done {
            e.done := true              ; 各打鍵の再確認タイマーを止める
            batch.Push(e)
        }
    }
    _imeRescuePending := []
    if !batch.Length
        return
    if (batch.Length > AdobeImeRescueMaxKeys)
        batch.Length := AdobeImeRescueMaxKeys
    _imeRescueBusy := true
    Send("{Escape}")        ; 未確定文字列を破棄（これが無いと ｖ が残る）
    ImeRescueWaitUntil(() => !ImeRescueComposing(pid), AdobeImeRescueStep)
    Send("{vk1D}")          ; 半角英数へ。変換中に送るとカタカナ変換に食われるのでEscの後
    ImeRescueWaitUntil(() => !IsImeOn(), AdobeImeRescueStep)
    seq := ""               ; 押された順に1回の Send で送る（間に生の打鍵が挟まらない）
    for e in batch
        seq .= (e.shift ? "+" : "") "{" e.key "}"
    Send(seq)               ; 本来やりたかったツール切り替え
    _imeRescueBusy := false
    MyTooltip(ImeRescueMessage(batch), 1200)
}

; 時間切れ・送り直し済みの打鍵を捨てる。救済が一度も起きなくても溜まり続けないように、
; 打鍵のたびに掃除する（残るのは直近 AdobeImeRescueTimeout ぶんだけ）
ImeRescuePrune() {
    global _imeRescuePending
    live := []
    for e in _imeRescuePending {
        if (!e.done && A_TickCount - e.tick < AdobeImeRescueTimeout)
            live.Push(e)
    }
    _imeRescuePending := live
}

; ツールチップの文言。同じキーの連打は「V を3回」とまとめる
ImeRescueMessage(batch) {
    labels := []
    for e in batch
        labels.Push((e.shift ? "Shift+" : "") ImeRescueKeyLabel(e.key))
    same := true
    for lb in labels
        if (lb !== labels[1])
            same := false
    if (same)
        return "日本語入力をOFFにして " labels[1] " を" (labels.Length > 1 ? labels.Length "回" : "") "送りました"
    joined := ""
    for lb in labels
        joined .= (joined ? " " : "") lb
    return "日本語入力をOFFにして " joined " を送りました"
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
