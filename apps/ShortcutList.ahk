;;
;; ショートカット一覧（グローバル2ストローク → k）
;;
;;   Escを押すまで開きっぱなしにする。ツールチップではなくGUIにしたのは、
;;   タイムアウトなしで出し続けるとツールチップが他の表示を邪魔し続けるうえ、
;;   2列に組めず縦に長くなりすぎるため。
;;
;;   2ストロークの中身は各ファイルのメニュー文字列（GlobalMenuText /
;;   ExplorerMenuText / PremiereMenuText）と AiMenu から組み立てる。
;;   ここに書き写すとメニューを直したときに一覧だけ古くなるため。
;;   単独ホットキーはコードから機械的に取り出せないのでこのファイルに書く。
;;
;;   アプリ固有の欄は「開いた時点でアクティブだったアプリ」のものだけ出す。
;;   GUIを出すとフォーカスが移るので、判定は必ず Show の前に済ませる。
;;;;

global _shortcutGui := ""
global _shortcutPrevWin := 0

; --- 表示 -----------------------------------------------------------------

ShowShortcutList() {
    global _shortcutGui, _shortcutPrevWin
    if (_shortcutGui) {             ; 開いているときはトグルで閉じる
        CloseShortcutList()
        return
    }
    _shortcutPrevWin := WinExist("A")   ; 閉じたときに戻す先
    app := ActiveShortcutApp()          ; フォーカスが移る前に判定する

    static KEY_W := 180, DESC_W := 300, GAP := 24, PAD := 16
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox +ToolWindow", "ショートカット一覧")
    g.BackColor := "FFFFFF"
    g.MarginX := 0, g.MarginY := 0

    left := [{ title: "共通", rows: CommonShortcutRows() }
           , { title: "グローバル2ストローク（無変換 + Space）", rows: MenuTextRows(GlobalMenuText()) }]
    right := AppShortcutSections(app)

    bottom := DrawShortcutColumn(g, left, PAD, KEY_W, DESC_W)
    width := PAD + KEY_W + DESC_W + PAD
    if (right.Length) {
        x2 := PAD + KEY_W + DESC_W + GAP
        bottom := Max(bottom, DrawShortcutColumn(g, right, x2, KEY_W, DESC_W))
        width := x2 + KEY_W + DESC_W + PAD
    }

    g.SetFont("s9 Norm", "Yu Gothic UI")
    g.Add("Text", Format("x{} y{} w{} c888888", PAD, bottom + 4, width - PAD * 2)
        , "Esc で閉じる" . (right.Length ? "" : "　（アプリ固有の欄はPremiere / Illustrator / エクスプローラーがアクティブなときに出ます）"))

    g.OnEvent("Escape", (*) => CloseShortcutList())
    g.OnEvent("Close", (*) => CloseShortcutList())
    _shortcutGui := g
    ShowShortcutGui(g, width, bottom + 40)
}

CloseShortcutList() {
    global _shortcutGui, _shortcutPrevWin
    if (!_shortcutGui)
        return
    _shortcutGui.Destroy()          ; 中身がアプリ次第で変わるので毎回作り直す
    _shortcutGui := ""
    if (_shortcutPrevWin && WinExist("ahk_id " _shortcutPrevWin))
        WinActivate("ahk_id " _shortcutPrevWin)
}

; 元のウィンドウの中央に出す。無ければ画面中央。
ShowShortcutGui(g, w, h) {
    global _shortcutPrevWin
    if (_shortcutPrevWin && WinExist("ahk_id " _shortcutPrevWin)) {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " _shortcutPrevWin)
        g.Show(Format("x{} y{} AutoSize", wx + (ww - w) // 2, Max(0, wy + (wh - h) // 2)))
        return
    }
    g.Show("AutoSize Center")
}

; 1列ぶんを描いて、次に置ける y を返す。
; キーと説明を別々の Text にするのは、フォント幅に依存せず桁を揃えるため。
DrawShortcutColumn(g, sections, x, keyW, descW) {
    y := 14
    for sec in sections {
        g.SetFont("s10 Bold", "Yu Gothic UI")
        g.Add("Text", Format("x{} y{} w{} c1A73E8", x, y, keyW + descW), sec.title)
        y += 26
        keys := "", descs := ""
        for row in sec.rows {
            keys .= (keys = "" ? "" : "`n") row[1]
            descs .= (descs = "" ? "" : "`n") row[2]
        }
        g.SetFont("s9 Bold", "Yu Gothic UI")
        kc := g.Add("Text", Format("x{} y{} w{} c333333", x, y, keyW), keys)
        g.SetFont("s9 Norm", "Yu Gothic UI")
        dc := g.Add("Text", Format("x{} y{} w{} c333333", x + keyW, y, descW), descs)
        ; 高さは実際のコントロールから取る（行数×決め打ちだと折り返しで崩れる）
        kc.GetPos(, , , &kh)
        dc.GetPos(, , , &dh)
        y += Max(kh, dh) + 22
    }
    return y
}

; --- 中身 -----------------------------------------------------------------

; 2ストロークのメニュー文字列を [キー, 説明] の配列にする。
; 見出しと区切り線は捨てる。
MenuTextRows(text) {
    rows := []
    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "-")
            continue
        if !(pos := InStr(line, ":"))
            continue                ; 「2ストローク待機中（5秒）」などの見出し
        key := Trim(SubStr(line, 1, pos - 1))
        desc := Trim(SubStr(line, pos + 1))
        if (key != "" && desc != "")
            rows.Push([key, desc])
    }
    return rows
}

