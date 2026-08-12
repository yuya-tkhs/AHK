; 参考 https://qiita.com/ryoheiszk/items/092cc5d76838cb5a13f1
; 「~ (チルダ)」を付けると、OS標準のCtrl+Sがそのまま素通りして実行される。わざわざ Send("^s") で送り直す必要がなくなり、無限ループの危険も防げる。

#Requires AutoHotkey v2.0
#SingleInstance Force

; #SingleInstance Force が旧インスタンスの置き換えに失敗したときの保険。
; 二重常駐すると「~」付きホットキーが両方で発火し、片方のInputHookが
; 取り残されて打鍵を横取りする（詳細は KillDuplicateInstances のコメント）。
; ツールチップは読み込み完了後に出したいのでタイマーで遅らせる。
dup := KillDuplicateInstances()
if (dup.killed || dup.survived) {
    dupMsg := dup.killed ? "取り残された常駐を終了しました（" dup.killed "件）" : ""
    if (dup.survived)   ; 権限差などで落とせなかった。放置すると打鍵を横取りされ続ける
        dupMsg .= (dupMsg ? "`n" : "") "⚠ 終了できない常駐が " dup.survived " 件あります。手動で終了してください"
    SetTimer(() => MyTooltip(dupMsg, 4000), -1500)
}

; 連続入力の警告を出にくくする設定
A_HotkeyInterval := 2000
A_MaxHotkeysPerInterval := 200

; ウィンドウタイトルの部分一致を有効にする
SetTitleMatchMode(2)

global exe_pr := "ahk_exe Adobe Premiere Pro.exe"
global exe_ai := "ahk_exe Illustrator.exe"
global exe_ps := "ahk_exe Photoshop.exe"
global exe_au := "ahk_exe Adobe Audition.exe"
global exe_ae := "ahk_exe AfterFX.exe"
; Lightroom Classic。SetTitleMatchMode(2) の部分一致により
; 「Adobe Lightroom.exe」（CC版）も同じ識別子で拾える
global exe_lr := "ahk_exe Lightroom.exe"
global exe_bl := "ahk_exe blender.exe"
global exe_pureref := "ahk_exe PureRef.exe"
global exe_chrome := "ahk_exe chrome.exe"
global exe_notepad := "ahk_exe notepad.exe"
global exe_code := "ahk_exe Code.exe"
global class_explorer := "ahk_class CabinetWClass"
; デスクトップ。通常は Progman、壁紙スライドショー中は WorkerW が前面になる
global class_desktop := "ahk_class Progman"
global class_desktop_alt := "ahk_class WorkerW"

#Include "lib\ToolTipEx.ahk"
#Include "lib\Functions.ahk"
#Include "lib\Hotstring.ahk"
#Include "lib\Mouse.ahk"
#Include "lib\ScrollKeys.ahk"
#Include "lib\AppKeys.ahk"
#Include "apps\Premiere.ahk"
#Include "apps\Common.ahk"
#Include "apps\Explorer.ahk"
#Include "apps\AdobeCommon.ahk"
#Include "apps\Illustrator.ahk"
#Include "apps\IllustratorLauncher.ahk"