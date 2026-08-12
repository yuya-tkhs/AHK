;;
;; F19 / F20 / F21 / F22 のアプリ別割り当て
;;
;;   対象                       F19          F20          F21            F22
;;   -------------------------- ------------ ------------ -------------- --------------
;;   Adobe系（Pr/Ai/Ps/Au/Ae/Lr） 下 {Down}   上 {Up}      +{Tab}         {Tab}
;;   デスクトップ               表示縮小 ^-  表示拡大 ^+  無効           無効
;;   日本語入力中／メモ帳/VSCode 表示縮小 ^- 表示拡大 ^+  元に戻す ^z    やり直し ^+z
;;   　└ メモ帳                表示縮小 ^-  表示拡大 ^+  元に戻す ^z    やり直し ^y
;;   Chrome / エクスプローラー  表示縮小 ^-  表示拡大 ^+  前のタブ ^+Tab 次のタブ ^Tab
;;   デフォルト                 表示縮小 ^-  表示拡大 ^+  +{Tab}         {Tab}
;;
;; #HotIf を並べず1か所で分岐しているのは、AdobeCommon.ahk の OnCtrlEnterPost() と同じ理由。
;; 「デフォルト＋例外」という優先順位がコード上で一目で分かるため。
;;;;

; $ を付けてキーボードフック経由にする。
; 付けないと環境によっては F19〜F22 自体がアプリに届いてしまい、
; ショートカットと元のキーの両方が送られたように見える。
$F19:: AppKey( "F19" )
$F20:: AppKey( "F20" )
$F21:: AppKey( "F21" )
$F22:: AppKey( "F22" )

AppKey( key ) {
    ; Adobe系：4キーすべて専用の割り当て
    ; Tab / Shift+Tab はどのAdobeアプリでもパネルの表示切り替えで共通
    if IsAdobeApp() {
        switch key {
            case "F19": Send( "{Down}" )
            case "F20": Send( "{Up}" )
            case "F21": Send( "+{Tab}" )
            case "F22": Send( "{Tab}" )
        }
        return
    }

    ; F19/F20（表示倍率）はアプリを問わず共通。
    ; ^+ は Ctrl+Shift と解釈されるため、+ は必ず {} で囲む。
    if ( key = "F19" || key = "F20" ) {
        Send( key = "F19" ? "^-" : "^{+}" )
        return
    }

    ; --- ここから F21 / F22 ---

    ; デスクトップ：何もしない。
    ; ここでの ^z はファイル操作（移動・削除・リネーム）の巻き戻しになり
    ; 誤操作の影響が大きいため、意図的に無効化している。
    if IsDesktop() {
        return
    }
    ; 日本語入力中、またはテキスト編集用アプリ：元に戻す／やり直し
    if ( IsTextEditApp() || IsImeOn() ) {
        SendUndoRedo( key )
        return
    }
    ; タブを持つアプリ：タブ切り替え
    if IsTabSwitchApp() {
        Send( key = "F21" ? "^+{Tab}" : "^{Tab}" )
        return
    }
    ; デフォルト：素の Tab / Shift+Tab（フォーカス移動・パネル送り）
    Send( key = "F21" ? "+{Tab}" : "{Tab}" )
}

; 元に戻す／やり直しを送る。メモ帳だけ ^+z が効かないため ^y にする。
SendUndoRedo( key ) {
    if WinActive( exe_notepad )
        Send( key = "F21" ? "^z" : "^y" )
    else
        Send( key = "F21" ? "^z" : "^+z" )
}

; 日本語入力（IME）がONかどうか＝長文を書いている最中かの判断に使う。
; Chrome / VSCode などの Electron 系でも取得できることを実測で確認済み。
; （CaretGetPos によるキャレット判定は Chrome がアドレスバーでも false を返すため使えない）
;
; 生の DllCall("SendMessage") は相手アプリが応答するまで戻らず、重いアプリでは
; キーの反応が遅れる。AHK の SendMessage() は内部で SendMessageTimeout を使うため、
; 短いタイムアウトを指定して「応答が無ければ即座に諦める」ようにしている。
IsImeOn() {
    static WM_IME_CONTROL := 0x283, IMC_GETOPENSTATUS := 0x0005, TIMEOUT := 80
    hWnd := WinExist( "A" )
    if !hWnd
        return false
    hIME := DllCall( "imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr" )
    if !hIME
        return false
    try
        return SendMessage( WM_IME_CONTROL, IMC_GETOPENSTATUS, 0, , "ahk_id " hIME, , , , TIMEOUT ) != 0
    catch
        return false   ; タイムアウト時は「入力中でない」側に倒してキーを待たせない
}

; 常に元に戻す／やり直しを割り当てるアプリ（テキスト編集が主目的のもの）。
; 入力していない間も取り消しを効かせたいアプリはここに1行足す。
IsTextEditApp() {
    return WinActive( exe_notepad )
        || WinActive( exe_code )
}

; Adobe系アプリが前面かどうかを判定する
IsAdobeApp() {
    return WinActive( exe_pr )
        || WinActive( exe_ai )
        || WinActive( exe_ps )
        || WinActive( exe_au )
        || WinActive( exe_ae )
        || WinActive( exe_lr )
}

; デスクトップが前面かどうかを判定する。
; 通常は Progman、壁紙スライドショー中は WorkerW が前面になる。
IsDesktop() {
    return WinActive( class_desktop )
        || WinActive( class_desktop_alt )
}

; Ctrl+Tab でタブを切り替えられるアプリが前面かどうかを判定する
IsTabSwitchApp() {
    return WinActive( exe_chrome )
        || WinActive( class_explorer )
}
