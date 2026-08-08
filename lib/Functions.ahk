; duration はミリ秒（ToolTipEx の TimeOut は秒のため変換）
MyTooltip(text := "", duration := 300) {
    if (text = "")
        ToolTipEx()
    else
        ToolTipEx(text, duration / 1000)
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

; 既に起動していればウィンドウをアクティブにし、無ければ起動する
;   winTitle … 判定に使うウィンドウ識別子（yuya_allways.ahk の exe_* を渡す）
;   target   … Run に渡す実行ファイル名／パス
LaunchOrActivate(winTitle, target) {
    if WinExist(winTitle)
        WinActivate                 ; 直前の WinExist で見つかったウィンドウ
    else
        Run target
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