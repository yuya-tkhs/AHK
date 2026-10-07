#HotIf WinActive("ahk_class CabinetWClass") or IsFileDialog()

; 3ストロークのグループ（Illustrator の AiMenu と同じ形）。
; 第1階層の文言・サブメニュー・ショートカット一覧はすべてここから作るので、
; 追加・変更はこの配列だけを直せばよい。
; run はそのグループの項目を実行する関数（選んだ項目を1つ受け取る）。
;
; g: cmd は Googleドライブの右クリックメニューに出る項目名そのもの（表示文字列で探すため、
;    Googleドライブの更新で文言が変わったらここを直す）。
;    result は実行後にツールチップへ出す結果の種類（GDriveRun を参照）。
; o: exe は実行ファイル名だけで書く。Windows の App Paths に登録されているので
;    インストール先（「Adobe Photoshop 2026」のような年版フォルダ）を書かずに済み、
;    バージョンが上がっても端末が変わっても直さなくてよい。
global ExplorerMenu := [
    { key: "o", label: "アプリケーションで開く", run: OpenSelectedWith, items: [
        { key: "p", label: "Photoshop",   exe: "Photoshop.exe" },
        { key: "i", label: "Illustrator", exe: "Illustrator.exe" },
        { key: "a", label: "Audition",    exe: "Adobe Audition.exe" } ] },
    { key: "g", label: "Googleドライブ", run: GDriveRun, items: [
        { key: "t", label: "オフラインで使用可能にする",     cmd: "オフラインで使用可能にする",     result: "state" },
        { key: "f", label: "オンラインでのみ使用可能にする", cmd: "オンラインでのみ使用可能にする", result: "state" },
        { key: "s", label: "共有",                           cmd: "Google ドライブで共有",           result: "open" },
        { key: "o", label: "ドライブで開く",                 cmd: "Google ドライブで開く",           result: "open" },
        { key: "c", label: "リンクをコピー",                 cmd: "リンクをクリップボードにコピー", result: "link" } ] }
]

; メニューの文言は関数にまとめる（ShortcutList.ahk がこの文字列を読んで一覧に並べる）
ExplorerMenuText() {
    global ExplorerMenu
    return "
    (
    2ストローク待機中（10秒）
    - - - - - - - - - - - - - - - -
    Space: Rename
    r: PowerRename
    t: テキストファイルの作成
    c: 開いているフォルダのパスを取得
    d: Downloadsの最新ファイルを移動
    v: コピーしたパスへ移動
    x: 7-Zipで展開
    - - - - - - - - - - - - - - - -
    1: 動画フォルダの作成
    2: Original, Proxy
    )" . BuildGroupMenuLines(ExplorerMenu) . KnobMenuText()
}

; 2/3ストローク
^Space:: {
    loop {
        key := ReadMenuKey(ExplorerMenuText())
        if (key = "")               ; Escape かタイムアウト
            return
        ; グループキーならサブメニューへ降りる
        if (group := FindMenuGroup(ExplorerMenu, key)) {
            item := ReadSubMenuItem(group)
            if (item = "Backspace")
                continue             ; 第1階層へ戻る
            if (item != "")
                group.run.Call(item)
            return
        }
        ; 物理キーから指が離れるまで待機（Sendと物理キーの衝突を防ぐ）
        KeyWait(StrLower(key))
        switch key {
            case "Space":  Send("{F2}")
            case "r":      RunPowerRename()
            case "t":      CreateTextFile()
            case "c":      RunGetExplorerPath()
            case "d":      MoveFileHere()
            case "v":      NavigateToClipboardPath()
            case "x":      ExtractWith7Zip()
            case "1":      CreateFolders(["01_Master","02_Assets","03_Works","04_Projects","05_Render"])
            case "2":      CreateFolders(["Original","Proxy"])
            default:       MyTooltip("無効なキーです", 500)
        }
        return
    }
}


