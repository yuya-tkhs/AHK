; duration はミリ秒（ToolTipEx の TimeOut は秒のため変換）
; wrapWidth を超える行は WrapText() で折り返す。ネイティブのツールチップは
; 改行文字でしか折れないため、長いパスなどを出すと横に伸び続けるので。
; 既定の80は2ストロークのメニュー（最長はグローバルのノブ欄で61）が折れない値にしてある。
; クリアは「破棄」ではなく「ID=1 の非表示」で行う（ToolTipEx の第3引数）。
; 引数無しの ToolTipEx() は WinClose でツールチップを破棄するため、
; 直後に次のツールチップを出すと破棄と生成が競合して**表示されない**。
; 3ストロークで第1階層→サブメニューに切り替わらなかった原因がこれ。
; 実測：破棄方式は5回中5回失敗、非表示方式は5回中5回成功。
MyTooltip(text := "", duration := 300, wrapWidth := 80) {
    if (text = "")
        ToolTipEx(, , 1)
    else
        ToolTipEx(StretchSeparators(WrapText(text, wrapWidth)), duration / 1000)
}

; 「- - - -」だけの行（メニューの区切り線）を、罫線（─）だけの線に置き換え、
; 他の行のうち最も長いものの幅まで伸ばす。半角ハイフンは字間が空いて点線に見えるため、
; 字の幅いっぱいに描かれて隣とつながる罫線素片（U+2500）を使う。元の文字列は「- - -」のままにしておく
; （ショートカット一覧の MenuTextRows() が先頭の「-」で区切り線を見分けるため）。
; ツールチップのフォントはプロポーショナルなので文字数では合わず、実際に描く幅（ピクセル）で比べる。
; 折り返し（WrapText）の後にかける。区切り線は全角換算で文字数が多くなるため、先に伸ばすと
; 区切り線そのものが折り返されてしまう。
StretchSeparators(text) {
    static LINE_CHAR := "─"
    if !RegExMatch(text, "m)^-( -)*$")
        return text
    lines := StrSplit(text, "`n", "`r")
    maxW := 0
    for line in lines
        if !RegExMatch(line, "^-( -)*$")
            maxW := Max(maxW, TooltipTextWidth(line))
    if (maxW = 0)
        return text
    ; 罫線だけを並べる（「──────」）。
    ; 最長の行を超えない最大の本数にする。見積もりの後、実測で超えていれば1本ずつ削る
    n := Max(1, Floor(maxW / TooltipTextWidth(LINE_CHAR)))
    sep := StrRepeat(LINE_CHAR, n)
    while (n > 1 && TooltipTextWidth(sep) > maxW)
        sep := StrRepeat(LINE_CHAR, --n)
    out := ""
    for i, line in lines
        out .= (i > 1 ? "`n" : "") (RegExMatch(line, "^-( -)*$") ? sep : line)
    return out
}

; str を count 回つなげた文字列
StrRepeat(str, count) {
    return StrReplace(Format("{:" count "}", ""), " ", str)
}

; ツールチップ（tooltips_class32）と同じフォントで描いたときの幅（ピクセル）。
; ツールチップはシステムのステータスフォント（NONCLIENTMETRICS.lfStatusFont）で描かれる。
; 行どうしの比較にしか使わないので、画面のDPIとの差は問題にならない。
TooltipTextWidth(str) {
    static hFont := 0
    if !hFont {
        ; NONCLIENTMETRICSW = 504バイト（iPaddedBorderWidth 込み）。LOGFONTW は92バイト。
        ; lfStatusFont は cbSize + int×5 + lfCaption + int×2 + lfSmCaption + int×2 + lfMenu の後＝316
        ncm := Buffer(504, 0)
        NumPut("UInt", 504, ncm, 0)
        DllCall("SystemParametersInfoW", "UInt", 0x29, "UInt", 504, "Ptr", ncm, "UInt", 0)  ; SPI_GETNONCLIENTMETRICS
        hFont := DllCall("CreateFontIndirectW", "Ptr", ncm.Ptr + 316, "Ptr")
    }
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
    sz := Buffer(8, 0)
    DllCall("GetTextExtentPoint32W", "Ptr", hdc, "WStr", str, "Int", StrLen(str), "Ptr", sz)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return NumGet(sz, 0, "Int")
}

