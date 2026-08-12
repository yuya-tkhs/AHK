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

; 同期実行。JSXが終わるまで本体が固まりホットキーが全部止まるため、現在の呼び出し元は無い。
; ダイアログを出さず一瞬で終わるJSXを足すとき以外は RunAiScriptAsync を使う。
AiScript(name) {
    static base := "W:\共有ドライブ\wc動画\sync\Assets\adobe-scripts_tkhs\illustrator\"
    ComObjActive("Illustrator.Application").DoJavaScriptFile(base name)
}

; jsxを別AHKプロセスで非同期起動する。
; DoJavaScriptFileのブロックを子プロセスに肩代わりさせ、本体をフリーズさせない。
global _aiChildPid := 0
; name: 実行するjsxファイル名
; imeDialogTitle: 指定するとそのダイアログが開いている間だけ日本語入力をON（閉じたらOFF）
RunAiScriptAsync(name, imeDialogTitle := "") {
    global _aiChildPid
    ; 多重起動ガード：前回の子がまだ生きていたら起動しない
    if (_aiChildPid && ProcessExist(_aiChildPid))
        return 0                    ; 起動しなかったことを呼び出し元に伝える
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
    try FileDelete(_aiResultFile)       ; 前回の残骸を消してから起動する
    pid := RunAiScriptAsync(name)
    if (!pid)                           ; 多重起動ガードで起動しなかった＝監視も始めない
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

; 「見せるだけ」のダイアログを、出た時点でこちらから閉じる。
; 自作JSXは結果ファイル方式（RunAiScriptWithTooltip）へ移行済みのため現在の呼び出し元は無い。
; ソースを書き換えられないサードパーティ製JSX（3flab-* / sttk3-* など）を
; AHKから起動するようになったときのために残してある。
; 書き出しのように時間がかかる処理では、待ちきれずに早めに押したEnterは
; ダイアログがまだ無いためIllustrator本体に吸われて消える。結局もう一度
; 押し直すことになり一拍待たされるので、そもそも押さなくて済むようにする。
; 消える内容はツールチップに移すため、ファイル名・保存先は失われない。
; WinWaitはスレッドを占有するので使わず、SetTimerでポーリングする。
global _autoCloseTitle := ""
global _autoCloseDeadline := 0
AutoCloseDialog(title, timeoutMs := 600000) {
    global _autoCloseTitle, _autoCloseDeadline
    _autoCloseTitle := title
    _autoCloseDeadline := A_TickCount + timeoutMs
    SetTimer(AutoClosePoll, 200)
}
AutoClosePoll() {
    global _autoCloseTitle, _autoCloseDeadline
    if !WinExist(_autoCloseTitle) {
        if (A_TickCount > _autoCloseDeadline)   ; 出ないまま時間切れ（JSXが失敗した等）
            SetTimer(AutoClosePoll, 0)
        return
    }
    SetTimer(AutoClosePoll, 0)
    ; 閉じる前に中身を控える。ただしScriptUI（JSXのWindow）は標準のWin32コントロールを
    ; 使わないため空が返る（実測確認済み）。その場合はタイトルだけツールチップに出す。
    body := WinGetText(_autoCloseTitle)
    WinActivate(_autoCloseTitle)
    Sleep(80)                                   ; フォーカスが移るのを待つ
    Send("{Enter}")                             ; ScriptUIのOKボタンは素のEnterで反応する
    Sleep(120)
    if WinExist(_autoCloseTitle)                ; Enterで閉じなければ強制的に閉じる
        WinClose(_autoCloseTitle)
    MyTooltip(body != "" ? body : _autoCloseTitle, 2500)
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
    MyTooltip("
    (
    2ストローク待機中（5秒）
    - - - - - - - - - - - - - - - -
    アートボード
    f: 移動
    a: 追加
    s: 中身を後ろへずらす
    m: 枠を作成
    2: 名前を変更
    - - - - - - - - - - - - - - - -
    書き出し
    e: PNG（10倍）
    E: PNG（等倍）
    - - - - - - - - - - - - - - - -
    オブジェクト
    t: テキストプロパティエディタ
    g: 位置・サイズ
    )", 5000)
    ih := InputHook("L1 T5")
    ih.KeyOpt("{Escape}{Space}", "E")
    ih.Start()
    ih.Wait()
    MyTooltip()
    if (ih.EndReason = "Timeout") {
        return
    }
    capturedKey := (ih.EndReason = "EndKey") ? ih.EndKey : ih.Input
    ; Common.ahk と違い、ここでは選択キーが離されるのを待たない。
    ; どのcaseも Send を使わず AiScript / RunAiScriptAsync を呼ぶだけなので、
    ; 「Sendと物理キーの衝突」を避ける必要がなく、待つとキーを離すまで
    ; JSXの起動が始まらない＝ダイアログが出るのがその分遅れるため。
    ; （KeyWaitはAHKのスレッドを止めるだけでキーを抑制しないので、外しても取りこぼしは増えない）
    switch capturedKey {
        case "Escape": return
        ; 並び順はツールチップの表示順に合わせている
        ; アートボード（f と 2 も同期のAiScriptから寄せた。同期だとJSXが終わるまで
        ; 本体が固まり、その間ほかのホットキーが全部効かなくなるため）
        case "f": RunAiScriptAsync("go_to_artboard.jsx")
        case "a": RunAiScriptAsync("add_new_artboard.jsx")
        case "s": RunAiScriptAsync("shift_artboard_contents.jsx")
        case "m": RunAiScriptAsync("create_artboard_shape.jsx")
        case "2": RunAiScriptAsync("rename_active_artboard.jsx")
        ; 書き出し（switchは既定で大文字小文字を区別するため e / E をそのまま分岐できる）
        ; どちらもJSXはダイアログを出さず結果ファイルを書き、それをツールチップに出す
        case "e": RunAiScriptWithTooltip("render_active_artboard_10x.jsx")
        case "E": RunAiScriptWithTooltip("render_active_artboard.jsx")
        ; オブジェクト
        case "t": RunAiScriptAsync("text_property_editor.jsx")
        case "g": RunAiScriptAsync("xywh_input.jsx")
        default: MyTooltip("無効なキーです", 500)
    }
}

#HotIf