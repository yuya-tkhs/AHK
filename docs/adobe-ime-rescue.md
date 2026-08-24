# Adobe系アプリ「日本語入力のままツールキーを押した」の自動救済

AutoHotkey v2 用。Illustrator や Premiere で **IMEがONのままツールのショートカット（`V` など）を押すと、打鍵がIMEの未確定文字列に吸われてツールが切り替わらない**問題を、自動で救済する仕組みです。

このファイルをそのまま Claude に渡して「これを実装して」と依頼すれば動くように書いてあります。

---

## 何が起きるか

1. IMEがONのまま `V` を押す
2. 約120ms後、AHKが「打鍵が吸われた」ことを検出する
3. `Esc`（未確定文字列を破棄）→ `無変換`（IMEをOFF）→ `V` を送り直す
4. ツールチップで「IME OFF → V」と知らせる

体感は「一瞬 `ｖ` が出て、すぐ消えて選択ツールに切り替わる」です。押し直す必要がなくなります。

---

## 核心：どうやって「救済すべき状況」を判定するか

**`CiceroUIWndFrame` という窓の存在で判定します。**

これは Windows の TSF（Text Services Framework、開発コード名 Cicero）が作る**浮動の変換窓**です。アプリ側にテキスト入力先が無いとき、IMEは未確定文字列を表示する場所が無いため、この窓を出します。逆にテキスト入力先があるときはインライン変換になるので出ません。

つまり、

> `CiceroUIWndFrame` が在る ＝ 変換中 **かつ** テキスト入力先が無い ＝ 打鍵が宙に浮いている

Illustrator で実測した結果（IMEは ATOK 36）：

| 状況 | 出る窓 | 救済すべきか |
|------|--------|------|
| キャンバス上のテキスト編集中 | `ATOK36Cand` のみ | ✗ しない |
| パネルの入力欄（レイヤー名・アートボード名・数値欄） | `ATOK36Cand` ＋ `MSCTFIME Composition` | ✗ しない |
| テキスト入力先が無い | **`CiceroUIWndFrame`** | ✓ する |

`CiceroUIWndFrame` は未確定文字列を表示する窓なので、**幅が1文字あたり約11px増える**のも確認済みです。

表の `ATOK36Cand` はATOK固有の窓です。**他のIME（MS-IMEなど）では別のクラス名が並びます**が、判定に使うのは `CiceroUIWndFrame` だけなので、そこは違っていて構いません。見るべきは「テキスト入力中に `CiceroUIWndFrame` が出ないこと」の一点です。

### この判定が優れている点

素朴な代案に「同じキーを2回連打したら救済する」がありますが、**これは日本語入力を壊します**。ローマ字入力では子音の2連打が正常な入力だからです（「って」= `t,t,e` / 「かっこ」= `k,k,o`）。`t`（文字ツール）`s`（スケール）`p`（ペン）などが該当し、2連打方式では対象キーを大きく絞る必要が出ます。

窓で判定すればテキスト入力中は発動しないので、**1打目から救済でき、対象キーを全ツールキーに広げられます**。

---

## あなたの環境で最初に確認すること

**必ず実装前に確認してください。** 5分で済みます。

`CiceroUIWndFrame` は Windows の TSF が作る窓なので、原理的にはIME製品に依存しません（MS-IMEでも Google日本語入力でも出るはず）。ただし**実測で確認できているのは ATOK 36 + Illustrator の組み合わせだけ**です。他のIMEやアプリで同じ出方をする保証はないので、下のスクリプトで自分の環境を確かめてから実装してください。

ここを飛ばして誤爆すると、**テキスト入力中に `Esc` が送られて入力中の文字が消えます**。

### 確認用スクリプト

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
DetectHiddenWindows true

logFile := A_Desktop "\ime_probe.txt"
try FileDelete(logFile)

