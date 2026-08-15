# AHK Personal Automation Suite

AutoHotkey v2.0 による個人用キーボード・アプリケーション自動化スクリプト群。

## プロジェクト構成

```
yuya_allways.ahk           # メインエントリポイント（全ファイルをinclude）
startup_manager.ahk        # 外付けドライブ接続時のアプリ自動起動（会社用）
startup_manager_home.ahk   # 同上（自宅用・TVClock追加）
apps/
  Common.ahk               # グローバルホットキー・2ストロークコマンド・クリップボード監視
  Explorer.ahk             # エクスプローラー／ファイルダイアログ拡張
  Premiere.ahk             # Adobe Premiere Pro ホットキー
  Illustrator.ahk          # Illustrator ホットキー・3ストローク・JSX連携
  IllustratorLauncher.ahk  # JSXを一覧から選んで実行するランチャー
  AdobeCommon.ahk          # Adobe共通の Ctrl+Enter 後処理をアプリ別に振り分け
lib/
  Functions.ahk            # 共通関数（MyTooltip, WrapText, IsUrl, CleanUrl, ClickImageAndReturn）
  Hotstring.ahk            # テキスト展開（ddd → 今日の日付MMDD / ttt → tkhs）
  Mouse.ahk                # 中クリックスクロール
  ScrollKeys.ahk           # F23/F24 によるキー加速スクロール
  AppKeys.ahk              # F19〜F22 のアプリ別割り当て（表示倍率／元に戻す／タブ切り替え）
  ToolTipEx.ahk            # ツールチップ描画の拡張
  run_ai_script.ahk        # JSXを別プロセスで実行する子スクリプト
images/                    # ImageSearch 用の参照画像（ai_OK.png 等）
```

## キーの表記

- `vk1D` = 無変換キー（日本語キーボード）
- `vk1C` = 変換キー（日本語キーボード）
- `F19` / `F20` = アプリ別割り当て（表示の縮小・拡大）
- `F21` / `F22` = アプリ別割り当て（元に戻す・やり直し／タブ切り替え）
- `F23` / `F24` = キー加速スクロール（下 / 上）

## 主要機能

### 2ストロークコマンド

いずれもトリガー後に `MyTooltip` でメニューを表示し、`InputHook` で次の1文字を待つ。

| 対象 | トリガー | 備考 |
|------|----------|------|
| グローバル（Common.ahk） | `vk1D + Space` | メニュー表示5秒／入力待ち2秒 |
| Explorer（Explorer.ahk） | `Ctrl + Space` | ファイルダイアログでも有効（`IsFileDialog()`で判定） |
| Premiere（Premiere.ahk） | `Ctrl + Space` | ファイルダイアログ中は無効 |
| Illustrator（Illustrator.ahk） | `Ctrl + Space` | 0.3秒以内の短押しのみ起動。長押しはAiにそのまま渡す。**3ストローク対応**（下記） |

- Illustrator で短押し判定を入れているのは、`Ctrl + Space` がAi本来のズームツールのため。長押しはそのままAiへ通す
- **グローバルとアプリ別を `Win + Space` ／ `vk1D + Space` に入れ替えたことがあるが、使い勝手が良くないため元に戻した**（2026-08-15）。Win+Space はWindows標準の入力方式切り替えと衝突する

#### Illustrator の3ストローク

メニューは `AiMenu`（apps/Illustrator.ahk 冒頭の配列）1か所で定義し、ツールチップの文言とキーの分岐を両方そこから生成する。追加・変更はこの配列だけを直す。

| 第2打鍵 | 内容 |
|---------|------|
| `b` | アートボード（移動 `f` / 追加 `a` / 中身を後ろへずらす `s` / 枠を作成 `m` / 名前変更 `2`） |
| `x` | 書き出し（`e` 10倍 / `E` 等倍） |
| `o` | オブジェクト（`t` テキストプロパティ / `g` 位置・サイズ） |
| `a` | 整列（`←→↑↓` 各方向 / `c` 水平中央 / `m` 垂直中央） |
| `j` | 文字揃え（`←` 左 / `→` 右 / `↑` 中央） |
| `e` `E` `t` `g` | 直接起動（`direct: true` の項目は第2打鍵だけで動く） |

