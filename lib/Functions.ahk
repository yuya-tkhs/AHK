; duration はミリ秒（ToolTipEx の TimeOut は秒のため変換）
MyTooltip(text := "", duration := 300) {
    if (text = "")
        ToolTipEx()
    else
        ToolTipEx(text, duration / 1000)
}

toggleOnishiAndTenkey() {
    toggleTenkeyMode()
    toggleOnishiMode()
}