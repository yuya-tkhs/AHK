;;
;; Illustrator
;;;;
; jsxを別AHKプロセスで非同期起動する。
; DoJavaScriptFileのブロックを子プロセスに肩代わりさせ、本体をフリーズさせない。
global _aiChildPid := 0
global _aiChildName := ""           ; 実行中のjsx名（警告表示に使う）

; 実行中のJSXがあるか。多重起動ガードの判定をここ1か所にまとめる。
IsAiScriptRunning() {
    global _aiChildPid
    return (_aiChildPid && ProcessExist(_aiChildPid)) ? true : false
}

; 多重起動ガードに掛かったことを知らせる。
; 黙って起動しないと「押したのに何も起きない」ようにしか見えず、
; JSXが動いているせいだと分からないため。
WarnAiScriptBusy(name) {
    global _aiChildName
    MyTooltip("JSXの実行中です`n実行中　: " _aiChildName "`n起動不可: " name, 2500)
}

; name: 実行するjsxファイル名
; imeDialogTitle: 指定するとそのダイアログが開いている間だけ日本語入力をON（閉じたらOFF）
; 子プロセスの起動と多重起動ガードの共通部分。
; displayName は警告表示に使う名前。戻り値は子PID（ガードで起動しなければ0）。
LaunchAiChild(childArgs, displayName) {
    global _aiChildPid, _aiChildName
    if IsAiScriptRunning() {
        WarnAiScriptBusy(displayName)
        return 0                    ; 起動しなかったことを呼び出し元に伝える
    }
    _aiChildName := displayName
    childPath := A_ScriptDir "\lib\run_ai_script.ahk"
    Run('"' A_AhkPath '" "' childPath '" ' childArgs, , "Hide", &_aiChildPid)
    return _aiChildPid
}

; Illustratorのメニューコマンドを実行する（整列など）。
; これらはJSXファイルが存在しないメニュー項目なので、共有ドライブにファイルを
; 作らず DoJavaScript で直接叩く。コマンド名はIllustratorのメニューコマンド名。
; JS側の引用符はシングルにする（コマンドラインの二重引用符と衝突させないため）。
RunAiMenuCommand(command, displayName) {
    js := "app.executeMenuCommand('" command "')"
    return LaunchAiChild('--code "' js '"', displayName)
}

RunAiScriptAsync(name, imeDialogTitle := "") {
    global _aiChildPid
    base := "W:\共有ドライブ\wc動画\sync\Assets\adobe-scripts_tkhs\illustrator\"
    if !LaunchAiChild('"' base name '"', name)
        return 0
    ; IME連動（WinWait/WinWaitCloseは割り込み可能なので本体は止まらない）
    if (imeDialogTitle != "") {
        if WinWait(imeDialogTitle, , 5) {
            Sleep(80)               ; ダイアログがフォーカスを得るのを待つ
            Send("{vk1C}")          ; 日本語入力ON
            WinWaitClose(imeDialogTitle)
            Send("{vk1D}")          ; 半角英数OFF
        }
    }
    return _aiChildPid
}

