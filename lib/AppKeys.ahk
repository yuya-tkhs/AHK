;;
;; F19 / F20 / F21 / F22 のアプリ別割り当て
;;
;;   対象                       F19          F20          F21            F22
;;   -------------------------- ------------ ------------ -------------- --------------
;;   Adobe系（Pr/Ai/Ps/Au/Ae/Lr） +{Tab}      {Tab}        下 {Down}      上 {Up}
;;   デスクトップ               表示縮小 ^-  表示拡大 ^+  無効           無効
;;   Chrome / エクスプローラー  表示縮小 ^-  表示拡大 ^+  前のタブ ^+Tab 次のタブ ^Tab
;;   メモ帳                     表示縮小 ^-  表示拡大 ^+  元に戻す ^z    やり直し ^y
;;   デフォルト                 表示縮小 ^-  表示拡大 ^+  元に戻す ^z    やり直し ^+z
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
            case "F19": Send( "+{Tab}" )
            case "F20": Send( "{Tab}" )
            case "F21": Send( "{Down}" )
            case "F22": Send( "{Up}" )
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
    ; タブを持つアプリ：タブ切り替え
    if IsTabSwitchApp() {
        Send( key = "F21" ? "^+{Tab}" : "^{Tab}" )
        return
    }
    ; メモ帳：やり直しが ^+z ではなく ^y
    if WinActive( exe_notepad ) {
        Send( key = "F21" ? "^z" : "^y" )
        return
    }
    ; デフォルト：元に戻す／やり直し
    Send( key = "F21" ? "^z" : "^+z" )
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
