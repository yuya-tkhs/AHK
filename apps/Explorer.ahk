#HotIf WinActive("ahk_class CabinetWClass")

; 2ストローク
^Space:: {
    MyTooltip("
    (
    2ストローク待機中（5秒）
    - - - - - - - - - - - - - - - -
    Space: Rename
    r: PowerRename
    t: テキストファイルの作成
    c: 開いているフォルダのパスを取得
    g: Googleドライブの設定変更
    d: Downloadsの最新ファイルを移動
    - - - - - - - - - - - - - - - -
    1: 動画フォルダの作成
    2: Original, Proxy
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
        case "Space":  Send("{F2}")
        case "r":      Send("+{F10}p")
        case "t":      CreateTextFile()
        case "c":      RunGetExplorerPath()
        case "g":      GDriveOnline()
        case "d":      MoveFileHere()
        case "1":      CreateFolders(["01_Master","02_Assets","03_Works","04_Projects","05_Render"])
        case "2":      CreateFolders(["Original","Proxy"])
        default:       MyTooltip("無効なキーです", 500)
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

GDriveOnline() {
    Send("+{F10}")
    Sleep(250)
    Send("{g 2}{Up 2}{Right}")
}

CreateTextFile() {
    OpenBgMenu("w{Up 3}")
    Sleep(250)
    Send("{Enter}")
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
    return ""
}

OpenBgMenu( keysToSend := "" ) {
    ; 1. アクティブなタブの選択を全解除（Win11タブ対応）
    try {
        tab := GetActiveExplorerTab()
        if (tab != "") {
            for item in tab.Document.SelectedItems {
                tab.Document.SelectItem(item, 0)
            }
        }
    }
    Sleep(50)
    ; 2. 背景の右クリックメニューを出す
    Send("+{F10}")
    Sleep(250)
    ; 3. 引数で指定されたキーがあれば送信する
    if (keysToSend != "") {
        Send(keysToSend)
    }
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