- サブメニューは `Backspace` で第1階層へ戻る。`Escape` は全キャンセル
- `direct: true` を付けると第1階層のメニューにも並び、第2打鍵だけで起動できる。頻用になった項目はこれで「昇格」させる
- **矢印のように文字にならないキーは `InputHook` の `EndKey` にしないと拾えない。** `BuildAiEndKeys()` が項目キーの文字数（2文字以上＝特殊キー）から自動で組み立てる
- `ReadAiMenuKey()` は**ツールチップを描く前にフックを張る**。`Wait()` が返ってから次の `Start()` までの隙間に押されたキーはIllustratorへ素通りし、単キーがツール切替に化けるため

#### Premiere のメニューコマンド実行

ショートカットの無いメニュー項目は `MenuSelect()` で直接叩く（2ストロークの `c` = キャプションをグラフィックにアップグレード）。

```ahk
MenuSelect(exe_pr, , "グラフィックとタイトル", "キャプションをグラフィックにアップグレード")
```

- Premiereのメニューバーは**ネイティブのWin32メニュー**なので `MenuSelect()` が効く（実測確認済み）。アクセラレータ文字も `{Down}` の回数も要らず、項目が増減しても壊れない
- 項目名・メニュー名は**先頭からの部分一致**でよい。`(&G)` や末尾の `...` は書かなくて当たる
- **効いたかどうかをメニューのチェック状態やウィンドウの増減で判定してはいけない。** チェック状態はメニューを開くまで更新されず、ヘルプのようにブラウザで開く項目はPremiereのウィンドウ一覧に現れない。実測でどちらも「効いていないように見えて実際は効いていた」
- Premiere側でショートカットを割り当てた項目は `Send("+^!t")` のようにキーを送る方（2ストロークの `t`）。この場合Premiere側の割り当てを外すと動かなくなる
- メニュー構成を調べるには `GetMenu` / `GetSubMenu` / `GetMenuStringW` を `DllCall` で舐める。実行せずに項目名と並び順が取れる

### Illustrator の単独ホットキー（apps/Illustrator.ahk）

| キー | 動作 |
|------|------|
| `Alt + Enter` | MultiEditText.jsx（表示中は日本語入力ON） |
| `Shift + PgDn` | 次のアートボードを表示して全選択 |
| `Shift + PgUp` | 前のアートボードを表示して全選択 |

### JSXランチャー（apps/IllustratorLauncher.ahk）

Illustrator の2ストロークから `Space` で開く。文字入力で絞り込み、`↑↓` で選択、`Enter` で実行、`Escape` でキャンセル、`F5` で一覧を再構築する。