; 全角を2・半角を1として数え、width を超えたところで改行を入れる。
; 単純に文字数で切ると日本語と英数が混ざったとき見た目の幅がそろわないため。
; 既存の改行は保持し、width に収まる行はそのまま返す。
; 単語やパスの区切りは見ずに折るが、対象がパスやURL（空白を含まない）なので実害はない。
WrapText(text, width := 60) {
    if (width <= 0)
        return text
    out := ""
    for i, line in StrSplit(text, "`n", "`r") {
        if (i > 1)
            out .= "`n"
        w := 0
        Loop Parse line {
            cw := IsWideChar(Ord(A_LoopField)) ? 2 : 1
            if (w + cw > width) {
                out .= "`n"
                w := 0
            }
            out .= A_LoopField
            w += cw
        }
    }
    return out
}

; 表示幅が2になる文字か（East Asian Wide / Fullwidth のうち実際に使う範囲）
IsWideChar(code) {
    return (code >= 0x1100 && code <= 0x115F)    ; ハングル字母
        || (code >= 0x2E80 && code <= 0xA4CF)    ; CJK・かな・約物
        || (code >= 0xAC00 && code <= 0xD7A3)    ; ハングル音節
        || (code >= 0xF900 && code <= 0xFAFF)    ; CJK互換漢字
        || (code >= 0xFF00 && code <= 0xFF60)    ; 全角英数・記号
        || (code >= 0xFFE0 && code <= 0xFFE6)    ; 全角記号
}

; 取り残された同一スクリプトの常駐を終了する。
; 戻り値: {killed: 終了できた数, survived: 終了できなかった数}
; #SingleInstance Force は旧インスタンスの置き換えに失敗することがあり、
; 失敗すると同じスクリプトが二重に常駐したままになる。
; この状態では「~」付き（非抑制）のホットキーが両方のインスタンスで発火するため
; InputHookが2本待機し、選択キーを捕捉できなかった方が待機したまま取り残されて、
; 後から押したキーを横取りする（ダイアログ表示中のEnterが「無効なキーです」に
; 化ける原因。実際に11時間前の残骸と併存していた事例あり）。
; メインウィンドウのタイトルは「<スクリプトのフルパス> - AutoHotkey v2.0.x」なので、
; 前方一致で判定すれば他のスクリプトやコンパイル済みexeには当たらない。
; ProcessClose を使うのは、応答不能になった残骸でも確実に落とすため。
KillDuplicateInstances() {
    prevDetect := A_DetectHiddenWindows
    DetectHiddenWindows true
    killed := 0, survived := 0
    for hwnd in WinGetList("ahk_class AutoHotkey") {
        if (hwnd = A_ScriptHwnd)        ; 自分自身は対象外
            continue
        try {
            if (SubStr(WinGetTitle(hwnd), 1, StrLen(A_ScriptFullPath)) != A_ScriptFullPath)
                continue
            pid := WinGetPID(hwnd)
            ProcessClose(pid)
            ; 落とせたか必ず確認する。権限が食い違うと ProcessClose は失敗しうるが、
            ; 黙って見逃すと二重常駐に気づけないまま同じ症状に戻るため。
            ProcessWaitClose(pid, 2)
            if ProcessExist(pid)
                survived++
            else
                killed++
        }
    }
    DetectHiddenWindows prevDetect
    return { killed: killed, survived: survived }
}

