;;
;; Illustrator
;;;;
; 使用するSppyの実行ファイルパス（このパス以外のSppyは別物として扱う）
global SppyExe := "W:\マイドライブ\Programming\Sppy_1_5\Sppy_1_5.exe"

; 10秒ごとにチェックを開始（ミリ秒指定）
SetTimer(CheckIllustrator, 10000)
CheckIllustrator() {
    global SppyExe
    if !ProcessExist("Illustrator.exe")
        return
    ; プロセス名ではなく実行パスで判定する。
    ; 共有ドライブ版など別パスのSppyが動いていたら終了し、マイドライブ版に差し替える。
    correctRunning := false
    wrongPids := []
    query := ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, ExecutablePath FROM Win32_Process WHERE Name = 'Sppy_1_5.exe'")
    for proc in query {
        if (proc.ExecutablePath = SppyExe)
            correctRunning := true
        else
            wrongPids.Push(proc.ProcessId)
    }
    if correctRunning
        return
    for pid in wrongPids
        ProcessClose(pid)
    Run(SppyExe)
}

AiScript(name) {
    static base := "W:\共有ドライブ\wc動画\sync\Assets\adobe-scripts_tkhs\illustrator\"
    ComObjActive("Illustrator.Application").DoJavaScriptFile(base name)
}

#HotIf WinActive(exe_ai)

; Ctrl+Shift+Alt+Enter → F21
^+!Enter:: Send("{F21}")

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
    t: テキストプロパティエディタ
    f: アートボードへ移動
    2: アートボード名変更
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
    if (capturedKey != "") {
        KeyWait(StrLower(capturedKey))
    }
    switch capturedKey {
        case "Escape": return
        case "t": AiScript("text_property_editor.jsx")
        case "f": AiScript("go_to_artboard.jsx")
        case "2": AiScript("rename_active_artboard.jsx")
        default: MyTooltip("無効なキーです", 500)
    }
}

#HotIf