; JSXの完了通知を、ダイアログではなく一時ファイル経由で受け取ってツールチップに出す。
; JSX側は結果を .tmp に書いてから ai_jsx_result.txt にリネームするので、
; 書きかけを読むことはない。こちらはその出現をポーリングして待つ。
; ダイアログを出さないので「早めに押したEnterが消える」問題自体が起きなくなる。
global _aiResultFile := A_Temp "\ai_jsx_result.txt"
global _aiResultPid := 0
global _aiResultDeadline := 0
global _aiResultGrace := 0
RunAiScriptWithTooltip(name, timeoutMs := 600000) {
    global _aiResultFile, _aiResultPid, _aiResultDeadline, _aiResultGrace
    ; ガードに掛かるときは結果ファイルに触らずに抜ける。
    ; 先に消してしまうと、実行中のJSXが書き終えた結果を横から削除してしまい、
    ; 監視中のポーリングが拾えなくなる（rename直後〜読み取りまでの隙間で起きる）。
    if IsAiScriptRunning() {
        WarnAiScriptBusy(name)
        return
    }
    try FileDelete(_aiResultFile)       ; 前回の残骸を消してから起動する
    pid := RunAiScriptAsync(name)
    ; Run は失敗すると例外を投げるので、0が返るのは割り込みで内側のガードに
    ; 掛かった場合だけ。その場合は警告済みなので黙って抜ける。
    if (!pid)
        return
    _aiResultPid := pid
    _aiResultDeadline := A_TickCount + timeoutMs
    _aiResultGrace := 0
    SetTimer(AiResultPoll, 200)
}
AiResultPoll() {
    global _aiResultFile, _aiResultPid, _aiResultDeadline, _aiResultGrace
    if FileExist(_aiResultFile) {
        SetTimer(AiResultPoll, 0)
        try {
            body := FileRead(_aiResultFile, "UTF-8")
            FileDelete(_aiResultFile)
            MyTooltip(StrReplace(body, "`r`n", "`n"), 2500)
        }
        return
    }
    ; 子プロセスが消えたのに結果が無い＝キャンセルかエラー。静かに監視をやめる。
    ; JSXはDoJavaScriptFileが返る前に書き終えるので、消えた後に出てくることはないが、
    ; 取りこぼしを避けるため猶予を2回（400ms）置いてから止める。
    if !ProcessExist(_aiResultPid) {
        if (++_aiResultGrace >= 2)
            SetTimer(AiResultPoll, 0)
        return
    }
    if (A_TickCount > _aiResultDeadline)
        SetTimer(AiResultPoll, 0)
}

#HotIf WinActive(exe_ai)

; Alt+Enter → MultiEditText.jsx 起動（非同期・表示中は日本語入力ON）
!Enter:: RunAiScriptAsync("MultiEditText.jsx", "Multi-edit Text")

; 次／前のアートボードを表示して中身を全選択する
+PgDn:: RunAiScriptAsync("display_next_artboard_and_select_all.jsx")
+PgUp:: RunAiScriptAsync("display_prev_artboard_and_select_all.jsx")

; MultiEditTextダイアログ表示中のみ Ctrl+Enter を上書き。
; 画像でOKボタンを探してクリックし、カーソルを元の位置へ戻す。
#HotIf WinActive("Multi-edit Text")
^Enter:: ClickImageAndReturn(A_ScriptDir "\images\ai_OK.png", "OKボタンが見つかりません", 150)

; テキストプロパティ設定ダイアログ表示中のみ Ctrl+Enter を上書き（OK画像クリック＋カーソル復帰）
#HotIf WinActive("テキストプロパティ設定")
^Enter:: ClickImageAndReturn(A_ScriptDir "\images\ai_OK.png", "OKボタンが見つかりません", 150)

; 位置・サイズダイアログ表示中のみ Ctrl+Enter を上書き（OK画像クリック＋カーソル復帰）
#HotIf WinActive("位置・サイズ")
^Enter:: ClickImageAndReturn(A_ScriptDir "\images\ai_OK.png", "OKボタンが見つかりません", 150)

#HotIf WinActive(exe_ai)

