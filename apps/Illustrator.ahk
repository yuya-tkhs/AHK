;;
;; Illustrator
;;;;
; 10秒ごとにチェックを開始（ミリ秒指定）
SetTimer(CheckIllustrator, 10000)
CheckIllustrator() {
    ; Illustratorが実行中か確認（プロセス名で判定）
    if ProcessExist("Illustrator.exe") {
        if !ProcessExist("sppy_1_5.exe") {
            Run("W:\マイドライブ\Programming\Sppy_1_5\Sppy_1_5.exe")
        }
    }
}