- 一覧は `AiMenu`（日本語ラベル付きの手書き定義）を先に並べ、続いてJSXフォルダを再帰列挙して `AiMenu` に無いものだけを足す。重複は相対パスで排除する
- `_aiLauncherExclude`（`test\`）は常に一覧に出さない。`_aiLauncherSearchOnly`（`あまり使わない\`）は**検索したときだけ**出す。既定の一覧を短く保ちつつ、名前を覚えていれば呼べる状態にしておくため。どちらも相対パスの前方一致
- 1列目はファイル名。半角のまま検索でき、ラベルを持たない列挙分とも表記が揃うため日本語ラベルより優先する。整列などメニューコマンドはコマンド名を出す
- 再帰列挙は実測16ms（キャッシュ後0ms）。Googleドライブ上でも問題にならない
- **ScriptUIで作ってはいけない。** ランチャー自身がJSXになるため多重起動ガード（`IsAiScriptRunning()`）を占有し続け、パネルを開いている間そこから何も起動できなくなる。表示中はIllustrator本体もブロックされる
- AHKのGUIはIllustratorからフォーカスを奪うが、**実行・キャンセルの直前に必ず `Hide()` → `WinActivate(exe_ai)` → `WinWaitActive` を通す**。アクティブ化の完了を待たずにJSXを起動すると、ダイアログが背面に出たりフォーカスを得られない。この往復でIllustratorの選択状態は失われない（実測確認済み）
- `Enter` / `↑↓` / `F5` は `HotIf AiLauncherActive` でランチャー表示中だけ有効にする。検索欄にフォーカスがあるため、上下は横取りしないとListViewへ届かない。`~` を付けないのは二重常駐時に両インスタンスで発火させないため
- 最近使ったものを先頭に出す（MRU・上限20件）。保存先は `%APPDATA%\AhkJsxLauncher\mru.txt`。リポジトリにもGoogleドライブにも置かないのは、使用履歴を版管理・同期の対象にしたくないため。並べ替えは絞り込みの**前**にかけるので、検索したときも最近使ったものが上に来る

### F19〜F22 のアプリ別割り当て（lib/AppKeys.ahk）

上から順に判定し、最初に一致したものが使われる。

| 対象 | F19 | F20 | F21 | F22 |
|------|-----|-----|-----|-----|
| Adobe系（Pr / Ai / Ps / Au / Ae / Lr） | 下 `{Down}` | 上 `{Up}` | `+{Tab}` | `{Tab}` |
| デスクトップ | 縮小 `^-` | 拡大 `^+` | 無効 | 無効 |
| 日本語入力中 | 縮小 `^-` | 拡大 `^+` | 元に戻す `^z` | やり直し `^+z` |
| 　└ メモ帳（常に） | 縮小 `^-` | 拡大 `^+` | 元に戻す `^z` | やり直し `^y` |
| Chrome / エクスプローラー / VSCode | 縮小 `^-` | 拡大 `^+` | 前のタブ `^+Tab` | 次のタブ `^Tab` |
| デフォルト | 縮小 `^-` | 拡大 `^+` | `+{Tab}` | `{Tab}` |

- Adobe系は `IsAdobeApp()` でまとめて判定する。Tab / Shift+Tab はどのAdobeアプリでもパネルの表示切り替えで共通のため
- 元に戻す／やり直しになるのは `IsImeOn()`（日本語入力ON）または `IsTextEditApp()`（メモ帳）のとき。それ以外はタブ切り替えや `Tab` になる
- VSCode は `IsTabSwitchApp()` に入れる。外すとデフォルトの素の `{Tab}` が送られ、エディタにインデントが挿入されてしまうため。日本語入力中は `IsImeOn()` が先に効くので取り消しになる
- `IsImeOn()` は `WM_IME_CONTROL` / `IMC_GETOPENSTATUS` で取得する。Chrome / VSCode などの Electron 系でも取得できることを実測済み
- **`SendMessage` は必ずタイムアウト付きで呼ぶ。** 生の `DllCall("SendMessage")` は相手アプリが応答するまで戻らず、重いアプリでキーの反応が遅れる。AHK の `SendMessage()` は内部で `SendMessageTimeout` を使うため、第9引数にタイムアウト（初期値80ms）を渡し、失敗時は false 側に倒す
- キャレットによる判定（`CaretGetPos()`）は**使えない**。Win32 では正しく効くが、Chrome はアドレスバーにフォーカスしていても false を返す（実測確認済み）
- **常駐 `InputHook` で打鍵時刻を記録する方式は、体感できる入力遅延が出たため廃止した。** 全打鍵を経由させる負荷が原因。判定はキー押下時にその場で調べる方式だけにする
- F21押下時の判定一式の実測コストは約 0.025ms（`IsImeOn()` 単体で 0.013ms）。ここは遅延の原因にならない
- メモ帳だけ `^+z` が効かないため、やり直しは `^y` を送る
- F19/F20 は Adobe系以外では共通（表示倍率）。`^+` は Ctrl+Shift と解釈されるため、Send では `^{+}` と `+` を波括弧で囲む
- デスクトップで F21/F22 を無効にしているのは、`^z` がファイル操作（移動・削除・リネーム）の巻き戻しになり誤操作の影響が大きいため。F19/F20 は無害なのでデフォルトのまま
- `#HotIf` を並べず `AppKey()` の中で分岐する。「デフォルト＋例外」の優先順位が一目で分かるため（`AdobeCommon.ahk` の `OnCtrlEnterPost()` と同じ方針）

### キー加速スクロール（lib/ScrollKeys.ahk）

| キー | 動作 |
|------|------|
| F23  | 下スクロール |
| F24  | 上スクロール |

