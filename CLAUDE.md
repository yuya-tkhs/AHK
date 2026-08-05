# AHK Personal Automation Suite

AutoHotkey v2.0 による個人用キーボード・アプリケーション自動化スクリプト群。

## プロジェクト構成

```
yuya_allways.ahk          # メインエントリポイント（全ファイルをinclude）
startup_manager.ahk        # 外付けドライブ接続時のアプリ自動起動（会社用）
startup_manager_home.ahk   # 同上（自宅用・TVClock追加）
apps/
  Common.ahk               # グローバルホットキー・2ストロークコマンド
  Explorer.ahk             # Windowsエクスプローラー拡張
  Premiere.ahk             # Adobe Premiere Pro ホットキー
  Illustrator.ahk          # Illustrator起動時にSppy_1_5を自動起動
  AdobeCommon.ahk          # Adobe共通設定（現在空）
lib/
  Functions.ahk            # 共通関数（MyTooltip 等）
  Hotstring.ahk            # テキスト展開（ddd → 今日の日付MMDD）
  Mouse.ahk                # 中クリックスクロール
  ToolTipEx.ahk            # ツールチップ描画の拡張
  run_ai_script.ahk        # Illustrator の JSX 実行連携
```

## キーの表記

- `vk1D` = 無変換キー（日本語キーボード）
- `vk1C` = 変換キー（日本語キーボード）

## 主要機能

### 2ストロークコマンド

- **グローバル（Common.ahk）**: `vk1D + Space` でメニュー起動（5秒タイムアウト）
- **Explorer（Explorer.ahk）**: `Ctrl + Space` でメニュー起動
- **Premiere（Premiere.ahk）**: `Ctrl + Space` でメニュー起動

### startup_manager の動作

- Wドライブの接続を監視（最大120秒待機）
- 接続検出後にFontBase・Eagleを自動起動
- 自宅版はTVClockも追加起動

## コーディング規約

- AutoHotkey v2.0 構文を使用（v1.xとは非互換）
- ウィンドウ判定は `#HotIf WinActive(...)` で行う
- Adobeアプリのウィンドウ識別子はyuya_allways.ahkでグローバル変数として定義
  - `exe_pr` = Premiere Pro
  - `exe_ai` = Illustrator 等
- 新しいアプリ固有のホットキーは `apps/` に追加
- 共通ユーティリティ関数は `lib/Functions.ahk` に追加
- ラップトップ専用の設定は `#HotIf InStr(A_ComputerName, "Laptop")` で分岐

## 実行方法

`yuya_allways.ahk` を AutoHotkey v2 で実行する。
`startup_manager.ahk` はシステム起動時に別プロセスで実行する。
