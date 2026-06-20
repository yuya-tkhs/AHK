; ===== JsxLauncher 連携 =====================================================
; CEP拡張 JsxLauncher が監視する連携ファイルにコマンドを書き込み、.jsx を実行する。
; 仕様: パネルが jsxl_cmd.txt を200ms毎に監視し、実行後にファイルを削除する。
;   "run:NAME"      … パネルで指定したルートフォルダ配下を名前で実行。
;                     NAME は「ファイル名.jsx」「サブフォルダ/ファイル名.jsx」どちらも可。
;                     .jsx省略可・大小無視。
; 前提: Premiere側で JsxLauncher パネルを開いたままにしておくこと(閉じていると拾われない)。
global gJsxCmd := A_AppData . "\Adobe\CEP\extensions\JsxLauncher\jsxl_cmd.txt"

; 既存を消してから1コマンドだけ書く(追記の重複を防ぐ)。UTF-8 BOMなし(UTF-8-RAW)。
JsxWrite(cmd) {
    try FileDelete gJsxCmd
    FileAppend cmd, gJsxCmd, "UTF-8-RAW"
}
JsxRun(name, *) {
    JsxWrite("run:" name)
}
; ===========================================================================

; AdobeCommon.ahkのOnCtrlEnterPost()から呼ばれる
OnCtrlEnterPremiere() {
    Send("{vk1D}")
    Send("^{Tab}")
}

; ファイルダイアログ（名前を付けて保存 等）ではExplorer側の2ストロークを優先するため除外する
#HotIf WinActive( exe_pr ) && !IsFileDialog()

; グラフィックステキストを編集
^vk1C:: Send("{vk1C}^![^!{Enter}")

; 2ストローク
^Space:: {
    MyTooltip("
    (
    2ストローク待機中（5秒）
    - - - - - - - - - - - - - - - -
    p: 入力状態
    s: スケール変更
    a: 位置アンカー変更
    d: 空のトラックを削除
    h: 再生ヘッド位置を自動選択
    r: トラックロック
    R: トラックリリース
    2: トラック名の変更
    )", 5000)
    ih := InputHook("L1 T5") ; 次の1文字を待機 (L1: 1文字入力で終了, T2: 2秒でタイムアウト)
    ih.KeyOpt("{Escape}{Space}", "E")
    ih.Start()
    ih.Wait()
    MyTooltip()
    if (ih.EndReason = "Timeout") {
        return
    }
    capturedKey := (ih.EndReason = "EndKey") ? ih.EndKey : ih.Input
    ; 物理キーから指が離れるまで待機（Sendと物理キーの衝突を防ぐ）
    if (capturedKey != "") {
        KeyWait(StrLower(capturedKey))
    }
    switch capturedKey {
        case "Escape": return
        case "Space":  Send("{vk1D}+7+f{Backspace}{vk1C}")
        case "p":      Send("+1+5{Tab 4}")
        case "s":      JsxRun("スケール変更.jsx")
        case "r":      JsxRun("トラックロック.jsx"), Send("+3")
        case "R":      JsxRun("トラックリリース.jsx"), Send("+3")
        case "d":      JsxRun("空トラック削除.jsx")
        case "h":
            Send("!s")  ; Alt+S でシーケンスメニューを開く
            Send("p")   ; P で再生ヘッド位置を自動選択
        case "2":      JsxRun("トラック名変更.jsx")
        case "a":      JsxRun("位置アンカー変更.jsx")
        default:       MyTooltip("無効なキーです", 500)
    }
}

; 編集点を全てのトラックに追加
; (1) 最も近い編集点をリップルアウト選択して、指定した値プラストリミング
; (2) 最も近い編集点をリップルイン選択して、指定した値マイナストリミング
; (1)(2) にターゲットの切り替えを追加したもの
trackPre  := "^{Numpad0}^!{Numpad1}^!{Numpad2}^!{Numpad0}"
trackPost := "^{Numpad0}^{Numpad7}^!{Numpad0}^!{Numpad1}^!{Numpad2}"

#HotIf WinActive( exe_pr )
+^!e:: Send("+^k")
+^!q:: {
    Send(trackPre)
    Sleep(100)
    Send("+^!q+^{Right}")
    Sleep(100)
    Send(trackPost)
}
+^!w:: {
    Send(trackPre)
    Sleep(100)
    Send("+^!w+^{Left}")
    Sleep(100)
    Send(trackPost)
}
+^!a:: Send("{Click Right}{Down 2}{Enter}")


#HotIf WinActive( exe_pr ) && GetKeyState("LButton", "P")
; 編集点の追加やクリップ名の変更
e::  Send("^k")
+e:: Send("+^k")
2::  Send("+{F2}")
; ターゲットの移動
[:: {
    if GetKeyState("Ctrl", "P") ; オーディオターゲット
        Send("!{PgDn}")
    else ; ビデオターゲット
        Send("^!{PgDn}")
}
]:: {
    if GetKeyState("Ctrl", "P")
        Send("!{PgUp}")
    else
        Send("^!{PgUp}")
}
; 拡大・縮小
-:: Send("{- 3}")
vkBA:: Send("{: 3}")

#HotIf
