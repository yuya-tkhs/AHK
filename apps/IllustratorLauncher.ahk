;;
;; Illustrator JSXランチャー
;;;;
; 2ストローク（Ctrl+Space）から Space で開く。
; 文字入力で絞り込み、上下で選択、Enterで実行、Escapeでキャンセル、F5で再列挙。
;
; ScriptUI（JSX）ではなくAHKのGUIで作っている理由：
; ScriptUI製のランチャーは自身がJSXなので多重起動ガード（IsAiScriptRunning）を
; 占有し続け、パネルを開いている間そこから何も起動できなくなる。
; 加えてモーダル表示中はIllustrator本体がブロックされる。
;
; AHKのGUIはIllustratorからフォーカスを奪うが、実行・キャンセルの直前に必ず
; Hide() → WinActivate(exe_ai) を通す。JSXのダイアログはIllustratorが出すので、
; 戻してから起動すれば3ストロークで起動したときと同じ条件になる。
; 逆に、パネル表示中の打鍵は全てGUIに入るため、3ストロークで問題になった
; 「素通りしたキーがIllustratorのツール切替に化ける」ことが起きない。

global _aiLauncherGui := ""
global _aiLauncherLV := ""
global _aiLauncherEdit := ""
global _aiLauncherItems := []       ; いま一覧に出ている項目（絞り込み後）
global _aiLauncherAll := ""         ; 全項目のキャッシュ（F5で作り直す）

