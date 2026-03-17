my_tooltip_function(text, duration := 300) {
    ToolTip(text)
    ; マイナスの値を指定すると、指定ミリ秒後に1回だけ実行（ツールチップを消去）します
    SetTimer(() => ToolTip(), -duration) 
}