Dump(label) {
    global logFile
    s := label "`n"
    for hwnd in WinGetList() {
        try {
            if !(WinGetStyle(hwnd) & 0x10000000)   ; 可視のものだけ
                continue
            cls := WinGetClass(hwnd)
            if !RegExMatch(cls, "i)Cicero|ATOK|IME|Composition|Candidate|MSCTF")
                continue
            WinGetPos(&x, &y, &w, &h, hwnd)
            if (w = 0 && h = 0)
                continue
            s .= "    " cls "  " w "x" h "  proc=" WinGetProcessName(hwnd) "`n"
        }
    }
    FileAppend(s, logFile, "UTF-8")
}

ToolTip("計測中【40秒】")
~*v::      SetTimer(() => Dump("--- v を押した150ms後 ---"), -150)
~*Escape:: SetTimer(() => Dump("--- Esc を押した150ms後 ---"), -150)
Sleep(40000)
ToolTip()
MsgBox("デスクトップの ime_probe.txt を確認してください")
ExitApp 0
```

対象アプリをアクティブにして、**日本語入力ONのまま**次を行います。

1. テキスト編集中（文字ツールでカーソルが点滅している状態）で `v` を押す → 3秒待つ → `Esc`
2. テキスト編集していない状態で `v` を押す → 3秒待つ → `Esc`

**2 でだけ `CiceroUIWndFrame` が出れば、この方式が使えます。** 1 でも出るなら、テキスト入力中に誤爆するので採用してはいけません。

---

## 実装コード

そのまま動く自己完結版です。

```ahk
#Requires AutoHotkey v2.0

; ===== 設定 =====

; 対象アプリ。必要に応じて増減する
IsTargetApp() {
    return WinActive("ahk_exe Illustrator.exe")
        || WinActive("ahk_exe Photoshop.exe")
        || WinActive("ahk_exe Adobe Premiere Pro.exe")
        || WinActive("ahk_exe AfterFX.exe")
}

; 打鍵から窓が出るまで実測約60ms。余裕をみて120ms待ってから判定する
global ImeRescueDelay := 120

; ===== 本体 =====

; 打鍵の直後はまだ窓が無いので、少し待ってから判定する
ScheduleImeRescue(key, shift, *) {
    global ImeRescueDelay
    SetTimer(ImeRescueCheck.Bind(key, shift), -ImeRescueDelay)
}

ImeRescueCheck(key, shift) {
    if !IsTargetApp()
        return
    ; 可視の窓だけを探したいので DetectHiddenWindows は既定(Off)のまま使う。
    ; ahk_pid で絞るのは、他プロセスの CiceroUIWndFrame に反応しないため
    if !WinExist("ahk_class CiceroUIWndFrame ahk_pid " WinGetPID("A"))
        return
    Send("{Escape}")                        ; 未確定文字列を破棄
    Sleep(40)
    Send("{vk1D}")                          ; 無変換＝半角英数へ
    Sleep(40)
    Send((shift ? "+" : "") "{" key "}")    ; 本来やりたかったツール切り替え
    ShowImeRescueTip("IME OFF → " (shift ? "Shift+" : "") ImeRescueKeyLabel(key))
}

; 記号キーは "vkBA" のままだと何のキーか分からないので、実際の文字に直す。
; 対応表を手書きするとキーを足したときにずれるので、OSに引かせる
ImeRescueKeyLabel(key) {
    if (SubStr(key, 1, 2) != "vk")
        return StrUpper(key)
    code := DllCall("MapVirtualKeyW", "UInt", Integer("0x" SubStr(key, 3)), "UInt", 2, "UInt")
    return code ? Chr(code & 0x7FFF) : key
}

ShowImeRescueTip(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -1200)
}