; Illustratorの3ストロークは AiMenu から組み立てる。
; グループ見出しの下に第3打鍵をぶら下げる。
AiShortcutRows() {
    global AiMenu
    rows := []
    for group in AiMenu {
        rows.Push([group.key, group.label])
        for item in group.items
            rows.Push(["　└ " AiItemDisp(item), "　" item.label])
    }
    rows.Push(["Space", "JSXランチャー"])
    return rows
}

; 単独ホットキー。コードから取り出せないのでここで持つ。
CommonShortcutRows() {
    return [["無変換 + Space", "2ストローク（グローバル）"]
        , ["Ctrl + Space", "2ストローク（アプリ別）"]
        , ["無変換", "半角英数"]
        , ["無変換 + 左クリック", "ダブルクリック"]
        , ["無変換 + 変換", "日本語入力ON"]
        , ["無変換 + ↑↓←→", "その向きへ5回移動"]
        , ["無変換 + Enter", "行末で改行（Ctrl併用で1行上）"]
        , ["無変換 + BS", "行頭まで削除"]
        , ["無変換 + Del", "行末まで削除"]
        , ["Ctrl + Shift + BS", "行削除"]
        , ["Esc", "半角英数"]
        , ["Ctrl + Enter", "送信 + アプリ別の後処理"]
        , ["中ボタン ドラッグ", "スムーズスクロール"]
        , ["F19 / F20", "表示 縮小 / 拡大（Adobe系は ↓ / ↑）"]
        , ["F21 / F22", "取り消し・やり直し / タブ切り替え"]
        , ["F23 / F24", "加速スクロール 下 / 上"]
        , ["ddd / ttt", "今日の日付（MMDD） / tkhs"]]
}

; アクティブなアプリを判定する。GUIを出す前に呼ぶこと。
ActiveShortcutApp() {
    if WinActive(exe_pr)
        return "premiere"
    if WinActive(exe_ai)
        return "illustrator"
    if (WinActive(class_explorer) || IsFileDialog())
        return "explorer"
    return ""
}

AppShortcutSections(app) {
    switch app {
        case "premiere":
            return [{ title: "Premiere 2ストローク（Ctrl + Space）", rows: MenuTextRows(PremiereMenuText()) }
                  , { title: "Premiere 単独", rows: PremiereShortcutRows() }]
        case "illustrator":
            return [{ title: "Illustrator 2/3ストローク（Ctrl + Space 短押し）", rows: AiShortcutRows() }
                  , { title: "Illustrator 単独", rows: AiSoloShortcutRows() }]
        case "explorer":
            return [{ title: "エクスプローラー 2ストローク（Ctrl + Space）", rows: MenuTextRows(ExplorerMenuText()) }
                  , { title: "エクスプローラー 単独", rows: [["F21 / F22", "前 / 次のタブ"]] }]
    }
    return []
}

PremiereShortcutRows() {
    return [["Ctrl + 変換", "グラフィックステキストを編集"]
        , ["Shift+Ctrl+Alt+E", "全トラックに編集点を追加"]
        , ["Shift+Ctrl+Alt+Q", "編集点をリップルアウト + トリム"]
        , ["Shift+Ctrl+Alt+W", "編集点をリップルイン + トリム"]
        , ["Shift+Ctrl+Alt+A", "右クリックメニューの2番目"]
        , ["左クリック中 + e / E", "編集点を追加 / 全トラックに追加"]
        , ["左クリック中 + 2", "クリップ名の変更"]
        , ["左クリック中 + [ / ]", "ターゲット移動（Ctrl併用でオーディオ）"]
        , ["左クリック中 + - / :", "縮小 / 拡大"]
        , ["F19〜F22", "↓ / ↑ / Shift+Tab / Tab"]]
}

AiSoloShortcutRows() {
    return [["Alt + Enter", "MultiEditText（日本語入力ON）"]
        , ["Shift + PgDn / PgUp", "次 / 前のアートボードを表示して全選択"]
        , ["Ctrl + Enter", "ダイアログのOKをクリック"]
        , ["F19〜F22", "↓ / ↑ / Shift+Tab / Tab"]]
}