- 単押しは `MIN_NOTCH`（初期値2ノッチ）、長押しは経過時間に応じて増え、約580msで上限に達する
- 速度は `AccelScroll()` 冒頭の `static` 定数（`REPEAT_DELAY` / `INTERVAL` / `RAMP_STEP` / `MIN_NOTCH` / `MAX_NOTCH`）で調整する
- 送信は `SendWheel()` が `mouse_event` で生のデルタ値（1ノッチ = 120単位）を送る。`Send "{WheelDown n}"` と違い 1.5 のような小数ノッチを扱えるため
- 多重起動ガードの `static` は上下で共有のため、同時に走るスクロールは1方向のみ

### 中クリックスムーズスクロール（lib/Mouse.ahk）

中ボタンを押しながらマウスを動かすと、動かした向きへ中身がついてくる（手のひらツールと同じ操作感）。

- `TICK`（初期値10ms）の固定周期ループ。`Sleep 0` のタイトループと違い出力間隔が一定になる
- マウスの生の移動量ではなく `SMOOTH` によるローパスフィルタを通した速度を送る。手のブレがならされ、止めた瞬間も指数的に減速する（慣性＝離した後の惰性スクロールは意図的に入れていない。狙った位置で止められなくなるため）
- 送信は `SendWheelDelta()` が `mouse_event` で小数ノッチを送り、1未満に丸められて消える端数は次のティックへ持ち越す
- 滑らかさの上限は送信先アプリ依存。Chrome / Edge / Electron など高精度ホイール対応アプリではピクセル単位で動くが、旧来の Win32 アプリはアプリ側が120単位に溜めるため段差は残る
- 縦横は `AXIS_HYST` ぶん優勢が続いた側へ切り替わる。縦に流している最中の横ブレで横スクロールに化けるのを防ぐため
- 感度の調整は `SmoothScroll()` 冒頭の `static` 定数（`TICK` / `PIXELS_PER_NOTCH` / `SMOOTH` / `MAX_NOTCH` / `AXIS_HYST`）で行う
- Ai / Ps / Au / Ae / Blender / PureRef は `#HotIf` で除外（各アプリ固有の中クリック操作を潰さないため）

### Illustrator の JSX 連携（apps/Illustrator.ahk）

- `RunAiMenuCommand()` は **JSXが存在しないIllustratorのメニューコマンド**（整列など）を実行する。`lib/run_ai_script.ahk` に `--code` を渡し、子プロセスが `DoJavaScript`（文字列実行）で `app.executeMenuCommand('...')` を叩く。共有ドライブにJSXファイルを作らずに済ませるため。コマンド名はIllustratorのメニューコマンド名（`Horizontal Align Left` など）。**JS側の引用符はシングルにする**（コマンドラインの二重引用符と衝突するため）
- JSXの起動はすべて `RunAiScriptAsync()` を通す。`lib/run_ai_script.ahk` を別プロセスで起動するので、ダイアログ表示中も本体がフリーズしない。COMで同期実行する版（`AiScript()`）はJSXが終わるまでホットキーが全部止まるため廃止した（追加コストは実測約30msしかなく、同期版を選ぶ理由がない）
- `RunAiScriptWithTooltip()` は完了通知をダイアログではなく `%TEMP%\ai_jsx_result.txt` 経由で受け取り `MyTooltip()` に出す。JSX側は `.tmp` に書いてから rename するので書きかけを読むことはない。**エンコーディングは JSX 側 `File.encoding`・AHK 側 `FileRead` とも `UTF-8` を明示する**（ExtendScript の既定は日本語Windowsでは Shift-JIS で、日本語のパスが化ける）。監視の停止条件は ①結果ファイル発見 ②子プロセス消滅＋猶予2回 ③絶対タイムアウト600秒 の3つ。②があるのでキャンセルやエラーで結果が書かれなくても確実に止まる
- ダイアログを出さない方式にしたのは、書き出しに時間がかかる間に待ちきれず押したEnterが、ダイアログがまだ無いためIllustrator本体に吸われて消え、結局押し直しになっていたため。確定操作そのものを不要にした
- **この方式のJSXをAHK以外（Illustratorのスクリプトメニュー等）から直接実行すると、完了通知が一切出ない**（結果は読み手のいない `%TEMP%` に書かれる）。JSXは共有ドライブにあり版管理外なので、他の人が使う可能性があるなら注意する
- ScriptUI（JSXの `new Window`）は標準のWin32コントロールを使わないため、**`WinGetText()` では中身が取れない**（実測確認済み・空が返る）。ダイアログ内のファイル名や保存先をAHK側で読むことはできないので、必要ならJSXにパスをファイル出力させてそれを読む
- ScriptUIのダイアログは `WinActivate` してから `Send("{Enter}")` で閉じられる（OKボタンが反応する。実測確認済み）。ただし `SetTitleMatchMode(2)` は部分一致なので、タイトル指定でEnterを送る処理を書くときは無関係のウィンドウに当たらないか確認すること
- WMIクエリ（`ComObjGet("winmgmts:")` の `Win32_Process` など）は実測125〜141msかかり、その間AHK全体が止まる。定期実行の中で毎回叩かないこと（かつてSppyの常駐監視で10秒ごとに叩いており、体感できる引っかかりの原因になっていた）
- 2ストロークの `switch` の前で `KeyWait` しない。Illustratorのcaseはどれも `Send` を使わないので衝突を避ける必要がなく、待つとキーを離すまでJSXの起動が始まらないため（`Common.ahk` 側は `Send` を使うので必要）

