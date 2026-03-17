

;;
;; 無変換関連
;;;;
vk1D::Send("{vk1D}")
vk1D & LButton:: Click 2
vk1D & vk1C::    Send("{vk1C}")
vk1D & Up::      Send("{Blind}{Up 5}")
vk1D & Down::    Send("{Blind}{Down 5}")
vk1D & Right::   Send("{Blind}{Right 5}")
vk1D & Left::    Send("{Blind}{Left 5}")
vk1D & Enter:: {
    if GetKeyState("Ctrl", "P")
        Send("{Up}{End}{Enter}")
    else
        Send("{End}{Enter}")
}

;;行削除
vk1D & BS:: Send("{Home}+{End}+{Right}{BS}")

;;実行しているスクリプトのReload
#HotIf GetKeyState("vk1D", "P")
+^!r:: Reload
#HotIf

~Esc:: {
    ; 前回発動したホットキーが「~Esc」で、かつ前回からの経過時間が300ミリ秒未満なら
    if (A_PriorHotkey == "~Esc" && A_TimeSincePriorHotkey < 500) {
        Send("{vk1D}")  ; 無変換キーを送信
    }
}

OnClipboardChange(OnClipChanged)
OnClipChanged(DataType) {
    ; DataTypeには 0(空), 1(テキスト), 2(画像などのファイル) が入ります
    my_tooltip_function("コピー", 600)
}

~^s:: {
    ; 「~ (チルダ)」を付けると、OS標準のCtrl+Sがそのまま素通りして実行される。
    ; わざわざ Send("^s") で送り直す必要がなくなり、無限ループの危険も防げる。
    my_tooltip_function("上書き保存", 600)
}