; クリップボードの中身がURLらしいか判定する
; 前後の囲み文字を許容しつつ、http(s):// / 欠けたスキーム / www. 始まりをURLとみなす
IsUrl(text) {
    t := Trim(text, " `t`r`n`f`v　")
    return RegExMatch(t, "i)^[`"'<（(「『【\[]*(h?t{1,2}ps?://|www\.)") > 0
}

; コピーしたURLを整形して返す（整形不要ならそのまま返す）
;  ①前後の空白・改行・引用符・囲み文字・末尾の句読点を除去
;  ②欠けたスキームを補完（ttps:// → https:// など、www. には https:// を付与）
CleanUrl(text) {
    ; 前後の空白・改行・全角スペースを除去
    url := Trim(text, " `t`r`n`f`v　")
    ; 先頭の囲み文字（引用符・括弧類）を除去
    url := RegExReplace(url, "^[`"'<（(「『【\[\s　]+", "")
    ; 末尾の空白・引用符・囲み文字・和文句読点を除去
    url := RegExReplace(url, "[`"'>」』】\]\s　。、．，]+$", "")
    ; 末尾の欧文句読点を除去
    url := RegExReplace(url, "[.,;:!?]+$", "")
    ; 対になる '(' が無いときだけ末尾の ')' を除去（Wikipedia等の正当な括弧を守る）
    if !InStr(url, "(")
        url := RegExReplace(url, "\)+$", "")

    ; 欠けたスキームを補完
    url := RegExReplace(url, "i)^h?t{1,2}ps://", "https://")
    url := RegExReplace(url, "i)^h?t{1,2}p://", "http://")
    if RegExMatch(url, "i)^www\.")
        url := "https://" url

    return url
}

;;
;; 2/3ストロークメニューの共通部品（Illustrator / エクスプローラー）
;;
;;   グループは { key, label, items }、項目は { key, label, disp?, direct? } の形で持つ。
;;   項目にはこれ以外に各アプリが実行内容（jsx / cmd など）を自由に足してよい。
;;;;

; 項目の表示用キー（矢印は disp に "←" などを持たせる）
MenuItemDisp(item) {
    return item.HasOwnProp("disp") ? item.disp : item.key
}
MenuItemIsDirect(item) {
    return item.HasOwnProp("direct") && item.direct
}

; 第1階層のツールチップに足すグループ欄。全項目を、実際に打つキー列そのままで並べる。
; direct の項目は第2打鍵だけで動くので短い方を出し、それ以外は
; 「グループキー + 項目キー」の3ストロークを出す。
; 降りてから選ぶ前に何が入っているか分かるよう、第3打鍵まで見せる。
BuildGroupMenuLines(groups) {
    text := ""
    for group in groups {
        text .= "`n- - - - - - - - - - - - - - - -`n" group.label " [" group.key "]"
        for item in group.items {
            seq := MenuItemIsDirect(item) ? MenuItemDisp(item) : group.key " " MenuItemDisp(item)
            text .= "`n" seq ": " item.label
        }
    }
    return text
}

; 第2階層（サブメニュー）のツールチップ。1行目をパンくずにする
BuildSubMenuText(group) {
    text := "2ストローク > " group.label "（10秒）"
    text .= "`n- - - - - - - - - - - - - - - -"
    for item in group.items
        text .= "`n" MenuItemDisp(item) ": " item.label
    return text "`n- - - - - - - - - - - - - - - -`nBS: 戻る / Esc: キャンセル"
}

; InputHookのEndKey指定を組み立てる。
; 矢印のような文字にならないキーはEndKeyにしないと拾えないため、
; そのグループの項目から自動で拾う（1文字のキーは通常の文字入力で取れる）。
BuildMenuEndKeys(group, allowBack) {
    keys := allowBack ? "{Escape}{Space}{Backspace}" : "{Escape}{Space}"
    if (group)
        for item in group.items
            if (StrLen(item.key) > 1)
                keys .= "{" item.key "}"
    return keys
}

; 押されたキーに対応するグループを返す（無ければ ""）
FindMenuGroup(groups, key) {
    for group in groups
        if (group.key == key)
            return group
    return ""
}

; グループ内で押されたキーに対応する項目を返す（無ければ ""）。
; == で大文字小文字を区別する（e と E を分けるため）
FindGroupItem(group, key) {
    for item in group.items
        if (item.key == key)
            return item
    return ""
}

; メニューを出してキーを1つ読む。Escapeとタイムアウトは "" を返す。
; 「戻る」を許すと Backspace をそのまま返す。
; フックはツールチップを描く「前」に張る。Wait()が返ってから次のStartまでの
; 隙間に押されたキーはアプリへ素通りし、単キーがツール切替などに化けるため。
ReadMenuKey(menuText, allowBack := false, group := "", timeoutSec := 10) {
    ih := InputHook("L1 T" timeoutSec)
    ; "S"（Suppress）が要る。InputHook は文字キーを抑制するが、矢印のような
    ; 非文字キーは既定（VisibleNonText）で素通しするため、EndKeyに指定しただけでは
    ; アプリにも届く。Illustratorではオブジェクトが動き、Backspace は選択中の
    ; オブジェクトを削除する。エクスプローラーの BS（→ Del）ホットキーより
    ; InputHook が先に捕捉することは実測確認済み（ファイルは消えない）。
    ih.KeyOpt(BuildMenuEndKeys(group, allowBack), "SE")
    ih.Start()
    MyTooltip(menuText, timeoutSec * 1000)
    ih.Wait()
    MyTooltip()
    if (ih.EndReason = "Timeout")
        return ""
    key := (ih.EndReason = "EndKey") ? ih.EndKey : ih.Input
    return (key = "Escape") ? "" : key
}

; サブメニューを出して項目を1つ選ばせる。
; 戻り値: 項目 / "Backspace"（第1階層へ戻る）/ ""（キャンセル・タイムアウト・無効なキー）
ReadSubMenuItem(group) {
    key := ReadMenuKey(BuildSubMenuText(group), true, group)
    if (key = "" || key = "Backspace")
        return key
    if (item := FindGroupItem(group, key))
        return item
    MyTooltip("無効なキーです", 500)
    return ""
}
