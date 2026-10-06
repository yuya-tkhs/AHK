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
; g はBlenderの移動ツール（G）に合わせた。
global PremiereMenu := [
    { key: "g", label: "モーションの欄へ移動", items: [
        { key: "x", label: "位置 X",             field: "posX" },
        { key: "y", label: "位置 Y",             field: "posY" },
        { key: "s", label: "スケール",           field: "scale" },
        { key: "r", label: "回転",               field: "rotation" },
        { key: "a", label: "アンカーポイント X", field: "anchorX" },
        { key: "c", label: "切り抜き（左）",     field: "cropLeft" },
        { key: "t", label: "不透明度",           field: "opacity" } ] }
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
;;   「見えている入力欄」を行（y座標）ごとにまとめて目的の欄を見分ける。
;;   Tab の回数を決め打ちしないので、見えない欄（大きさ0の Edit）や入力欄以外の
;;   停止位置が増減してもずれない。
;;
;;   並び（実測）：位置 X・Y → スケール → 回転 → アンカーポイント X・Y → アンチフリッカー
;;                 → 切り抜き 左・上・右・下 → 不透明度
;;   目印は「欄が2つ並ぶ行」。1つ目が位置、2つ目がアンカーポイント。
;;   回転はアンカーの直前の行（縦横比を固定していないとスケールが2行になるが、それでも当たる）、
;;   切り抜き（左）はアンカーの2行後、不透明度は6行後。
;;   目的の欄は、それと分かった時点で行き過ぎていることがある（位置 X・アンカー X・回転）ので、
;;   その欄に戻るまで Shift+Tab で戻る。
;;;;

; target: posX / posY / scale / rotation / anchorX / cropLeft / opacity
FocusMotionField(target, label) {
    h := WinExist(exe_pr)
    if !h
        return
    ; 待ちを1ms単位で見るため、探している間だけ Windows のタイマー分解能を1msにする
    ; （既定は約15.6msで、Sleep(5) でも約15ms眠る。落ち着き判定がその分長くなっていた）
    DllCall("winmm\timeBeginPeriod", "uint", 1)
    try {
        PrFindMotionField(h, target, label)
    } finally {
        DllCall("winmm\timeEndPeriod", "uint", 1)
    }
}

PrFindMotionField(h, target, label) {
    static MAX_TABS := 45, MAX_BACK := 12
    Send("+1+5")                    ; 以前の p と同じく、プロジェクト → エフェクトコントロールの順に移る
    PrSettleFocus(h)
    rows := []                      ; 見えている入力欄を行ごとに { y, xs: [x, …] }
    goal := "", cur := ""
    Loop MAX_TABS {
        if !(cur := PrVisibleEdit(PrSendAndSettle(h, "{Tab}")))
            continue
        if (rows.Length && rows[rows.Length].y = cur.y)
            rows[rows.Length].xs.Push(cur.x)
        else
            rows.Push({ y: cur.y, xs: [cur.x] })
        if (rows.Length >= 2 && rows[1].xs.Length < 2)
            break                   ; 最初の行が2つ並びでない＝モーションの位置ではない
        if (goal := PrMotionGoal(rows, target))
            break
    }
    if goal {
        Loop MAX_BACK + 1 {
            if (cur && cur.x = goal.x && cur.y = goal.y)
                return
            if (A_Index > MAX_BACK)
                break
            cur := PrVisibleEdit(PrSendAndSettle(h, "+{Tab}"))
        }
    }
    Send("{Escape}")
    MyTooltip("「" label "」の欄が見つかりません`nクリップを選択し、エフェクトコントロールで「モーション」を開いてください", 3000)
}

; ここまでに見えた行から目的の欄の位置 {x, y} が決まれば返す（まだ決まらなければ ""）
PrMotionGoal(rows, target) {
    pairs := []                     ; 欄が2つ並ぶ行の番号
    for i, row in rows
        if (row.xs.Length >= 2)
            pairs.Push(i)
    if (pairs.Length = 0 || pairs[1] != 1)
        return ""
    switch target {
        case "posX":  return { x: rows[1].xs[1], y: rows[1].y }
        case "posY":  return { x: rows[1].xs[2], y: rows[1].y }
        case "scale": return (rows.Length >= 2) ? { x: rows[2].xs[1], y: rows[2].y } : ""
    }
    if (pairs.Length < 2)
        return ""
    k := pairs[2]                   ; アンカーポイントの行
    switch target {
        case "anchorX":  return { x: rows[k].xs[1], y: rows[k].y }
        case "rotation": return (k - 1 > 1) ? { x: rows[k - 1].xs[1], y: rows[k - 1].y } : ""
        case "cropLeft": return (rows.Length >= k + 2) ? { x: rows[k + 2].xs[1], y: rows[k + 2].y } : ""
        case "opacity":  return (rows.Length >= k + 6) ? { x: rows[k + 6].xs[1], y: rows[k + 6].y } : ""
    }
    return ""
}
; キーを送り、フォーカスが動いてから落ち着くまで待って、着地した窓を返す。
; Premiere が反応する前に「動かない＝着地」と判定しないよう、まず前の窓から
; フォーカスが離れるのを待つ。入力欄（Edit）は欄ごとに作り直されるので、入力欄からの
; 移動なら必ず窓が変わる（上限200ms）。入力欄以外の停止位置はパネル本体の窓のままで、
; 続くと動かないので待ちを短くする。入力欄以外から入力欄へ移るときの反応は最大32ms
; （実測）なので上限45ms。一律200msだと、入力欄以外が続く区間で毎回上限まで待ち、
; 不透明度まで約2秒かかっていた（実測）。
PrSendAndSettle(h, keys) {
    static FROM_EDIT := 200, FROM_OTHER := 45
    prev := 0
    try prev := ControlGetFocus(h)
    limit := FROM_OTHER
    try limit := (WinGetClass(prev) = "Edit") ? FROM_EDIT : FROM_OTHER
    Send(keys)
    t0 := A_TickCount
    while (A_TickCount - t0 < limit) {
        fc := 0
        try fc := ControlGetFocus(h)
        if (fc != prev)
            break
        DllCall("Sleep", "uint", 1)
    }
    return PrSettleFocus(h)
}

; フォーカスが20ms動かなくなるまで待って、その窓を返す（最大400ms）。
; Tab の直後はフォーカスが途中の窓を一瞬経由するため、最初の変化では判定できない（実測）。
; 20ms・30msとも21回中21回取り違え無し（実測）。
PrSettleFocus(h) {
    static STABLE := 20, LIMIT := 400
    t0 := A_TickCount, last := -1, since := A_TickCount
    loop {
        fc := 0
        try fc := ControlGetFocus(h)
        if (fc != last)
            last := fc, since := A_TickCount
        if (A_TickCount - since >= STABLE || A_TickCount - t0 > LIMIT)
            return last
        DllCall("Sleep", "uint", 1)
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
