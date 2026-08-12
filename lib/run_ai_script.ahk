; Illustrator用jsxを「別プロセス」で非同期に実行するための小スクリプト。
; yuya_allways本体から Run で起動され、DoJavaScriptFile のブロックを肩代わりする。
; これにより本体はダイアログ表示中もフリーズせず、各種ホットキーが生き続ける。
;
; 使い方:
;   AutoHotkey64.exe run_ai_script.ahk "<jsxのフルパス>"
;   AutoHotkey64.exe run_ai_script.ahk --code "<JavaScriptの文字列>"
; --code は整列などIllustratorのメニューコマンド用。JSXファイルが存在しない操作を
; 共有ドライブにファイルを作らずに実行するため（COMのDoJavaScriptで動くことは実測確認済み）。
#Requires AutoHotkey v2.0
#SingleInstance Off              ; 本体や他の子プロセスを絶対に終了させない

if (A_Args.Length < 1)
    ExitApp()
isCode := (A_Args[1] = "--code")
if (isCode) {
    if (A_Args.Length < 2)
        ExitApp()
    path := A_Args[2]
} else {
    path := A_Args[1]
}

; Illustratorへの接続をリトライ（起動直後・ビジー時の RPC_E_CALL_REJECTED 対策）
app := ""
Loop 10 {
    try {
        app := ComObjActive("Illustrator.Application")
        break
    } catch {
        Sleep(150)
    }
}
if (app = "")
    ExitApp()                    ; 取得できなければ無言で終了（エラーダイアログを出さない）

; ダイアログが閉じるまでここでブロックする（＝本体ではなく、この子プロセスが待つ）
try {                            ; 失敗してもエラーダイアログを出さない
    if (isCode)
        app.DoJavaScript(path)
    else
        app.DoJavaScriptFile(path)
}
ExitApp()                        ; 正常・異常どちらでも終了 → プロセスは残らない