MoveFileHere() {
    sourceDir := EnvGet("USERPROFILE") . "\Downloads"
    destDir := GetCurrentExplorerPath()

    if (destDir = "") {
        MyTooltip("移動先フォルダを取得できませんでした", 2000)
        return
    }
    if (sourceDir = destDir) {
        MyTooltip("移動元と移動先が同じフォルダです", 2000)
        return
    }

    ; Downloadsの最新ファイルを探す
    newestFile := ""
    newestTime := ""
    Loop Files, sourceDir . "\*", "F" {
        if (newestTime = "" || A_LoopFileTimeModified > newestTime) {
            newestTime := A_LoopFileTimeModified
            newestFile := A_LoopFilePath
        }
    }

    if (newestFile = "") {
        MyTooltip("Downloadsにファイルがありません", 2000)
        return
    }

    SplitPath(newestFile, &fileName)
    SplitPath(destDir, &destName, &destParentPath)
    SplitPath(destParentPath, &destParentName)
    shortDest := "...\" . destParentName . "\" . destName
    MyTooltip( Format("
    (
    移動
    - - - - - - - - - - - - - - - -
    {}
    {}
    - - - - - - - - - - - - - - - -
    Enter/Space: 実行
    Esc: キャンセル
    )", fileName, shortDest ), 15000 )

    ih := InputHook("L1 T15")
    ih.KeyOpt("{Escape}{Enter}{Space}", "E")
    ih.Start()
    ih.Wait()
    MyTooltip()

    if (ih.EndReason = "Timeout" || ih.EndKey = "Escape") {
        return
    }

    destPath := destDir . "\" . fileName
    if (FileExist(destPath)) {
        if (MsgBox("同名ファイルが存在します。上書きしますか?`n" . destPath, "確認", "YesNo") != "Yes") {
            return
        }
    }

    try {
        FileMove(newestFile, destPath, true)
        MyTooltip("移動完了: " . fileName, 2000)
    } catch as err {
        MsgBox("ファイルの移動に失敗しました:`n" . err.Message)
    }
}

; 開いているフォルダに空のテキストファイルを作り、名前の変更状態にする（2ストロークの t）。
; 以前は背景の右クリックメニューをキー送り（新規作成 → ↑3回）でたどっていたが、
; 「新規作成」の並びは入っているアプリで変わるため、ファイルを直接作るようにした。
CreateTextFile() {
    dir := GetCurrentExplorerPath()
    if (dir = "") {
        MyTooltip("作成先のフォルダを取得できませんでした", 2000)
        return
    }
    dir := RTrim(dir, "\")
    path := dir "\新しいテキスト ドキュメント.txt"
    n := 1
    while FileExist(path)           ; エクスプローラーと同じく「 (2)」から番号を振る
        path := dir "\新しいテキスト ドキュメント (" (++n) ").txt"
    try FileAppend("", path)
    catch as err {
        MyTooltip("テキストファイルを作成できませんでした`n" err.Message, 3000)
        return
    }
    ; 作ったことをエクスプローラーへすぐ知らせる。知らせないと一覧に現れるまで約1秒、
    ; 知らせると約0.5秒（実測。IFileOperation で作っても同じだった）
    DllCall("shell32\SHChangeNotify", "int", 0x2, "uint", 0x5, "wstr", path, "ptr", 0)  ; SHCNE_CREATE, SHCNF_PATHW
    if !SelectAndRename(path)
        MyTooltip("テキストファイルを作成しました`n" path, 2000)
}

; path をエクスプローラーの一覧で選択し、名前の変更状態にする。
; 作った直後は一覧にまだ現れていない（実測0.5〜1秒）ので、現れるまで待つ。
; ファイルダイアログ（エクスプローラーのタブが無い）では false を返す。
SelectAndRename(path) {
    static SVSI_SELECT := 0x1, SVSI_EDIT := 0x3, SVSI_DESELECTOTHERS := 0x4, SVSI_ENSUREVISIBLE := 0x8, SVSI_FOCUSED := 0x10
    tab := GetActiveExplorerTab()
    if (tab = "")
        return false
    SplitPath(path, &name)
    ; まず普通に選択して、一覧に現れたこと（フォーカスが移ったこと）を確かめてから
    ; 名前の変更に入る。名前の変更中は FocusedItem が更新されないので、
    ; いきなり SVSI_EDIT を付けると成功したかどうかを判定できない（実測）。
    Loop 60 {                       ; 最大3秒
        try {
            if (item := tab.Document.Folder.ParseName(name)) {
                tab.Document.SelectItem(item, SVSI_SELECT | SVSI_DESELECTOTHERS | SVSI_ENSUREVISIBLE | SVSI_FOCUSED)
                if (tab.Document.FocusedItem.Path = path) {
                    tab.Document.SelectItem(item, SVSI_EDIT)
                    return true
                }
            }
        }
        Sleep(50)
    }
    return false
}

GetActiveExplorerTab() {
    try {
        hwnd := WinExist("A")
        activeTab := 0
        ; Windows 11の場合のみ、「現在アクティブなタブ画面」の専用IDを取得
        try activeTab := ControlGetHwnd("ShellTabWindowClass1", hwnd)
        for window in ComObject("Shell.Application").Windows {
            ; 別のウィンドウは無視
            if (window.hwnd != hwnd) {
                continue
            }
            ; Win11で複数タブが存在する場合、アクティブなタブと一致するかチェック
            if (activeTab) {
                static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
                shellBrowser := ComObjQuery(window, IID_IShellBrowser, IID_IShellBrowser)
                ComCall(3, shellBrowser, "uint*", &thisTab := 0)
                ; 見えているタブのIDと一致しなければスキップ（裏のタブを無視）
                if (thisTab != activeTab) {
                    continue
                }
            }
            ; 一致したタブのオブジェクトを返す
            return window
        }
    }
    return ""
}

RunGetExplorerPath() {
    A_Clipboard := GetCurrentExplorerPath()
}

GetCurrentExplorerPath() {
    tab := GetActiveExplorerTab()
    if (tab != "") {
        return tab.Document.Folder.Self.Path
    }
    ; 本物のエクスプローラータブが取れない場合（ファイルダイアログ等）は
    ; アドレスバー経由でフルパスを取得する
    if (IsFileDialog()) {
        return GetPathViaAddressBar()
    }
    return ""
}

; ファイルを開く/保存するダイアログ（#32770）かどうかを判定する。
; MsgBox等の汎用ダイアログと区別するため、ファイル一覧（DirectUIHWND）の有無で確認する。
IsFileDialog() {
    hwnd := WinActive("ahk_class #32770")
    if (!hwnd) {
        return false
    }
    for ctrl in WinGetControls("ahk_id " hwnd) {
        if (InStr(ctrl, "DirectUIHWND") = 1) {
            return true
        }
    }
    return false
}

; アドレスバー（Alt+D）でフルパスを選択 → コピーして現在フォルダのパスを取得する。
; ダイアログにはエクスプローラーのCOMタブが無いためのフォールバック。
GetPathViaAddressBar() {
    saved := ClipboardAll()
    A_Clipboard := ""
    Send("!d")          ; アドレスバーにフォーカス（フルパスが選択状態になる）
    Sleep(120)
    Send("^c")          ; 選択中のパスをコピー
    path := ""
    if (ClipWait(0.5)) {
        path := Trim(A_Clipboard)
    }
    Send("{Escape}")    ; アドレスバーをパンくず表示に戻す
    A_Clipboard := saved
    return path
}

; クリップボードにコピーされているパスへ移動する。
; フォルダパスならそのフォルダへ、ファイルパスならその親フォルダへ移動する。
; エクスプローラーではタブを直接移動させる（アドレスバーへのキー送りやクリップボードの
; 書き換えをしない）。タブを持たないファイルダイアログだけアドレスバー経由にする。
NavigateToClipboardPath() {
    raw := Trim(A_Clipboard, " `t`r`n`"")  ; 前後の空白・改行・引用符を除去
    if (raw = "") {
        MyTooltip("クリップボードにパスがありません", 2000)
        return
    }
    if (DirExist(raw)) {
        target := raw
    } else if (FileExist(raw)) {
        SplitPath(raw, , &target)          ; ファイルの場合は親フォルダへ
    } else {
        MyTooltip("有効なパスではありません:`n" raw, 2500)
        return
    }
    if ((tab := GetActiveExplorerTab()) != "") {
        tab.Navigate2(target)
        if (target != raw)          ; ファイルなら移動先でそのファイルを選ぶ
            SelectAfterNavigate(tab, raw)
        return
    }
    Send("!d")          ; アドレスバーにフォーカス
    Sleep(120)
    Send("^a")          ; 既存テキストを全選択
    A_Clipboard := target ; クリップボード経由で貼り付け
    ClipWait(0.5)
    Send("^v")
    Sleep(80)
    Send("{Enter}")     ; 移動
}

; 移動の完了を待ってから path を選択する（移動直後は前のフォルダの一覧のままのため）
SelectAfterNavigate(tab, path) {
    static SVSI_SELECT := 0x1, SVSI_DESELECTOTHERS := 0x4, SVSI_ENSUREVISIBLE := 0x8, SVSI_FOCUSED := 0x10
    SplitPath(path, &name, &dir)
    Loop 40 {                       ; 最大2秒
        try {
            if (tab.Document.Folder.Self.Path = dir && (item := tab.Document.Folder.ParseName(name))) {
                tab.Document.SelectItem(item, SVSI_SELECT | SVSI_DESELECTOTHERS | SVSI_ENSUREVISIBLE | SVSI_FOCUSED)
                return
            }
        }
        Sleep(50)
    }
}

; 選択中のファイルを item.exe で開く（3ストロークの o）。
; 複数選択はまとめて1回の起動に渡す（Adobe系は起動済みならそのウィンドウで開く）。
OpenSelectedWith(item) {
    selected := GetSelectedPaths()
    if (selected = "") {
        MyTooltip("エクスプローラーのウィンドウで使ってください", 2000)
        return
    }
    paths := []
    args := ""
    for p in selected {
        if DirExist(p)              ; フォルダはアプリに渡しても開けないので外す
            continue
        paths.Push(p)
        args .= ' "' p '"'
    }
    if (paths.Length = 0) {
        MyTooltip("ファイルを選択してください", 2000)
        return
    }
    try {
        Run('"' item.exe '"' args)
        MyTooltip(item.label " で開いています`n" GDriveTargetName(paths), 2000)
    } catch as err {
        MyTooltip(item.label " を起動できませんでした`n" err.Message, 3000)
    }
}

; 選択中の圧縮ファイルを 7-Zip で展開する（2ストロークの x）。
; 中身がアーカイブと同名のフォルダ1つにまとまっていれば「ここに展開」、
; ファイルが直接入っていれば「<名前>\ に展開」にする（フォルダの二重化とばらまきを両方避ける）。
; 右クリックメニューはたどらず 7z.exe で中身を調べ、展開は 7zG.exe（進捗・上書き確認・パスワード入力の画面が出る）に任せる。
; macOS で作った zip に付く __MACOSX は判定から外し、展開もしない。
ExtractWith7Zip() {
    paths := GetSelectedPaths()
    if (paths = "") {
        MyTooltip("エクスプローラーのウィンドウで使ってください", 2000)
        return
    }
    dir7z := Get7ZipDir()
    if !FileExist(dir7z "7z.exe") {
        MyTooltip("7-Zip が見つかりません", 2000)
        return
    }
    msgs := []
    skipped := []
    for p in paths {
        if DirExist(p)
            continue
        SplitPath(p, &fileName, &dir, , &nameNoExt)
        mode := ArchiveExtractMode(dir7z "7z.exe", p, nameNoExt)
        if (mode = "") {
            skipped.Push(fileName)
            continue
        }
        dest := (mode = "here") ? dir : dir "\" nameNoExt
        ; -o の末尾に \ を付けない（"…\" の \ が閉じ引用符を打ち消すため）
        try Run('"' dir7z '7zG.exe" x "' p '" -o"' dest '" -xr!__MACOSX')
        catch as err {
            MyTooltip("7-Zip を起動できませんでした`n" err.Message, 3000)
            return
        }
        msgs.Push((mode = "here" ? "ここに展開: " : nameNoExt "\ に展開: ") fileName)
    }
    for f in skipped
        msgs.Push("圧縮ファイルではありません: " f)
    MyTooltip(msgs.Length ? JoinLines(msgs) : "圧縮ファイルを選択してください", 2000)
}

; 中身を調べて展開の仕方を返す。"here" = 同名フォルダにまとまっている / "folder" = それ以外 /
; "" = 圧縮ファイルとして開けない。
ArchiveExtractMode(exe7z, path, name) {
    tmp := A_Temp "\ahk_7z_list.txt"
    try FileDelete(tmp)
    ; < nul はパスワードを聞かれたときに入力待ちで止まらないため。-sccUTF-8 で日本語の名前を化けさせない
    code := RunWait(A_ComSpec ' /c ""' exe7z '" l -slt -ba -sccUTF-8 "' path '" < nul > "' tmp '" 2>nul"', , "Hide")
    list := ""
    try list := FileRead(tmp, "UTF-8")
    try FileDelete(tmp)
    if (code >= 2)
        return ""
    isFolder := false
    entries := 0
    last := ""
    for line in StrSplit(list, "`n", "`r") {
        if (SubStr(line, 1, 7) = "Path = ") {
            last := SubStr(line, 8)
            top := StrSplit(last, "\")[1]
            if (top = "__MACOSX")
                continue
            entries++
            if (top != name)                ; 同名フォルダの外に何かある
                return "folder"
            if InStr(last, "\")             ; フォルダ自体の項目が無い zip もあるので、下に物があることでも見る
                isFolder := true
        } else if (line = "Folder = +" && last = name) {
            isFolder := true
        }
    }
    return (entries && isFolder) ? "here" : (entries ? "folder" : "")
}

Get7ZipDir() {
    for v in ["Path64", "Path"] {
        try {
            if (d := RegRead("HKLM\SOFTWARE\7-Zip", v))
                return RTrim(d, "\") "\"
        }
    }
    return A_ProgramFiles "\7-Zip\"
}

JoinLines(arr) {
    s := ""
    for v in arr
        s .= (A_Index > 1 ? "`n" : "") v
    return s
}

;;
;; 右クリックメニューの項目を、画面に出さずに名前で探して実行する
;;
;;   右クリックの項目の多くは classic な IContextMenu ハンドラが出している
;;  （Googleドライブ = drivefsext.dll / PowerRename = PowerRenameExt）。
;;   ハンドラを直接作り、画面に出さないメニューへ項目を入れさせてから、
;;   項目名で探して InvokeCommand する（InvokeShellMenu）。
;;   キー送りや画像認識と違い、複数選択・ファイルとフォルダの違いでメニュー構成が
;;   変わっても、端末（DPI・テーマ）が変わっても壊れない。
;;   シェル全体の右クリックメニューを作ると約340msかかるが、ハンドラ単体なら約31ms。
;;   項目には動詞名（GetCommandString）が無いので、表示文字列で探すしかない。
;;;;

global CLSID_DRIVEFS_MENU := "{EE15C2BD-CECB-49F8-A113-CA1BFC528F5B}"     ; DriveFS ContextMenu Handler
global CLSID_POWERRENAME_MENU := "{0440049F-D1DC-4E46-B27B-98393D79486B}" ; PowerRenameExt

; 選択中の項目のパス（エクスプローラーのタブが取れなければ ""、選択が無ければ空の配列）
GetSelectedPaths() {
    tab := GetActiveExplorerTab()
    if (tab = "")
        return ""
    paths := []
    for it in tab.Document.SelectedItems
        paths.Push(it.Path)
    return paths
}

; 選択中の項目を PowerRename で名前変更する（2ストロークの r）
RunPowerRename() {
    paths := GetSelectedPaths()
    if (paths = "") {
        MyTooltip("エクスプローラーのウィンドウで使ってください", 2000)
        return
    }
    if (paths.Length = 0) {
        MyTooltip("ファイルかフォルダを選択してください", 2000)
        return
    }
    try status := InvokeShellMenu(paths, "PowerRename で名前を変更する", WinExist("A"), true, CLSID_POWERRENAME_MENU)
    catch as err {
        MyTooltip("PowerRename を起動できませんでした`n" err.Message, 3000)
        return
    }
    if (status != "ok")
        MyTooltip("PowerRename のメニューが見つかりません`n（PowerToys が起動していないか、表示名が変わった可能性があります）", 3000)
}

; 選択中の項目に対して Googleドライブのメニュー項目を実行し、結果をツールチップに出す。
; item.result: "state" = オフライン/オンラインの切り替え（チェック状態で反映を確かめる）
;              "link"  = リンクのコピー（クリップボードに入ったリンクを出す）
;              "open"  = ブラウザや共有ダイアログが開くもの（依頼したことだけ知らせる）
GDriveRun(item) {
    paths := GetSelectedPaths()
    if (paths = "") {
        MyTooltip("エクスプローラーのウィンドウで使ってください", 2000)
        return
    }
    if (paths.Length = 0) {
        MyTooltip("ファイルかフォルダを選択してください", 2000)
        return
    }
    target := GDriveTargetName(paths)

    if (item.result = "link") {
        saved := ClipboardAll()
        A_Clipboard := ""           ; ClipWait でリンクが入ったことを見分けるため空にする
    }
    try status := InvokeDriveMenu(paths, item.cmd, WinExist("A"))
    catch as err {
        MyTooltip("Googleドライブの操作に失敗しました`n" err.Message, 3000)
        return
    }

    switch status {
        case "empty":               ; Googleドライブ外のファイル
            MyTooltip("Googleドライブ上のファイルではありません`n" target, 2500)
        case "notfound":
            ; 共有・開く・リンクは1つだけ選んだときにしか出ない
            msg := (paths.Length > 1) ? "（複数選択では使えない項目です）" : "（Googleドライブの表示名が変わった可能性があります）"
            MyTooltip("メニューに「" item.cmd "」がありません`n" msg, 3000)
        case "already":
            MyTooltip("すでに「" item.label "」になっています`n" target, 2000)
        case "ok":
            GDriveReportResult(item, paths, target)
    }
    if (item.result = "link" && status != "ok")
        A_Clipboard := saved        ; 何も入らなかったので元に戻す
}

; 実行後の結果を確かめてツールチップに出す
GDriveReportResult(item, paths, target) {
    switch item.result {
        case "state":
            ; 反映されたかを右クリックメニューのチェック状態で確かめる
            if (InvokeDriveMenu(paths, item.cmd, 0, false) = "already")
                MyTooltip("「" item.label "」にしました`n" target, 2000)
            else
                MyTooltip("「" item.label "」を依頼しました（反映待ち）`n" target, 2500)
        case "link":
            if ClipWait(3)
                MyTooltip("リンクをコピーしました`n" A_Clipboard, 2500)
            else
                MyTooltip("リンクを取得できませんでした`n" target, 2500)
        default:
            MyTooltip("「" item.label "」を開いています`n" target, 2000)
    }
}

; ツールチップに出す対象名（1件なら名前、複数なら「名前 ほかN件」）
GDriveTargetName(paths) {
    SplitPath(paths[1], &name)
    return (paths.Length > 1) ? name " ほか" (paths.Length - 1) "件" : name
}

; Googleドライブのハンドラで InvokeShellMenu する
InvokeDriveMenu(paths, cmdText, hwnd := 0, invoke := true) {
    return InvokeShellMenu(paths, cmdText, hwnd, invoke, CLSID_DRIVEFS_MENU)
}

; 右クリックメニューを画面に出さずに作り、cmdText の項目を実行する。
; handler にハンドラのCLSIDを渡すとそのハンドラの項目だけを作る（速い）。
; 省略するとシェル全体の右クリックメニュー（全ハンドラ＋標準の項目）を作る。
; 項目名は「(&E)」や「&」を除いて比べるので、アクセラレータは書かなくてよい。
; invoke := false なら探すだけ（状態の確認用）。
; 戻り値: "ok" / "already"（チェック済み＝すでにその状態）/ "notfound"
;         / "empty"（文字のある項目が1つも無い＝そのハンドラの対象外。
;           Googleドライブ外のファイルでも Drive のハンドラは区切り線だけ足す（実測））
; paths はすべて同じフォルダにあること（エクスプローラーの選択は必ずそうなる。
; 検索結果のように親が混ざると、2件目以降の相対IDが1件目の親と食い違う）。
InvokeShellMenu(paths, cmdText, hwnd := 0, invoke := true, handler := "") {
    static IID_IShellExtInit := "{000214E8-0000-0000-C000-000000000046}"
    static IID_IContextMenu  := "{000214E4-0000-0000-C000-000000000046}"
    static IID_IShellFolder  := "{000214E6-0000-0000-C000-000000000046}"
    static IID_IDataObject   := "{0000010E-0000-0000-C000-000000000046}"
    static ID_FIRST := 1

    SplitPath(paths[1], , &dir1)
    for p in paths {
        SplitPath(p, , &dir)
        if (dir != dir1)
            throw Error("別々のフォルダにある項目はまとめて扱えません")
    }

    pidls := [], hMenu := 0, parent := 0
    try {
        children := Buffer(A_PtrSize * paths.Length)
        for i, p in paths {
            DllCall("shell32\SHParseDisplayName", "wstr", p, "ptr", 0, "ptr*", &pidl := 0, "uint", 0, "ptr", 0, "hresult")
            pidls.Push(pidl)
            ; 末尾のIDは親フォルダからの相対IDとしてそのまま使える
            NumPut("ptr", DllCall("shell32\ILFindLastID", "ptr", pidl, "ptr"), children, (i - 1) * A_PtrSize)
        }
        parent := DllCall("shell32\ILClone", "ptr", pidls[1], "ptr")
        DllCall("shell32\ILRemoveLastID", "ptr", parent)

        DllCall("shell32\SHBindToParent", "ptr", pidls[1], "ptr", GuidBuffer(IID_IShellFolder), "ptr*", &pSF := 0, "ptr", 0, "hresult")
        sf := ComValue(13, pSF)     ; 13 = VT_UNKNOWN。抜けるときに自動で Release される
        if (handler != "") {
            ComCall(10, sf, "ptr", hwnd, "uint", paths.Length, "ptr", children
                , "ptr", GuidBuffer(IID_IDataObject), "ptr", 0, "ptr*", &pDO := 0)  ; GetUIObjectOf
            dataObj := ComValue(13, pDO)
            ext := ComObject(handler, IID_IShellExtInit)
            ComCall(3, ext, "ptr", parent, "ptr", dataObj, "ptr", 0)               ; Initialize
            cm := ComObjQuery(ext, IID_IContextMenu)
        } else {
            ComCall(10, sf, "ptr", hwnd, "uint", paths.Length, "ptr", children
                , "ptr", GuidBuffer(IID_IContextMenu), "ptr", 0, "ptr*", &pCM := 0)  ; GetUIObjectOf
            cm := ComValue(13, pCM)
        }
        hMenu := DllCall("CreatePopupMenu", "ptr")
        ComCall(3, cm, "ptr", hMenu, "uint", 0, "uint", ID_FIRST, "uint", 0x7FFF, "uint", 0)  ; QueryContextMenu

        if !MenuHasTextItem(hMenu)
            return "empty"
        found := FindMenuItemByText(hMenu, cmdText)
        if !found
            return "notfound"
        if found.checked
            return "already"
        if !invoke
            return "ok"

        ; CMINVOKECOMMANDINFO（lpVerb にコマンドIDのオフセットを渡す）
        ci := Buffer(16 + 5 * A_PtrSize, 0)
        NumPut("uint", ci.Size, ci, 0)
        NumPut("ptr", hwnd, ci, 8)
        NumPut("ptr", found.id - ID_FIRST, ci, 8 + A_PtrSize)
        NumPut("int", 1, ci, 8 + 4 * A_PtrSize)                                 ; SW_SHOWNORMAL
        ComCall(4, cm, "ptr", ci)                                                ; InvokeCommand
        return "ok"
    } finally {
        if hMenu
            DllCall("DestroyMenu", "ptr", hMenu)
        if parent
            DllCall("ole32\CoTaskMemFree", "ptr", parent)
        for pidl in pidls
            DllCall("ole32\CoTaskMemFree", "ptr", pidl)
    }
}

; メニュー（サブメニューも含む）から表示文字列が text の項目を探す。
; 「(&E)」や「&」は除いて比べる（項目名にアクセラレータが付いていても付いていなくても当たる）。
; 戻り値: {id, checked} / 見つからなければ ""
FindMenuItemByText(hMenu, text) {
    text := StripMenuAccel(text)
    Loop DllCall("GetMenuItemCount", "ptr", hMenu, "int") {
        pos := A_Index - 1
        if (sub := DllCall("GetSubMenu", "ptr", hMenu, "int", pos, "ptr")) {
            if (found := FindMenuItemByText(sub, text))
                return found
            continue
        }
        buf := Buffer(512, 0)
        DllCall("GetMenuStringW", "ptr", hMenu, "uint", pos, "ptr", buf, "int", 256, "uint", 0x400)  ; MF_BYPOSITION
        if (StripMenuAccel(StrGet(buf)) = text) {
            state := DllCall("GetMenuState", "ptr", hMenu, "uint", pos, "uint", 0x400)
            return { id: DllCall("GetMenuItemID", "ptr", hMenu, "int", pos, "int"), checked: !!(state & 0x8) }  ; MF_CHECKED
        }
    }
    return ""
}

; メニュー項目名からアクセラレータの表記（末尾の「(&E)」と「&」）を除く
StripMenuAccel(text) {
    return Trim(RegExReplace(text, "\(&.\)$|&", ""))
}

; 文字のある項目が1つでもあるか（区切り線だけなら false）
MenuHasTextItem(hMenu) {
    Loop DllCall("GetMenuItemCount", "ptr", hMenu, "int")
        if DllCall("GetMenuStringW", "ptr", hMenu, "uint", A_Index - 1, "ptr", 0, "int", 0, "uint", 0x400) > 0
            return true
    return false
}

GuidBuffer(str) {
    buf := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", str, "ptr", buf, "hresult")
    return buf
}


CreateFolders(folderNames) {
    basePath := GetCurrentExplorerPath()
    ; ベースパスの末尾に「\」がない場合は自動で付け足す（パス結合のエラー防止）
    if (SubStr(basePath, -1) != "\") {
        basePath .= "\"
    }
    createdCount := 0 ; 実際に作成できた数を数えるための変数
    ; 配列の中身を1つずつ取り出してループ処理
    for index, folderName in folderNames {
        targetPath := basePath . folderName ; 作成先のフルパスを作る

        ; フォルダがまだ存在していない場合のみ作成を実行
        if !DirExist(targetPath) {
            try {
                DirCreate(targetPath)
                createdCount++
            } catch as err {
                ; アクセス権限などで失敗した場合はエラーメッセージを出す
                MsgBox("フォルダの作成に失敗しました:`n" targetPath "`n`n原因: " err.Message)
            }
        }
    }
    ; 作成した数を呼び出し元に返す
    return createdCount
}

#HotIf
;;
;; BS → Del（ファイル一覧にフォーカスがあるときだけ）
;;
;;   エクスプローラーの既定では BS は「戻る」だが、戻るは Alt+← を使うので
;;   削除に振り替える。名前の変更（インラインのEdit）・アドレスバー・
;;   検索ボックスでは素の BS が要るため、一覧にいるときだけ差し替える。
;;
;;   判定はホワイトリスト（DirectUIHWND 等）にする。「Edit なら通す」という
;;   ブラックリストにしないのは、Win11 の検索ボックスが Edit ではなく XAML で
;;   拾えないため。取得に失敗したときも false に倒して素の BS を通す。
;;
;;   ファイルダイアログ（「名前を付けて保存」「開く」など）も同じにする。
;;   一覧の中身はエクスプローラーと同じ DirectUIHWND なので判定は共通。
;;   ファイル名の入力欄は Edit なので、そこでは素の BS が通る。
;;;;

#HotIf (WinActive(class_explorer) || IsFileDialog()) && IsShellListFocused()

BS::Send("{Del}")

#HotIf

; フォーカスがファイル一覧またはナビゲーションウィンドウにあるか。
; どちらも DirectUIHWND。SysListView32 / SysTreeView32 は旧来の表示用の保険。
IsShellListFocused() {
    static listClasses := ["DirectUIHWND", "SysListView32", "SysTreeView32"]
    try {
        hwnd := ControlGetFocus("A")
        if (!hwnd)
            return false
        cls := WinGetClass("ahk_id " hwnd)
        for name in listClasses {
            if (InStr(cls, name) = 1)
                return true
        }
    }
    return false
}
