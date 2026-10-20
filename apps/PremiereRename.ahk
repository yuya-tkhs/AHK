;;
;; Premiere のトラック名変更を、AHK のダイアログ（Premiere の外）で行う（^Space → 2）
;;
;;   Premiere（NewWorld）では ScriptUI のダイアログが使えないので、入力は AHK の Gui で受け、
;;   値を jsx に渡す。jsx の側は adobe-scripts リポジトリの premiere/ExtendScript/リネーム.jsx。
;;   1. 読み取り：リネーム.jsx を args.op="list" で流し、トラック名の一覧を受け取る（往復 約0.1秒、実測）
;;      クリップを選択していれば、jsx がそのまま今までどおりの prompt でクリップ名を聞いて終わる（Gui は出さない）
;;   2. Gui で編集 → Ctrl+Enter / Enter で確定、Esc で取消
;;   3. 適用：args.op="apply" で新しい名前を流す。読んだときとシーケンス・本数・名前が違うトラックは jsx が変えない
;;
;;   値の渡し方：%TEMP%\jsxl\<id>.call.jsx（純 ASCII）に
;;     $.global.__jsxlReq = {…}; $.evalFile(new File("<adobe-scripts>/premiere/claude/jsxl_wrap.jsx"));
;;   を書き、JsxLauncher に runfile: で流す。包み（jsxl_wrap.jsx）が期限・結果ファイル（<id>.result.json）を受け持つ。
;;   Claude Code の premiere/claude/ppro_run.ps1 と同じ約束（adobe-scripts の CLAUDE.md「Claude から Premiere の jsx を実行する」）。
;;   ps1 の lock（%TEMP%\jsxl\lock）は取らない（人のキー操作を Claude の実行待ちで止めないため）。
;;;;

global gPrScriptsDir := "W:\共有ドライブ\wc動画\sync\Assets\adobe-scripts_tkhs\premiere\"
global gJsxlDir := A_Temp "\jsxl"
global _prRn := ""                  ; 進行中の呼び出し { id, phase, deadline, runUntil, … }
global _prRnGui := "", _prRnEdits := [], _prRnList := ""

; ---- 値の受け渡し（Premiere 用の汎用部品） ----

; JS の文字列リテラル（純 ASCII）。UTF-16 の単位ごとに見て、0x20 未満と 0x7E 超は \uXXXX にする
JsxlStr(s) {
    s := String(s), out := '"'
    Loop StrLen(s) {
        c := NumGet(StrPtr(s), (A_Index - 1) * 2, "UShort")
        if (c = 0x22)
            out .= '\"'
        else if (c = 0x5C)
            out .= "\\"
        else if (c < 0x20 || c > 0x7E)
            out .= Format("\u{:04x}", c)
        else
            out .= Chr(c)
    }
    return out '"'
}
JsxlArr(list) {
    out := ""
    for v in list
        out .= (out = "" ? "" : ",") JsxlStr(v)
    return "[" out "]"
}
; ExtendScript の new Date().getTime() と同じ UTC の epoch ms
JsxlNowMs() {
    DllCall("GetSystemTimeAsFileTime", "Int64*", &ft := 0)
    return (ft - 116444736000000000) // 10000
}

