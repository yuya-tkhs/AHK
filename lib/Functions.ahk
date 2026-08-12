; duration はミリ秒（ToolTipEx の TimeOut は秒のため変換）
; wrapWidth を超える行は WrapText() で折り返す。ネイティブのツールチップは
; 改行文字でしか折れないため、長いパスなどを出すと横に伸び続けるので。
; 既定の60は2ストロークのメニュー（最長31）が折れない値にしてある。
MyTooltip(text := "", duration := 300, wrapWidth := 60) {
    if (text = "")
        ToolTipEx()
    else
        ToolTipEx(WrapText(text, wrapWidth), duration / 1000)
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

; variation: 色の許容誤差（0-255）。大きいほど判定がゆるくなる
ClickImageAndReturn(imgPath, notFoundMsg, variation := 100) {
    if ImageSearch(&imgX, &imgY, 0, 0, A_ScreenWidth, A_ScreenHeight, "*" variation " " imgPath) {
        MouseGetPos(&origX, &origY)
        Click imgX, imgY
        MouseMove origX, origY
    } else
        MyTooltip(notFoundMsg, 1500)
}