### 無変換（vk1D）の同時押し（apps/Common.ahk）

| キー | 動作 |
|------|------|
| `vk1D` 単押し | `{vk1D}` をそのまま送る（半角英数） |
| `vk1D + 左クリック` | ダブルクリック |
| `vk1D + vk1C` | `{vk1C}`（変換＝日本語入力ON） |
| `vk1D + ↑ / ↓ / ← / →` | その向きへ5回移動（`{Blind}` 付きで修飾キーは維持） |
| `vk1D + Enter` | 行末で改行。Ctrl併用で1行上の行末に改行 |
| `vk1D + BS` | 前方削除（カーソルから行頭まで） |
| `vk1D + Del` | 後方削除（カーソルから行末まで） |

- 矢印に `{Blind}` を付けているのは、Shift併用時に選択を伸ばす動作を保つため
- 削除系のもう一つとして `Ctrl+Shift+BS` に行削除（`{Home}+{End}+{Right}{BS}`）を割り当てている。行末の改行まで選択して消すため、次の行が繰り上がる

### その他のグローバル処理（apps/Common.ahk）

- `ResetStuckKeys()` … 1500ms間隔で修飾キーのスタック（論理ON・物理OFF）を検出して自動解除
- `OnClipboardChange` … コピーされたテキストがURLなら `CleanUrl()` で自動整形
- `MyTooltip()` は既定で60幅を超える行を `WrapText()` で折り返す。ネイティブのツールチップ（`tooltips_class32`）は**改行文字でしか折れず自動折り返しが無い**ため、長いパスやURLを出すと横に伸び続ける。全角を2・半角を1として数えるので日本語と英数が混ざっても見た目の幅がそろう。既定値60は2ストロークのメニュー（最長31）が折れない値
- `~Esc` … Escを押すたびに `{vk1D}`（無変換＝半角英数）を送る。`~` 付きなのでEsc自体は各アプリに素通しされる
  - **`~` 付きはキーを抑制しないので、2ストローク待機中もInputHookと両方に届いて両方発火する。** 「InputHookが横取りするのでホットキーは発火しない」は誤り（対照実験で実測。かつてコメントにそう書いていた）
  - それでもメニューが壊れないのは、EndKeyのEscが先に確定し、送った無変換はフック停止後に届くため（Common.ahkの2ストロークは `{vk1D}` もEndKeyに含むので、順序が逆なら「無効なキーです」に化けていた）
  - 修飾キー付きのEscでは発火しない（AHKは修飾キーの完全一致を要求するため）。`Ctrl+Esc` のスタートメニュー等はそのまま
  - 変換中に押すと、未確定文字列が残っていれば無変換が**カタカナ変換**として食われてIMEが切れないことがある（IME側の仕様）

### startup_manager の動作

