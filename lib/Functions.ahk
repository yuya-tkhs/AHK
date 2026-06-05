; duration はミリ秒（ToolTipEx の TimeOut は秒のため変換）
MyTooltip(text := "", duration := 300) {
    if (text = "")
        ToolTipEx()
    else
        ToolTipEx(text, duration / 1000)
}

ClickImageAndReturn(imgPath, notFoundMsg) {
    if ImageSearch(&imgX, &imgY, 0, 0, A_ScreenWidth, A_ScreenHeight, "*100 " imgPath) {
        MouseGetPos(&origX, &origY)
        Click imgX, imgY
        MouseMove origX, origY
    } else
        MyTooltip(notFoundMsg, 1500)
}