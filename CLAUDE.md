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
  Illustrator.ahk          # Illustrator ホットキー・Sppy_1_5 常駐監視・JSX連携
  AdobeCommon.ahk          # Adobe共通の Ctrl+Enter 後処理をアプリ別に振り分け
lib/
  Functions.ahk            # 共通関数（MyTooltip, IsUrl, CleanUrl, ClickImageAndReturn）
  Hotstring.ahk            # テキスト展開（ddd → 今日の日付MMDD / ttt → tkhs）
  Mouse.ahk                # 中クリックスクロール
  ScrollKeys.ahk           # F23/F24 によるキー加速スクロール
  ToolTipEx.ahk            # ツールチップ描画の拡張
  run_ai_script.ahk        # JSXを別プロセスで実行する子スクリプト
images/                    # ImageSearch 用の参照画像（ai_OK.png 等）
```

## キーの表記

- `vk1D` = 無変換キー（日本語キーボード）
- `vk1C` = 変換キー（日本語キーボード）
- `F23` / `F24` = キー加速スクロール（下 / 上）

## 主要機能

### 2ストロークコマンド

いずれもトリガー後に `MyTooltip` でメニューを表示し、`InputHook` で次の1文字を待つ。

| 対象 | トリガー | 備考 |
|------|----------|------|
| グローバル（Common.ahk） | `vk1D + Space` | メニュー表示5秒／入力待ち2秒 |
| Explorer（Explorer.ahk） | `Ctrl + Space` | ファイルダイアログでも有効（`IsFileDialog()`で判定） |
| Premiere（Premiere.ahk） | `Ctrl + Space` | ファイルダイアログ中は無効 |
| Illustrator（Illustrator.ahk） | `Ctrl + Space` | 0.3秒以内の短押しのみ起動。長押しはAiにそのまま渡す |

### キー加速スクロール（lib/ScrollKeys.ahk）

| キー | 動作 |
|------|------|
| F23  | 下スクロール |
| F24  | 上スクロール |

- 単押しは `MIN_NOTCH`（初期値2ノッチ）、長押しは経過時間に応じて増え、約580msで上限に達する
- 速度は `AccelScroll()` 冒頭の `static` 定数（`REPEAT_DELAY` / `INTERVAL` / `RAMP_STEP` / `MIN_NOTCH` / `MAX_NOTCH`）で調整する
- 送信は `SendWheel()` が `mouse_event` で生のデルタ値（1ノッチ = 120単位）を送る。`Send "{WheelDown n}"` と違い 1.5 のような小数ノッチを扱えるため
- 多重起動ガードの `static` は上下で共有のため、同時に走るスクロールは1方向のみ

### Illustrator の JSX 連携（apps/Illustrator.ahk）

- `AiScript()` は COM 経由で同期実行（本体がブロックされる）
- `RunAiScriptAsync()` は `lib/run_ai_script.ahk` を別プロセスで起動し、ダイアログ表示中も本体をフリーズさせない
- Sppy_1_5 は10秒ごとに実行パスで判定し、別パスのものが動いていれば差し替える

### その他のグローバル処理（apps/Common.ahk）

- `ResetStuckKeys()` … 1500ms間隔で修飾キーのスタック（論理ON・物理OFF）を検出して自動解除
- `OnClipboardChange` … コピーされたテキストがURLなら `CleanUrl()` で自動整形
- `~Esc` … 400ms以内にEscを2回押すと `{vk1D}`（無変換＝半角英数）を送る。`~` 付きなのでEsc自体は各アプリに素通しされる。2ストローク待機中はInputHookがEscを横取りするため発火せず、キャンセル動作が優先される

### startup_manager の動作

- Wドライブの接続を監視（1秒間隔・最大120秒）
- 接続検出後、3秒待ってから Eagle・carnac を1秒間隔で起動
- 自宅版（startup_manager_home.ahk）は TVClock も追加起動

## コーディング規約

- AutoHotkey v2.0 構文を使用（v1.xとは非互換）
- ウィンドウ判定は `#HotIf WinActive(...)` で行い、ブロック終端は `#HotIf` で閉じる
- ウィンドウ識別子は yuya_allways.ahk でグローバル変数として定義
  - `exe_pr` / `exe_ai` / `exe_ps` / `exe_au` / `exe_ae` / `exe_bl` / `exe_pureref` / `class_explorer`
- 新しいアプリ固有のホットキーは `apps/` に追加
- 共通ユーティリティ関数は `lib/Functions.ahk` に追加
- ソースはすべて UTF-8（BOM無し）。新規ファイルにも BOM を付けない

## 実行方法

`yuya_allways.ahk` を AutoHotkey v2 で実行する。
`startup_manager.ahk` はシステム起動時に別プロセスで実行する。

### 構文チェック

`yuya_allways.ahk` は `#SingleInstance Force` を持つため、直接実行すると常駐中のインスタンスを終了させてしまう。
個別ファイルだけを検証したい場合は、`ExitApp` を `#Include` より前に置いたラッパーを一時ディレクトリに作って実行する。

```ahk
#Requires AutoHotkey v2.0
FileAppend "PARSE-OK`n", "*"
ExitApp 0
#Include <検証したいファイルの絶対パス>
```

- `/validate` は AutoHotkey v2.0 では未対応（引数がスクリプト名として扱われる）
- `/ErrorStdOut` はこの環境では正常なスクリプトでも exit 2 を返すため付けない
