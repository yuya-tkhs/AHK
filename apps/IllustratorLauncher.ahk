;;
;; Illustrator JSXランチャー
;;;;
; 2ストローク（無変換+Space）から Space で開く。
; 上下で選択、Enterで実行、Escapeでキャンセル。
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
global _aiLauncherItems := []

; AiMenu を平坦化して一覧用の配列にする。
; 1列目はファイル名（メニューコマンドはコマンド名）。半角のまま検索でき、
; フォルダ列挙で日本語ラベルを持たない項目が増えても表記が揃うため。
; 2列目に日本語ラベルを説明として出す。
BuildAiLauncherItems() {
    global AiMenu
    items := []
    for group in AiMenu
        for item in group.items
            items.Push({ name: AiItemName(item), label: item.label, group: group.label, action: AiItemAction(item) })
    return items
}

; ランチャーがアクティブか（Enterを拾う条件）
AiLauncherActive(*) {
    global _aiLauncherGui
    return (_aiLauncherGui && WinActive("ahk_id " _aiLauncherGui.Hwnd)) ? true : false
}

CreateAiLauncher() {
    global _aiLauncherGui, _aiLauncherLV
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox +ToolWindow", "JSXランチャー")
    g.MarginX := 8, g.MarginY := 8
    g.SetFont("s10")
    ; -Hdr で見出しを消す。上下キーはListViewが自前で処理するので、
    ; フォーカスさえ当てておけば移動用のホットキーは要らない。
    lv := g.Add("ListView", "w620 r16 -Multi NoSortHdr", ["ファイル名", "説明", "分類"])
    lv.OnEvent("DoubleClick", (*) => RunSelectedAiLauncherItem())
    g.OnEvent("Escape", (*) => CloseAiLauncher())
    g.OnEvent("Close", (*) => CloseAiLauncher())
    _aiLauncherGui := g
    _aiLauncherLV := lv
}

ShowAiLauncher() {
    global _aiLauncherGui, _aiLauncherLV, _aiLauncherItems, exe_ai
    if (!_aiLauncherGui)
        CreateAiLauncher()
    _aiLauncherItems := BuildAiLauncherItems()
    lv := _aiLauncherLV
    lv.Opt("-Redraw")                   ; 充填中のちらつきを抑える
    lv.Delete()
    for item in _aiLauncherItems
        lv.Add(, item.name, item.label, item.group)
    lv.Opt("+Redraw")
    lv.ModifyCol(1, 330)
    lv.ModifyCol(2, 170)
    lv.ModifyCol(3, 100)
    if (_aiLauncherItems.Length)
        lv.Modify(1, "Select Focus Vis")
    ; Illustratorの中央に出す
    if (hwnd := WinExist(exe_ai)) {
        WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        _aiLauncherGui.Show(Format("x{} y{} AutoSize", wx + (ww - 650) // 2, wy + (wh - 420) // 2))
    } else {
        _aiLauncherGui.Show("AutoSize Center")
    }
    lv.Focus()                          ; 上下キーが効くようにListViewへフォーカス
}

; 閉じてフォーカスをIllustratorへ返す（実行時・キャンセル時とも必ずここを通す）
CloseAiLauncher() {
    global _aiLauncherGui, exe_ai
    if (_aiLauncherGui)
        _aiLauncherGui.Hide()
    WinActivate(exe_ai)
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
    CloseAiLauncher()
    ; アクティブ化が終わってから起動する。終わる前にJSXが走ると
    ; ダイアログがIllustratorの背面に出たりフォーカスを得られないため。
    WinWaitActive(exe_ai, , 0.5)
    item.action.Call()
}

; Enter はランチャーがアクティブなときだけ拾う。
; 隠しデフォルトボタンで受ける手もあるが、Hidden時に反応するかが不確実なので使わない。
; 「~」を付けないのは、二重常駐したときに両インスタンスで発火させないため。
HotIf AiLauncherActive
Hotkey "Enter", (*) => RunSelectedAiLauncherItem()
Hotkey "NumpadEnter", (*) => RunSelectedAiLauncherItem()
HotIf