; 2ストロークのメニュー定義。
; ツールチップの文言とキーの分岐を両方ここから生成するので、
; 追加・変更はこの配列だけを直せばよい（以前は表示と switch の二重管理だった）。
; f と 2 も同期のAiScriptから寄せてある。同期だとJSXが終わるまで本体が固まり、
; その間ほかのホットキーが全部効かなくなるため。
; e / E は大文字小文字で別コマンド。照合は「==」で行う（「=」は区別しない）。
; グループの key は第2打鍵でサブメニューへ降りるためのもの。
; direct: true の項目は第2打鍵だけでも起動できる（第1階層のメニューにも並ぶ）。
; アートボード系は全て b 経由。書き出しとオブジェクトは直接キーも残してある。
; 今後増やすものは原則サブメニュー側へ足し、頻用になったら direct を付けて昇格させる。
; disp は表示用（矢印キーは "Left" ではなく "←" と出す）。
; 矢印のような複数文字のキーは InputHook の EndKey に自動で加えられる。
; 実行内容は jsx（ファイル名）か menucmd（Illustratorのメニューコマンド）で持つ。
; 関数を Bind したものを直接持たせると実行はできても中身を取り出せず、
; ランチャーにファイル名を出せないため、定義側に素の値で置く。
; tooltip: true の項目だけ完了通知を結果ファイル経由で受け取る。
global AiMenu := [
    { key: "b", label: "アートボード", items: [
        { key: "f", label: "移動",               jsx: "go_to_artboard.jsx" },
        { key: "a", label: "追加",               jsx: "add_new_artboard.jsx" },
        { key: "s", label: "中身を後ろへずらす", jsx: "shift_artboard_contents.jsx" },
        { key: "m", label: "枠を作成",           jsx: "create_artboard_shape.jsx" },
        { key: "2", label: "名前を変更",         jsx: "rename_active_artboard.jsx" } ] },
    { key: "x", label: "書き出し", items: [
        { key: "e", label: "PNG（10倍）", direct: true, tooltip: true, jsx: "render_active_artboard_10x.jsx" },
        { key: "E", label: "PNG（等倍）", direct: true, tooltip: true, jsx: "render_active_artboard.jsx" } ] },
    { key: "o", label: "オブジェクト", items: [
        { key: "t", label: "テキストプロパティエディタ", direct: true, jsx: "text_property_editor.jsx" },
        { key: "g", label: "位置・サイズ", direct: true, jsx: "xywh_input.jsx" } ] },
    ; 整列はIllustratorのメニューコマンド（JSXは存在しない）
    { key: "a", label: "整列", items: [
        { key: "Left",  disp: "←", label: "左に整列", menucmd: "Horizontal Align Left" },
        { key: "Right", disp: "→", label: "右に整列", menucmd: "Horizontal Align Right" },
        { key: "Up",    disp: "↑", label: "上に整列", menucmd: "Vertical Align Top" },
        { key: "Down",  disp: "↓", label: "下に整列", menucmd: "Vertical Align Bottom" },
        { key: "c", label: "水平方向中央に整列", menucmd: "Horizontal Align Center" },
        { key: "m", label: "垂直方向中央に整列", menucmd: "Vertical Align Center" } ] },
    ; 文字揃えは sttk3 製のJSX。よく使う3つだけ第3打鍵に載せる（残りはランチャーから）
    { key: "j", label: "文字揃え", items: [
        { key: "Left",  disp: "←", label: "左揃え",   jsx: "sttk3-changeJustification\justification=left.jsx" },
        { key: "Right", disp: "→", label: "右揃え",   jsx: "sttk3-changeJustification\justification=right.jsx" },
        { key: "Up",    disp: "↑", label: "中央揃え", jsx: "sttk3-changeJustification\justification=center.jsx" } ] }
]

; 項目の実行内容を組み立てる（定義から都度作るので二重管理にならない）
AiItemAction(item) {
    if item.HasOwnProp("menucmd")
        return RunAiMenuCommand.Bind(item.menucmd, item.label)
    if (item.HasOwnProp("tooltip") && item.tooltip)
        return RunAiScriptWithTooltip.Bind(item.jsx)
    return RunAiScriptAsync.Bind(item.jsx)
}

; ランチャーに出す名前。ファイル名（またはメニューコマンド名）をそのまま使う。
; 半角のまま検索できて識別しやすいため、日本語ラベルより優先する。
AiItemName(item) {
    return item.HasOwnProp("menucmd") ? item.menucmd : item.jsx
}

; 項目の表示用キー（矢印は disp に "←" などを持たせてある）
AiItemDisp(item) {
    return item.HasOwnProp("disp") ? item.disp : item.key
}
AiItemIsDirect(item) {
    return item.HasOwnProp("direct") && item.direct
}

; 第1階層のツールチップ。グループ見出しに降り先のキーを併記し、
; 直接起動できる項目だけを並べる（サブメニュー限定の項目は出さない）。
BuildAiMenuText(title) {
    global AiMenu
    text := title
    for group in AiMenu {
        text .= "`n- - - - - - - - - - - - - - - -`n" group.label " [" group.key "]"
        for item in group.items
            if AiItemIsDirect(item)
                text .= "`n" AiItemDisp(item) ": " item.label
    }
    return text
}

; 第2階層（サブメニュー）のツールチップ。1行目をパンくずにする
BuildAiSubMenuText(group) {
    text := "2ストローク > " group.label "（5秒）"
    text .= "`n- - - - - - - - - - - - - - - -"
    for item in group.items
        text .= "`n" AiItemDisp(item) ": " item.label
    return text "`n- - - - - - - - - - - - - - - -`nBS: 戻る / Esc: キャンセル"
}