; target の jsx を、値（inputJs：JS のオブジェクトリテラル）つきで流す。
; startMs までに Premiere で始まらなければ、包みは本体を実行しない（expired）
JsxlCall(target, inputJs, startMs := 3000, runMs := 120000) {
    global gJsxlDir, gPrScriptsDir
    DirCreate(gJsxlDir)
    id := "ahk-" FormatTime(, "yyyyMMdd-HHmmss") "-" A_MSec "-" Format("{:04x}", Random(0, 0xFFFF))
    now := JsxlNowMs()
    slash(p) => StrReplace(p, "\", "/")
    js := "$.global.__jsxlReq={id:" JsxlStr(id) ",deadline:" (now + startMs) ",runMs:" runMs
        . ",out:" JsxlStr(slash(gJsxlDir)) ",target:" JsxlStr(slash(target)) ",input:" inputJs "};`n"
        . "$.evalFile(new File(" JsxlStr(slash(gPrScriptsDir "claude\jsxl_wrap.jsx")) "));`n"
    call := gJsxlDir "\" id ".call.jsx"
    f := FileOpen(call, "w", "UTF-8-RAW")
    f.Write(js), f.Close()
    JsxWrite("runfile:" call)
    return { id: id, deadline: now + startMs, runUntil: now + startMs + runMs, call: call,
             result: gJsxlDir "\" id ".result.json", started: gJsxlDir "\" id ".started" }
}

; 結果ファイル（包みの ser() の出力。キーは "…":、文字列のエスケープは \" \\ \uXXXX だけ）から値を取り出す
JsxlUnescape(s) {
    out := "", pos := 1
    while (p := RegExMatch(s, "\\(u[0-9a-fA-F]{4}|.)", &m, pos)) {
        e := m[1]
        out .= SubStr(s, pos, p - pos) ((StrLen(e) = 5) ? Chr("0x" SubStr(e, 2)) : e)
        pos := p + m.Len
    }
    return out SubStr(s, pos)
}
JsxlGetStr(json, key) {
    return RegExMatch(json, '"' key '":"((?:[^"\\]|\\.)*)"', &m) ? JsxlUnescape(m[1]) : ""
}
JsxlGetNum(json, key) {
    return RegExMatch(json, '"' key '":(-?[0-9.]+)', &m) ? Number(m[1]) : ""
}
JsxlGetBool(json, key) {
    return RegExMatch(json, '"' key '":(true|false)', &m) ? (m[1] = "true") : ""
}
; 文字列の配列（"key":["a","b"]）
JsxlGetStrArr(json, key) {
    list := []
    if !(p := InStr(json, '"' key '":['))
        return list
    pos := p + StrLen(key) + 4
    while RegExMatch(json, '\G\s*,?\s*"((?:[^"\\]|\\.)*)"', &m, pos) {
        list.Push(JsxlUnescape(m[1]))
        pos := m.Pos + m.Len
    }
    return list
}

; ---- トラック名の変更 ----

PrRenameStart() {
    global _prRn, gPrScriptsDir
    PrRenameClose(false)
    ; クリップ選択中は jsx が prompt を出して人が打つので、待つ上限は長めに（10分）
    _prRn := JsxlCall(gPrScriptsDir "ExtendScript\リネーム.jsx", "{args:{op:" JsxlStr("list") "}}", 3000, 600000)
    _prRn.phase := "list"
    SetTimer(PrRenamePoll, 20)
}

; 結果ファイルを待つ。始まらないまま期限を過ぎたら知らせる。
; 始まった後は待ち続ける（クリップ選択中は jsx が prompt を出していて、人が打っている）
PrRenamePoll() {
    global _prRn
    if !IsObject(_prRn) {
        SetTimer(PrRenamePoll, 0)
        return
    }
    rn := _prRn
    if FileExist(rn.result) {
        SetTimer(PrRenamePoll, 0)
        json := ""
        try json := FileRead(rn.result, "UTF-8")
        PrRenameDone(rn, json)
        return
    }
    now := JsxlNowMs()
    if (!FileExist(rn.started) && now > rn.deadline + 500) {
        SetTimer(PrRenamePoll, 0)
        PrRenameWithdraw(rn)
        _prRn := ""
        MyTooltip("Premiere が受け付けませんでした`nJsxLauncher パネルが開いているか、Premiere がダイアログを出していないか確認してください", 3000)
        return
    }
    if (now > rn.runUntil) {
        SetTimer(PrRenamePoll, 0)
        _prRn := ""
        try FileDelete(rn.call)         ; 結果は後から書かれることがあるので、call だけ消す
        return
    }
    if (FileExist(rn.started))
        SetTimer(PrRenamePoll, 200)     ; 人が prompt に打っている間は間隔を空ける
}

; 自分のコマンドがまだ拾われていなければ取り下げる（後でパネルを開いたときに走らないように。走っても期限切れで本体は実行しない）
PrRenameWithdraw(rn) {
    global gJsxCmd
    try {
        if (Trim(FileRead(gJsxCmd, "UTF-8")) = "runfile:" rn.call)
            FileDelete(gJsxCmd)
    }
    try FileDelete(rn.call)             ; 後で拾われても call が無ければ何も起きない
}

; 包み（jsxl_wrap.jsx）が書く英語のエラーを言い換える
PrRenameErrText(err) {
    static texts := Map(
        "expired", "Premiere が 3 秒以内に始められませんでした（レンダリング中・自動保存中・ダイアログ表示中など）",
        "sequence mismatch", "一覧を読んだ後にシーケンスが切り替わったので、変えていません",
        "busy (another wrapper is running)", "Premiere で別のスクリプトが動いていました",
        "cancelled", "取り下げました",
        "target not found", "リネーム.jsx が見つかりません（W: ドライブを確認してください）")
    return texts.Has(err) ? texts[err] : err
}

PrRenameDone(rn, json) {
    global _prRn
    _prRn := ""
    err := JsxlGetStr(json, "error")
    if (json = "" || err != "" || JsxlGetBool(json, "ok") != true) {
        MyTooltip("トラック名の変更: " (err != "" ? PrRenameErrText(err) : "失敗しました"), 4000)
        return
    }
    if (rn.phase = "list") {
        if (JsxlGetStr(json, "rnMode") = "tracks")
            PrRenameShow(json)
        PrRenameCleanup(rn)             ; "clips" は jsx が prompt で済ませている
        return
    }
    PrRenameCleanup(rn)                 ; apply の成功は jsx の通知（イベントパネル）に任せる
}

PrRenameCleanup(rn) {
    for p in [rn.call, rn.result, rn.started]
        try FileDelete(p)
}

PrRenameShow(json) {
    global _prRnGui, _prRnEdits, _prRnList, exe_pr
    lst := { seq: JsxlGetStr(json, "rnSeq"), nv: JsxlGetNum(json, "rnNv"), na: JsxlGetNum(json, "rnNa"),
             v: JsxlGetStrArr(json, "rnV"), a: JsxlGetStrArr(json, "rnA"),
             dv: JsxlGetStrArr(json, "rnDefV"), da: JsxlGetStrArr(json, "rnDefA") }
    if (lst.seq = "" || lst.v.Length != lst.nv || lst.a.Length != lst.na) {
        MyTooltip("トラック名の変更: 一覧を読み取れませんでした", 3000)
        return
    }
    if (lst.nv + lst.na > 30) {         ; 画面に収まらないので、今までのテキストファイル方式に任せる
        JsxRun("リネーム.jsx")
        return
    }
    _prRnList := lst, _prRnEdits := []
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox +ToolWindow", "トラック名の変更")
    g.MarginX := 10, g.MarginY := 8
    g.SetFont("s10")
    ; 1行＝ラベル＋入力欄。V は上（番号の大きい方）から、A は A1 から（タイムラインの見た目の順）
    addRow(label, value, cue) {
        g.Add("Text", "xm w44 Section", label)
        e := g.Add("Edit", "ys-3 w260 r1", value)
        SendMessage(0x1501, 1, StrPtr(cue), e)     ; EM_SETCUEBANNER：空欄に既定名を灰色で出す
        _prRnEdits.Push(e)
    }
    Loop lst.nv
        addRow("V" (lst.nv - A_Index + 1), lst.v[A_Index], lst.dv[A_Index])
    g.Add("Text", "xm w304 h1 0x10")                    ; 区切り線（SS_ETCHEDHORZ）
    Loop lst.na
        addRow("A" A_Index, lst.a[A_Index], lst.da[A_Index])
    g.SetFont("s8 c808080")
    g.Add("Text", "xm", "Ctrl+Enter / Enter：適用　Esc：取消　空欄＝変えない")
    g.OnEvent("Escape", (*) => PrRenameClose(true))
    g.OnEvent("Close", (*) => PrRenameClose(true))
    _prRnGui := g
    if (hwnd := WinExist(exe_pr)) {
        g.Show("Hide AutoSize")
        g.GetPos(, , &gw, &gh)
        WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        g.Show(Format("x{} y{}", wx + (ww - gw) // 2, wy + (wh - gh) // 3))
    } else {
        g.Show("AutoSize Center")
    }
    if (_prRnEdits.Length)
        _prRnEdits[1].Focus()
}

PrRenameGuiActive(*) {
    global _prRnGui
    return (IsObject(_prRnGui) && WinActive("ahk_id " _prRnGui.Hwnd)) ? true : false
}

; 閉じてフォーカスを Premiere へ返す
PrRenameClose(activate) {
    global _prRnGui, exe_pr
    if IsObject(_prRnGui) {
        _prRnGui.Destroy()
        _prRnGui := ""
    }
    if activate
        WinActivate(exe_pr)
}

PrRenameConfirm(*) {
    global _prRnGui, _prRnEdits, _prRnList, _prRn, gPrScriptsDir, exe_pr
    if !IsObject(_prRnGui)
        return
    ; 日本語の変換中なら、先に確定させてから読む
    try {
        fh := ControlGetFocus(_prRnGui)
        if (fh && IsImeComposing(fh)) {
            Send("{Enter}")
            t0 := A_TickCount
            while (IsImeComposing(fh) && A_TickCount - t0 < 500)
                Sleep(10)
        }
    }
    lst := _prRnList, v := [], a := [], changed := false
    for i, e in _prRnEdits {
        val := e.Value
        if (i <= lst.nv) {
            v.Push(val == lst.v[i] ? "" : val)
            changed := changed || (val != "" && val !== lst.v[i])
        } else {
            k := i - lst.nv
            a.Push(val == lst.a[k] ? "" : val)
            changed := changed || (val != "" && val !== lst.a[k])
        }
    }
    PrRenameClose(true)
    if !changed
        return                          ; 何も変えていなければ流さない
    WinWaitActive(exe_pr, , 0.5)
    input := "{expectSequenceId:" JsxlStr(lst.seq) ",args:{op:" JsxlStr("apply") ",nv:" lst.nv ",na:" lst.na
        . ",oldV:" JsxlArr(lst.v) ",oldA:" JsxlArr(lst.a) ",video:" JsxlArr(v) ",audio:" JsxlArr(a) "}}"
    _prRn := JsxlCall(gPrScriptsDir "ExtendScript\リネーム.jsx", input)
    _prRn.phase := "apply"
    SetTimer(PrRenamePoll, 20)
}

; Enter は変換中なら IME に譲る（変換の確定を奪わない）
PrRenameEnter(key, *) {
    global _prRnGui
    try {
        fh := ControlGetFocus(_prRnGui)
        if (fh && IsImeComposing(fh)) {
            Send("{" key "}")
            return
        }
    }
    PrRenameConfirm()
}

; Gui がアクティブなときだけ拾う。「~」を付けないのは、二重常駐したときに両方で発火させないため
HotIf PrRenameGuiActive
Hotkey "^Enter", PrRenameConfirm
Hotkey "Enter", PrRenameEnter.Bind("Enter")
Hotkey "NumpadEnter", PrRenameEnter.Bind("NumpadEnter")
HotIf
