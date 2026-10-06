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

; 3ストロークのグループ（Illustrator の AiMenu / Explorer の ExplorerMenu と同じ形）。
; 第1階層の文言・サブメニュー・ショートカット一覧はすべてここから作る。
; field はエフェクトコントロールの「モーション」のどの欄か（FocusMotionField を参照）。
global PremiereMenu := [
    { key: "p", label: "モーションの欄にフォーカス", items: [
        { key: "x", label: "位置 X",   field: "posX" },
        { key: "y", label: "位置 Y",   field: "posY" },
        { key: "s", label: "スケール", field: "scale" } ] }
]

; メニューの文言は関数にまとめる（ShortcutList.ahk がこの文字列を読んで一覧に並べる）
PremiereMenuText() {
    global PremiereMenu
    return "
    (
    2ストローク待機中（10秒）
    - - - - - - - - - - - - - - - -
    s: スケール変更
    a: 位置アンカー変更
    d: 空のトラックを削除
    f: クリップを全長に
    h: 再生ヘッド位置を自動選択
    t: オーディオユニット時間の切り替え
    c: キャプションをグラフィックにアップグレード
    r: トラックロック
    R: トラックリリース
    2: トラック名の変更
    )" . BuildGroupMenuLines(PremiereMenu) . KnobMenuText()
}

; 2/3ストローク
^Space:: {
    loop {
        key := ReadMenuKey(PremiereMenuText())
        if (key = "")               ; Escape かタイムアウト
            return
        ; グループキーならサブメニューへ降りる
        if (group := FindMenuGroup(PremiereMenu, key)) {
            item := ReadSubMenuItem(group)
            if (item = "Backspace")
                continue             ; 第1階層へ戻る
            if (item != "") {
                KeyWait(StrLower(item.key))     ; Send と物理キーの衝突を防ぐ
                FocusMotionField(item.field, item.label)
            }
            return
        }
        ; 物理キーから指が離れるまで待機（Sendと物理キーの衝突を防ぐ）
        KeyWait(StrLower(key))
        switch key {
            case "Space":  Send("{vk1D}+7+f{Backspace}{vk1C}")
            case "s":      JsxRun("スケール変更.jsx")
            case "r":      JsxRun("トラックロック.jsx")
            case "R":      JsxRun("トラックリリース.jsx")
            case "d":      JsxRun("空トラック削除.jsx"), Send("=")  ; 全トラック最小化
            case "f":      JsxRun("クリップを全長に.jsx")
            ; メニューをキー送り（Alt+S → P）でたどらず、項目名で直接実行する（c と同じ）
            case "h":      MenuSelect(exe_pr, , "シーケンス", "再生ヘッド位置を自動選択")
            case "t":      Send("+^!t")  ; Premiere側に割り当てたオーディオユニット時間の切り替え
            ; メニュー名は部分一致でよい（実際は「グラフィックとタイトル(&G)」）
            case "c":      MenuSelect(exe_pr, , "グラフィックとタイトル", "キャプションをグラフィックにアップグレード")
            case "2":      JsxRun("リネーム.jsx")
            case "a":      JsxRun("位置アンカー変更.jsx")
            default:       MyTooltip("無効なキーです", 500)
        }
        return
    }
}

;;
;; エフェクトコントロールの「モーション」の欄にフォーカスを合わせる
;;
;;   Premiere のパネルは独自描画で、UI Automation にも中身を出さない（スクリーンリーダーの
;;   合図をONにしても枠だけ。実測）。ただし数値欄は、入力状態になった瞬間だけ Win32 の
;;   Edit が現れ、値と画面上の位置が読める。そこで Tab で欄を順にたどり、
;;   「見えている入力欄」を行ごとにまとめて目的の欄を見分ける。
;;   以前の Tab ×4 の決め打ちと違い、見えない欄（大きさ0の Edit）や入力欄以外の停止位置が
;;   増減してもずれない。並びは 位置 X・Y（同じ行に2つ）→ スケール（次の行）→ 回転 → …
;;;;

; target: "posX" / "posY" / "scale"
FocusMotionField(target, label) {
    static MAX_TABS := 40
    h := WinExist(exe_pr)
    if !h
        return
    Send("+1+5")                    ; 以前の p と同じく、プロジェクト → エフェクトコントロールの順に移る
    PrSettleFocus(h)
    first := "", paired := false
    Loop MAX_TABS {
        e := PrVisibleEdit(PrSendAndSettle(h, "{Tab}"))
        if !e
            continue
        if !first {                 ; 最初に見えた入力欄＝位置 X のはず
            first := e
            continue
        }
        if !paired {                ; 2つ目が同じ行なら 位置 X・Y の組
            if (e.y != first.y)
                break
            paired := true
            if (target = "posY")
                return
            if (target = "posX") {  ; 1つ戻る
                back := PrVisibleEdit(PrSendAndSettle(h, "+{Tab}"))
                if (back && back.x = first.x && back.y = first.y)
                    return
                break
            }
            continue
        }
        if (target = "scale" && e.y > first.y)  ; 位置の次の行＝スケール
            return
    }
    Send("{Escape}")
    MyTooltip("「" label "」の欄が見つかりません`nクリップを選択し、エフェクトコントロールで「モーション」を開いてください", 3000)
}

; キーを送り、フォーカスが動いてから落ち着くまで待って、着地した窓を返す。
; Premiere が反応する前に「動かない＝着地」と判定しないよう、まず前の窓から
; フォーカスが離れるのを待つ（最大200ms）。入力欄以外の停止位置が続くと同じ窓のまま
; 動かないことがあるので、そのときは上限まで待ってから落ち着き待ちに進む。
PrSendAndSettle(h, keys) {
    static MOVE_LIMIT := 200
    prev := 0
    try prev := ControlGetFocus(h)
    Send(keys)
    t0 := A_TickCount
    while (A_TickCount - t0 < MOVE_LIMIT) {
        fc := 0
        try fc := ControlGetFocus(h)
        if (fc != prev)
            break
        Sleep(5)
    }
    return PrSettleFocus(h)
}

; フォーカスが30ms動かなくなるまで待って、その窓を返す（最大400ms）。
; Tab の直後はフォーカスが途中の窓を一瞬経由するため、最初の変化では判定できない（実測）。
; 30msで着地の取り違えは無く、1回あたり約60ms（実測）。
PrSettleFocus(h) {
    static STABLE := 30, LIMIT := 400
    t0 := A_TickCount, last := -1, since := A_TickCount
    loop {
        fc := 0
        try fc := ControlGetFocus(h)
        if (fc != last)
            last := fc, since := A_TickCount
        if (A_TickCount - since >= STABLE || A_TickCount - t0 > LIMIT)
            return last
        Sleep(5)
    }
}

; 見えている入力欄（Win32 の Edit で大きさがある）なら {x, y}、それ以外は ""
PrVisibleEdit(hwnd) {
    try {
        if (hwnd && WinGetClass(hwnd) = "Edit") {
            WinGetPos(&x, &y, &w, &hh, hwnd)
            if (w > 0 && hh > 0)
                return { x: x, y: y }
        }
    }
    return ""
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