; 第1階層の末尾に出す案内。Space は EndKey に入っているだけで未割当だったので
; ランチャーの入口に使っている（既存キーと衝突しない）。
AiMenuFooter() {
    return "`n- - - - - - - - - - - - - - - -`nSpace: ランチャー（一覧から選ぶ）"
}

; InputHookのEndKey指定を組み立てる。
; 矢印のような文字にならないキーはEndKeyにしないと拾えないため、
; そのグループの項目から自動で拾う（1文字のキーは通常の文字入力で取れる）。
BuildAiEndKeys(group, allowBack) {
    keys := allowBack ? "{Escape}{Space}{Backspace}" : "{Escape}{Space}"
    if (group)
        for item in group.items
            if (StrLen(item.key) > 1)
                keys .= "{" item.key "}"
    return keys
}

; 押されたキーに対応する項目を返す（無ければ ""）。
; group を渡すとそのグループ内だけを探す。
; group 省略時＝第1階層なので、direct の項目だけを対象にする。
FindAiMenuItem(key, group := "") {
    global AiMenu
    for g in (group ? [group] : AiMenu)
        for item in g.items {
            if (!group && !AiItemIsDirect(item))
                continue
            if (item.key == key)    ; == で大文字小文字を区別（e と E を分ける）
                return item
        }
    return ""
}

; 押されたキーに対応するグループを返す（無ければ ""）
FindAiGroup(key) {
    global AiMenu
    for group in AiMenu
        if (group.key == key)
            return group
    return ""
}

; メニューを出してキーを1つ読む。Escapeとタイムアウトは "" を返す。
; 「戻る」を許すと Backspace をそのまま返す。
; フックはツールチップを描く「前」に張る。Wait()が返ってから次のStartまでの
; 隙間に押されたキーはIllustratorへ素通りし、単キーがツール切替に化けるため。
ReadAiMenuKey(menuText, allowBack := false, group := "", timeoutSec := 5) {
    ih := InputHook("L1 T" timeoutSec)
    ih.KeyOpt(BuildAiEndKeys(group, allowBack), "E")
    ih.Start()
    MyTooltip(menuText, timeoutSec * 1000)
    ih.Wait()
    MyTooltip()
    if (ih.EndReason = "Timeout")
        return ""
    key := (ih.EndReason = "EndKey") ? ih.EndKey : ih.Input
    return (key = "Escape") ? "" : key
}

; 選んだ項目を実行する。該当が無ければ知らせるだけ。
RunAiMenuItem(key, group := "") {
    if (item := FindAiMenuItem(key, group))
        AiItemAction(item).Call()
    else
        MyTooltip("無効なキーです", 500)
}

; 2ストローク（0.3秒以内の短押しのみ起動・長押しはIllustratorにそのまま渡す）
$~^Space:: {
    static inLongPress := false
    if inLongPress  ; キーリピート中 → スキップ
        return
    KeyWait("Space", "T0.3")
    if GetKeyState("Space", "P") {  ; まだ押されている = 長押し確定
        inLongPress := true
        KeyWait("Space")            ; 離されるまで待機してフラグをリセット
        inLongPress := false
        return
    }
    ; Common.ahk と違い、ここでは選択キーが離されるのを待たない。
    ; どの項目も Send を使わず JSX を起動するだけなので「Sendと物理キーの衝突」を
    ; 避ける必要がなく、待つとキーを離すまでJSXの起動が始まらない＝ダイアログが
    ; 出るのがその分遅れるため。
    ; （KeyWaitはAHKのスレッドを止めるだけでキーを抑制しないので、外しても取りこぼしは増えない）
    loop {
        key := ReadAiMenuKey(BuildAiMenuText("2ストローク待機中（5秒）") AiMenuFooter())
        if (key = "")               ; Escape かタイムアウト
            return
        if (key = "Space") {        ; 一覧から選ぶランチャーを開く
            ShowAiLauncher()
            return
        }
        ; グループキーならサブメニューへ降りる
        if (group := FindAiGroup(key)) {
            subKey := ReadAiMenuKey(BuildAiSubMenuText(group), true, group)
            if (subKey = "")
                return
            if (subKey = "Backspace")
                continue             ; 第1階層へ戻る
            RunAiMenuItem(subKey, group)
            return
        }
        RunAiMenuItem(key)           ; 従来どおりの2打鍵
        return
    }
}

#HotIf