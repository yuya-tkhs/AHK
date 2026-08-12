;;
;; Illustrator
;;;;
; 使用するSppyの実行ファイルパス（このパス以外のSppyは別物として扱う）
global SppyExe := "W:\マイドライブ\Programming\Sppy_1_5\Sppy_1_5.exe"

; 10秒ごとにチェックを開始（ミリ秒指定）
SetTimer(CheckIllustrator, 10000)
CheckIllustrator() {
    global SppyExe
    static verifiedPid := 0
    if !ProcessExist("Illustrator.exe")
        return
    ; 実行パスを確認できたPIDが生きている間は、WMIを叩かずここで抜ける。
    ; WMIクエリは実測125〜141msかかり、その間AHK全体が止まる。
    ; 素通りさせるとIllustrator起動中はずっと10秒ごとに固まることになるため。
    ; （ProcessExist(pid)は実測0〜16ms）
    if (verifiedPid && ProcessExist(verifiedPid))
        return
    verifiedPid := 0
    ; プロセス名ではなく実行パスで判定する。
    ; 共有ドライブ版など別パスのSppyが動いていたら終了し、マイドライブ版に差し替える。
    correctRunning := false
    wrongPids := []
    query := ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name = 'Sppy_1_5.exe'")
    for proc in query {
        if (proc.ExecutablePath = SppyExe) {
            correctRunning := true
            verifiedPid := proc.ProcessId   ; 次回以降はこのPIDの生死だけ見る
        } else {
            wrongPids.Push(proc.ProcessId)
        }
    }
    if correctRunning
        return
    for pid in wrongPids
        ProcessClose(pid)
    Run(SppyExe, , , &newPid)
    verifiedPid := newPid
}

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
RunAiScriptAsync(name, imeDialogTitle := "") {
    global _aiChildPid, _aiChildName
    ; 多重起動ガード：前回の子がまだ生きていたら起動しない
    if IsAiScriptRunning() {
        WarnAiScriptBusy(name)
        return 0                    ; 起動しなかったことを呼び出し元に伝える
    }
    _aiChildName := name
    base := "W:\共有ドライブ\wc動画\sync\Assets\adobe-scripts_tkhs\illustrator\"
    childPath := A_ScriptDir "\lib\run_ai_script.ahk"
    Run('"' A_AhkPath '" "' childPath '" "' base name '"', , "Hide", &_aiChildPid)
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
global AiMenu := [
    { label: "アートボード", items: [
        { key: "f", label: "移動",                 action: RunAiScriptAsync.Bind("go_to_artboard.jsx") },
        { key: "a", label: "追加",                 action: RunAiScriptAsync.Bind("add_new_artboard.jsx") },
        { key: "s", label: "中身を後ろへずらす",   action: RunAiScriptAsync.Bind("shift_artboard_contents.jsx") },
        { key: "m", label: "枠を作成",             action: RunAiScriptAsync.Bind("create_artboard_shape.jsx") },
        { key: "2", label: "名前を変更",           action: RunAiScriptAsync.Bind("rename_active_artboard.jsx") } ] },
    { label: "書き出し", items: [
        { key: "e", label: "PNG（10倍）",          action: RunAiScriptWithTooltip.Bind("render_active_artboard_10x.jsx") },
        { key: "E", label: "PNG（等倍）",          action: RunAiScriptWithTooltip.Bind("render_active_artboard.jsx") } ] },
    { label: "オブジェクト", items: [
        { key: "t", label: "テキストプロパティエディタ", action: RunAiScriptAsync.Bind("text_property_editor.jsx") },
        { key: "g", label: "位置・サイズ",         action: RunAiScriptAsync.Bind("xywh_input.jsx") } ] }
]

; メニュー定義からツールチップの文字列を組み立てる
BuildAiMenuText(title) {
    global AiMenu
    text := title
    for group in AiMenu {
        text .= "`n- - - - - - - - - - - - - - - -`n" group.label
        for item in group.items
            text .= "`n" item.key ": " item.label
    }
    return text
}

; 押されたキーに対応する項目を返す（無ければ "")
FindAiMenuItem(key) {
    global AiMenu
    for group in AiMenu
        for item in group.items
            if (item.key == key)    ; == で大文字小文字を区別（e と E を分ける）
                return item
    return ""
}

; メニューのキーを1つ読む。キャンセル・タイムアウトなら "" を返す。
ReadAiMenuKey(timeoutSec := 5) {
    ih := InputHook("L1 T" timeoutSec)
    ih.KeyOpt("{Escape}{Space}", "E")
    ih.Start()
    ih.Wait()
    if (ih.EndReason = "Timeout")
        return ""
    key := (ih.EndReason = "EndKey") ? ih.EndKey : ih.Input
    return (key = "Escape") ? "" : key
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
    MyTooltip(BuildAiMenuText("2ストローク待機中（5秒）"), 5000)
    key := ReadAiMenuKey()
    MyTooltip()
    if (key = "")                   ; Escape かタイムアウト
        return
    ; Common.ahk と違い、ここでは選択キーが離されるのを待たない。
    ; どの項目も Send を使わず JSX を起動するだけなので「Sendと物理キーの衝突」を
    ; 避ける必要がなく、待つとキーを離すまでJSXの起動が始まらない＝ダイアログが
    ; 出るのがその分遅れるため。
    ; （KeyWaitはAHKのスレッドを止めるだけでキーを抑制しないので、外しても取りこぼしは増えない）
    if (item := FindAiMenuItem(key))
        item.action.Call()
    else
        MyTooltip("無効なキーです", 500)
}

#HotIf