; 対象キー：文字を生むキーすべて（英字・数字・記号）。
; 判定が厳密なのでキーを絞る必要がない。
; 記号は「^」がAHKの修飾キー記号と紛れるため vk コードで指定する。
; ※ 下の記号リストは【JIS配列】前提。US配列なら見直すこと
ImeRescueKeys() {
    keys := []
    for k in StrSplit("abcdefghijklmnopqrstuvwxyz")
        keys.Push(k)
    Loop 10                                  ; 0〜9
        keys.Push("vk" Format("{:X}", 0x30 + A_Index - 1))
    ; BA(:) BB(;) BC(,) BD(-) BE(.) BF(/) C0(@) DB([) DC(\) DD(]) DE(^) E2(\)
    for vk in ["BA", "BB", "BC", "BD", "BE", "BF", "C0", "DB", "DC", "DD", "DE", "E2"]
        keys.Push("vk" vk)
    return keys
}

; 「~」付き＝キーはアプリにもそのまま流す（救済しないときは何も変えない）。
; Shift併用（Shift+M など）もツールキーなので両方登録する。
; Ctrl / Alt 併用はIMEに吸われないので対象外＝「*」は付けない。
HotIf((*) => IsTargetApp())
for _imeKey in ImeRescueKeys() {
    Hotkey("~" _imeKey, ScheduleImeRescue.Bind(_imeKey, false))
    Hotkey("~+" _imeKey, ScheduleImeRescue.Bind(_imeKey, true))
}
HotIf()
```

---

## 設計上の判断と、その理由

実装を変更するときに壊しやすい点です。

| 判断 | 理由 |
|------|------|
| **常駐 `InputHook` を使わない** | 全打鍵を経由させると体感できる入力遅延が出る。ホットキーは押されたときだけ動くので影響がない |
| **`Esc` を `無変換` より先に送る** | 変換中に無変換を送ると**カタカナ変換として食われてIMEが切れない**ことがある。先に未確定を破棄する |
| **打鍵から120ms待つ** | 窓が出るのは打鍵の約60ms後。押した瞬間に判定しても窓がまだ無い |
| **`~` を付ける** | キーを抑制しない。救済しない場面（IME OFF時など）でアプリの動作を一切変えないため |
| **`*` は付けない** | `Ctrl+S` などはIMEに吸われないので救済不要。無駄な判定を増やさない |
| **`ahk_pid` で絞る** | TSFを使う他プロセスも `CiceroUIWndFrame` を持ちうる |
| **`CaretGetPos()` を使わない** | テキスト入力中かの判定に使えない。Win32では効くが Chrome はアドレスバーにフォーカスしていても false を返す |

判定コストは実測 **0.07ms/回** で、常用して問題ありません。

---

## うまく動かないときは

| 症状 | 原因の候補 |
|------|-----------|
| 何も起きない | 対象アプリの `ahk_exe` 名が違う／確認用スクリプトで `CiceroUIWndFrame` が出るか要確認 |
| 特定のキーだけ効かない | そのキーが `ImeRescueKeys()` に無い。テンキーや `Space` は既定で対象外 |
| 記号キーで違う文字が入る | US配列など、vkコードと文字の対応が違う。確認用スクリプトの要領で `MapVirtualKey` の結果を確認する |
| テキスト入力中に誤爆する | そのアプリではテキスト入力中も `CiceroUIWndFrame` が出ている。**この方式は使えない**ので、対象アプリから外す |
| IMEが切れずカタカナになる | `Esc` と `無変換` の間隔（40ms）を延ばす |
| 切り替わりが一拍遅い | `ImeRescueDelay` を詰める。ただし短すぎると窓が出る前に判定してしまう |

---

## 検証済みの環境

- Windows 11
- AutoHotkey v2.0.19
- IMEは ATOK 36。`CiceroUIWndFrame` は Windows の TSF が作る窓なのでIME製品には依存しないはずだが、**他IMEでは未検証**（だからこそ上の確認手順を必ず通すこと）
- 日本語（JIS）キーボード
- Adobe Illustrator（Premiere でも動作。Photoshop / After Effects は未検証）