- Wドライブの接続を監視（1秒間隔・最大120秒）
- 接続検出後、3秒待ってから Eagle・carnac を1秒間隔で起動
- 自宅版（startup_manager_home.ahk）は TVClock も追加起動

## コーディング規約

- AutoHotkey v2.0 構文を使用（v1.xとは非互換）
- ウィンドウ判定は `#HotIf WinActive(...)` で行い、ブロック終端は `#HotIf` で閉じる
- ウィンドウ識別子は yuya_allways.ahk でグローバル変数として定義
  - `exe_pr` / `exe_ai` / `exe_ps` / `exe_au` / `exe_ae` / `exe_lr` / `exe_bl` / `exe_pureref`
  - `exe_chrome` / `exe_notepad` / `exe_code`
  - `class_explorer` / `class_desktop` / `class_desktop_alt`（デスクトップは Progman、壁紙スライドショー中は WorkerW）
- 新しいアプリ固有のホットキーは `apps/` に追加
- 共通ユーティリティ関数は `lib/Functions.ahk` に追加
- ソースはすべて UTF-8（BOM無し）。新規ファイルにも BOM を付けない

## 実行方法

`yuya_allways.ahk` を AutoHotkey v2 で実行する。
`startup_manager.ahk` はシステム起動時に別プロセスで実行する。

### 二重常駐への対策

- **`#SingleInstance Force` は旧インスタンスの置き換えに失敗することがある。** 実際に11時間前の残骸と併存していた事例がある（どちらも `/restart` 付き＝`Reload` 由来）
- 二重常駐すると `~` 付き（非抑制）のホットキーが**両方のインスタンスで発火する**。2ストロークでは InputHook が2本待機し、選択キーは片方が捕捉して抑制するため、**もう片方は待機したまま取り残されて後から押したキーを横取りする**。ダイアログ表示中の Enter が「無効なキーです」に化け、しかもその Enter は抑制されてダイアログにも届かない
- 一度複製すると、以後の `Reload` はフック先頭の1プロセスしか更新しないため**複製状態が自己永続する**（古いコードのまま動き続ける残骸も残る）
- 対策として `KillDuplicateInstances()`（lib/Functions.ahk）を `yuya_allways.ahk` の冒頭で呼ぶ。メインウィンドウのタイトルが `<スクリプトのフルパス> - AutoHotkey v2.0.x` 形式なので前方一致で判定でき、他のスクリプトやコンパイル済みexeには当たらない。応答不能な残骸でも確実に落とすため `ProcessClose` を使う
- 常駐数の確認方法：`Get-CimInstance Win32_Process -Filter "Name LIKE '%AutoHotkey%'" | Select ProcessId, CommandLine`

### 構文チェック

`yuya_allways.ahk` は `#SingleInstance Force` を持つため、直接実行すると常駐中のインスタンスを終了させてしまう。
代わりに、`yuya_allways.ahk` から `#SingleInstance` だけを外した写しを一時ディレクトリに作って実行する。
グローバル変数の定義をそのまま写し、`ExitApp 0` を `#Include` 群より前に置き、`#Include` は絶対パスにする。

```ahk
#Requires AutoHotkey v2.0
SetTitleMatchMode(2)
global exe_pr := "ahk_exe Adobe Premiere Pro.exe"
; …yuya_allways.ahk のグローバル定義をすべて写す

ExitApp 0

#Include W:\マイドライブ\Programming\AHK\lib\ToolTipEx.ahk
; …以下、yuya_allways.ahk と同じ順序ですべて
```

- 検証したいファイル1つだけを `#Include` すると、他ファイルの関数（`MyTooltip()` 等）が未定義になり、AHK v2 はこれをロード時エラーにする。正常なコードでも exit 2 になるため、必ず全ファイルを揃えて読み込む
- 終了コードで判定する（0 = OK、2 = ロードエラー）。AutoHotkey64.exe は GUI サブシステムのため stdout が取れず、`FileAppend "…", "*"` の出力は届かない。PowerShell では `Start-Process -Wait -PassThru` の `ExitCode` を見る
- `/validate` は AutoHotkey v2.0 では未対応（引数がスクリプト名として扱われる）
- `/ErrorStdOut` を付けてもこの環境ではメッセージが得られないため付けない
