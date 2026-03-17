;;
;; 「ddd」と入力されたら今日の日付 (MMDD形式) を挿入
;;;;
:*C:ddd:: {
    ; 今日の日付を取得、2桁にフォーマット、MMDDを作成
    thisMonth := Format("{:02}", A_MM)
    thisDay := Format("{:02}", A_DD)
    currentDate := thisMonth . thisDay
    ; 現在のカーソル位置に日付を貼り付け
    Send(currentDate)
    return
}