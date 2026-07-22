# Simple Screenshot

macOS標準のスクリーンショットUIを使わず、ScreenCaptureKitで直接撮影・録画する軽量なメニューバーアプリです。Swift/AppKitのみで実装し、外部依存はありません。

## 機能

- 画面・領域・ウィンドウのスクリーンショット
- 画面・領域・ウィンドウのMP4録画
- 撮影直後に開く編集画面（テキスト、矢印、四角）
- `Esc` でJPEG保存、クリップボードへコピー、編集画面を閉じる
- JPEG品質68%、録画はH.264・30fps・約1.6Mbps・最大1920px
- `~/Downloads/Screenshots` へ自動保存
- メニューバー常駐、外部ランタイム不要

## ショートカット

| 操作 | ショートカット |
| --- | --- |
| 画面を撮影 | `⌘⇧1` |
| 領域を撮影 | `⌘⇧2` |
| ウィンドウを撮影 | `⌘⇧3` |
| 画面を録画 | `⌘⇧4` |
| 領域を録画 | `⌘⇧5` |
| ウィンドウを録画 | `⌘⇧6` |
| 録画を停止 | メニューバー、または `⌘⇧.` |

編集画面では `V` 選択、`T` テキスト、`A` 矢印、`R` 四角、`⌘Z` 取り消し、`Esc` 保存です。

## 必要環境

- macOS 14 Sonoma以降
- ビルド時のみXcode 15以降

初回撮影時に「システム設定 → プライバシーとセキュリティ → 画面とシステムオーディオ録音」で許可してください。

## ビルド

```sh
make app
open "dist/Simple Screenshot.app"
```

## Homebrew

Homebrew tapへFormulaを追加すると、次の形式でインストールできます。

```sh
brew tap hiroshi-kamikawa/tap
brew install simple-screenshot
```

署名・公証済みの配布では、リリース用ワークフローにDeveloper ID証明書とNotary APIのSecretsを追加してください。ローカルビルドはad-hoc署名です。

## ライセンス

MIT