; 一覧に出さないフォルダ（相対パスの前方一致）
global _aiLauncherExclude := ["test\"]
; 検索したときだけ出すフォルダ。既定の一覧を短く保ちつつ、
; 名前を覚えていれば呼べる状態にしておくため。
global _aiLauncherSearchOnly := ["あまり使わない\"]

; 最近使ったもの（新しい順）。リロードやPC再起動をまたいで残す。
; 置き場は A_AppData。リポジトリにもGoogleドライブにも置かないのは、
; 使用履歴を版管理・同期の対象にしたくないため。
global _aiMruFile := A_AppData "\AhkJsxLauncher\mru.txt"
global _aiMruMax := 20
global _aiMru := ""

AiMru() {
    global _aiMru
    if !IsObject(_aiMru)
        LoadAiMru()
    return _aiMru
}

LoadAiMru() {
    global _aiMru, _aiMruFile
    _aiMru := []
    try {
        for line in StrSplit(FileRead(_aiMruFile, "UTF-8"), "`n", "`r")
            if (line != "")
                _aiMru.Push(line)
    }
    return _aiMru
}

; 実行したものを先頭へ持ってくる（既にあれば取り除いてから入れ直す）
RecordAiMru(name) {
    global _aiMru, _aiMruFile, _aiMruMax
    mru := AiMru()
    for i, v in mru
        if (v = name) {
            mru.RemoveAt(i)
            break
        }
    mru.InsertAt(1, name)
    while (mru.Length > _aiMruMax)
        mru.Pop()
    text := ""
    for v in mru
        text .= v "`n"
    try {
        DirCreate(RegExReplace(_aiMruFile, "\\[^\\]+$"))
        if FileExist(_aiMruFile)
            FileDelete(_aiMruFile)
        FileAppend(text, _aiMruFile, "UTF-8")
    }
}

; 最近使ったものを先頭に、残りは元の並びのまま返す。
; 絞り込みの前にかけるので、検索したときも「最近使ったもの」が上に来る。
SortByAiMru(items) {
    mru := AiMru()
    if (!mru.Length)
        return items
    byName := Map()
    byName.CaseSense := false
    for item in items
        if !byName.Has(item.name)
            byName[item.name] := item
    out := [], used := Map()
    used.CaseSense := false
    for name in mru
        if (byName.Has(name) && !used.Has(name)) {
            out.Push(byName[name])
            used[name] := true
        }
    for item in items
        if !used.Has(item.name)
            out.Push(item)
    return out
}

AiLauncherBase() {
    return "W:\共有ドライブ\wc動画\sync\Assets\adobe-scripts_tkhs\illustrator\"
}

AiLauncherMatchesFolder(rel, prefixes) {
    for prefix in prefixes
        if (SubStr(rel, 1, StrLen(prefix)) = prefix)    ; = は大文字小文字を区別しない
            return true
    return false
}
AiLauncherExcluded(rel) {
    global _aiLauncherExclude
    return AiLauncherMatchesFolder(rel, _aiLauncherExclude)
}
AiLauncherSearchOnly(rel) {
    global _aiLauncherSearchOnly
    return AiLauncherMatchesFolder(rel, _aiLauncherSearchOnly)
}

; 一覧を作る。
; 先に AiMenu と AiDirectKeys（日本語ラベル・メニューコマンドを持つ手書き定義）を
; 並べ、続いてフォルダを再帰列挙して、そこに出てこないJSXだけを足す。
; AiDirectKeys も混ぜるのは、整列のメニューコマンドに対応するJSXファイルが無く、
; 拾い漏らすとランチャーから消えてしまうため。
; 1列目はファイル名。半角のまま検索でき、ラベルを持たない列挙分とも表記が揃うため。
BuildAiLauncherItems() {
    global AiMenu, AiDirectKeys
    items := []
    seen := Map()
    seen.CaseSense := false         ; Windowsのパスは大文字小文字を区別しない
    for def in [AiMenu, AiDirectKeys]   ; menu は組み込みクラス名なので避ける
        for group in def
            for item in group.items {
                items.Push({ name: AiItemName(item), label: item.label
                           , group: group.label, action: AiItemAction(item) })
                if item.HasOwnProp("jsx")
                    seen[item.jsx] := true
            }
    base := AiLauncherBase()
    Loop Files base "*.jsx", "R" {
        rel := SubStr(A_LoopFileFullPath, StrLen(base) + 1)
        if (AiLauncherExcluded(rel) || seen.Has(rel))
            continue
        seen[rel] := true
        searchOnly := AiLauncherSearchOnly(rel)
        items.Push({ name: rel, label: "", group: searchOnly ? "あまり使わない" : "その他"
                   , searchOnly: searchOnly, action: RunAiScriptAsync.Bind(rel) })
    }
    return items
}

; 全項目（キャッシュ付き）。Googleドライブ上の再帰列挙を毎回やらないため。
AiLauncherAllItems(refresh := false) {
    global _aiLauncherAll
    if (refresh || !IsObject(_aiLauncherAll))
        _aiLauncherAll := BuildAiLauncherItems()
    return _aiLauncherAll
}

; 空白区切りのAND検索。ファイル名・説明・分類のどれかに含まれれば残す。
; InStr は既定で大文字小文字を区別しないので、半角でそのまま打てる。
; 検索欄が空のときは searchOnly の項目（あまり使わないフォルダ）を伏せる。
FilterAiLauncherItems(items, query) {
    query := Trim(query)
    out := []
    for item in items {
        if (query = "") {
            if !(item.HasOwnProp("searchOnly") && item.searchOnly)
                out.Push(item)
            continue
        }
        hay := item.name " " item.label " " item.group
        ok := true
        for term in StrSplit(query, " ") {
            if (term != "" && !InStr(hay, term)) {
                ok := false
                break
            }
        }
        if ok
            out.Push(item)
    }
    return out
}

; ランチャーがアクティブか（Enterや上下を拾う条件）
AiLauncherActive(*) {
    global _aiLauncherGui
    return (_aiLauncherGui && WinActive("ahk_id " _aiLauncherGui.Hwnd)) ? true : false
}

CreateAiLauncher() {
    global _aiLauncherGui, _aiLauncherLV, _aiLauncherEdit
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox +ToolWindow", "JSXランチャー")
    g.MarginX := 8, g.MarginY := 8
    g.SetFont("s10")
    ed := g.Add("Edit", "w620")
    ed.OnEvent("Change", (*) => RefreshAiLauncherList())
    lv := g.Add("ListView", "w620 r16 -Multi NoSortHdr", ["ファイル名", "説明", "分類"])
    lv.OnEvent("DoubleClick", (*) => RunSelectedAiLauncherItem())
    ; LVS_EX_DOUBLEBUFFER。絞り込みのたびに全行を入れ替えるのでちらつきを抑える
    try SendMessage(0x1036, 0x10000, 0x10000, lv)
    g.OnEvent("Escape", (*) => CloseAiLauncher())
    g.OnEvent("Close", (*) => CloseAiLauncher())
    _aiLauncherGui := g
    _aiLauncherLV := lv
    _aiLauncherEdit := ed
}

; 検索欄の内容で一覧を作り直す
RefreshAiLauncherList() {
    global _aiLauncherLV, _aiLauncherEdit, _aiLauncherItems
    _aiLauncherItems := FilterAiLauncherItems(SortByAiMru(AiLauncherAllItems()), _aiLauncherEdit.Value)
    lv := _aiLauncherLV
    lv.Opt("-Redraw")               ; 充填中のちらつきを抑える
    lv.Delete()
    for item in _aiLauncherItems
        lv.Add(, item.name, item.label, item.group)
    lv.Opt("+Redraw")
    if (_aiLauncherItems.Length)
        lv.Modify(1, "Select Focus Vis")
}

ShowAiLauncher() {
    global _aiLauncherGui, _aiLauncherLV, _aiLauncherEdit, exe_ai
    if (!_aiLauncherGui)
        CreateAiLauncher()
    _aiLauncherEdit.Value := ""     ; 前回の検索語は持ち越さない
    RefreshAiLauncherList()
    _aiLauncherLV.ModifyCol(1, 330)
    _aiLauncherLV.ModifyCol(2, 170)
    _aiLauncherLV.ModifyCol(3, 100)
    ; Illustratorの中央に出す
    if (hwnd := WinExist(exe_ai)) {
        WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        _aiLauncherGui.Show(Format("x{} y{} AutoSize", wx + (ww - 650) // 2, wy + (wh - 460) // 2))
    } else {
        _aiLauncherGui.Show("AutoSize Center")
    }
    _aiLauncherEdit.Focus()         ; そのまま絞り込みを打てるようにする
}

; 閉じてフォーカスをIllustratorへ返す（実行時・キャンセル時とも必ずここを通す）
CloseAiLauncher() {
    global _aiLauncherGui, exe_ai
    if (_aiLauncherGui)
        _aiLauncherGui.Hide()
    WinActivate(exe_ai)
}

; 検索欄にフォーカスがあるので、上下は自前で選択を動かす。端では巻き戻す。
MoveAiLauncherSel(delta) {
    global _aiLauncherLV
    if (!_aiLauncherLV)
        return
    count := _aiLauncherLV.GetCount()
    if (!count)
        return
    cur := _aiLauncherLV.GetNext(0, "F")
    if (!cur)
        cur := 1
    next := cur + delta
    if (next < 1)
        next := count
    else if (next > count)
        next := 1
    _aiLauncherLV.Modify(next, "Select Focus Vis")
}

RunSelectedAiLauncherItem() {
    global _aiLauncherLV, _aiLauncherItems, exe_ai
    if (!_aiLauncherLV)
        return
    row := _aiLauncherLV.GetNext(0, "F")    ; フォーカス行
    if (!row)
        row := _aiLauncherLV.GetNext()      ; 無ければ選択行
    if (!row || row > _aiLauncherItems.Length)
        return
    item := _aiLauncherItems[row]
    RecordAiMru(item.name)          ; 次に開いたとき先頭に出す
    CloseAiLauncher()
    ; アクティブ化が終わってから起動する。終わる前にJSXが走ると
    ; ダイアログがIllustratorの背面に出たりフォーカスを得られないため。
    WinWaitActive(exe_ai, , 0.5)
    item.action.Call()
}

; フォルダにJSXを足した直後などに一覧を作り直す
ReloadAiLauncherItems() {
    AiLauncherAllItems(true)
    RefreshAiLauncherList()
    MyTooltip("一覧を再構築しました（" AiLauncherAllItems().Length " 件）", 1500)
}

; Enter・上下・F5 はランチャーがアクティブなときだけ拾う。
; 検索欄にフォーカスがあるため、上下はここで横取りしないとListViewへ届かない。
; 「~」を付けないのは、二重常駐したときに両インスタンスで発火させないため。
HotIf AiLauncherActive
Hotkey "Up", (*) => MoveAiLauncherSel(-1)
Hotkey "Down", (*) => MoveAiLauncherSel(1)
Hotkey "Enter", (*) => RunSelectedAiLauncherItem()
Hotkey "NumpadEnter", (*) => RunSelectedAiLauncherItem()
Hotkey "F5", (*) => ReloadAiLauncherItems()
HotIf
