; 参考 https://qiita.com/ryoheiszk/items/092cc5d76838cb5a13f1
; 「~ (チルダ)」を付けると、OS標準のCtrl+Sがそのまま素通りして実行される。わざわざ Send("^s") で送り直す必要がなくなり、無限ループの危険も防げる。

#Requires AutoHotkey v2.0
#SingleInstance Force

; 連続入力の警告を出にくくする設定
A_HotkeyInterval := 2000
A_MaxHotkeysPerInterval := 200

; ウィンドウタイトルの部分一致を有効にする
SetTitleMatchMode(2)

global pr_exe := "ahk_exe Adobe Premiere Pro.exe"
global ai_exe := "ahk_exe Illustrator.exe"
global ps_exe := "ahk_exe Photoshop.exe"
global au_exe := "ahk_exe Adobe Audition.exe"
global ae_exe := "ahk_exe AfterFX.exe"
global bl_exe := "ahk_exe blender.exe"
global pureref_exe := "ahk_exe PureRef.exe"

#Include "lib\Functions.ahk"
#Include "lib\Hotstring.ahk"
#Include "lib\Laptop.ahk"
#Include "lib\Mouse.ahk"
#Include "lib\Onishi.ahk"
#Include "lib\Tenkey.ahk"
#Include "apps\Common.ahk"
#Include "apps\AdobeCommon.ahk"
#Include "apps\Illustrator.ahk"
#Include "apps\Premiere.ahk"