; 参考 https://qiita.com/ryoheiszk/items/092cc5d76838cb5a13f1
; 「~ (チルダ)」を付けると、OS標準のCtrl+Sがそのまま素通りして実行される。わざわざ Send("^s") で送り直す必要がなくなり、無限ループの危険も防げる。

#Requires AutoHotkey v2.0
#SingleInstance Force

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
global exe_bl := "ahk_exe blender.exe"
global exe_pureref := "ahk_exe PureRef.exe"
global class_explorer := "ahk_class CabinetWClass"

#Include "lib\Functions.ahk"
#Include "lib\Hotstring.ahk"
#Include "lib\Laptop.ahk"
#Include "lib\Mouse.ahk"
#Include "lib\Onishi.ahk"
#Include "lib\Tenkey.ahk"
#Include "apps\Common.ahk"
#Include "apps\Explorer.ahk"
#Include "apps\AdobeCommon.ahk"
#Include "apps\Illustrator.ahk"
#Include "apps\Premiere.ahk"