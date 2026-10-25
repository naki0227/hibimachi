# Quality / CI — 実装前の品質基盤

## 現状
このパックはドキュメントと構造検査スクリプトのみ。Xcodeプロジェクト、Swiftコード、macOS Runnerでのビルドは**まだ存在しない**ため、Swift checksは未実施。

## ブートストラップ最初のコミットで行うこと
1. iOS Xcode projectを作成し、shared scheme、Deployment Target、Swiftツールチェーンのバージョン、Bundle ID仮値を定義。
2. アプリは起動し、空のSwiftUI画面からSpriteView/ SKScene が表示できるところまで。機能は入れない。
3. format check（swift-format等）とlint（SwiftLintを採用するか比較して固定）、unit test（Swift TestingまたはXCTest）、typecheck（swiftc/Xcode target依存。ビルドでの型検査と別に実行可否を確認）、build checkを設定。
4. GitHub Actions macOSでPRとmain pushを検証。Xcodeバージョンを固定。依存とアクションをバージョン固定/可能ならSHA固定。
5. CIがgreenになってからゲームロジックに着手。CI基盤と機能を別コミットに分ける。

## 単体テスト（P0）
- `validatePlacement`: マップ端、建物サイズ、占有衝突、許可地形、負座標、同一ID、空マップ。
- 座標変換: 表示座標⇄タイル座標、倍率変更、パン、端末サイズ変更。
- 建築: 購入/配置/移動/撤去と資源返却方針、失敗時に資源が減らない。
- Undo: 配置直後・移動直後・撤去直後・保存をまたぐ場合の定義。
- NPC反応: ベンチあり/なし、木・池の優先度、対象物撤去時fallback、seed固定時の再現性。
- 保存: 空の島、最大密度、古いschemaVersion、壊れたデータ、容量不足、アプリ中断時。
- 描画: メインスレッド、過剰ノード増殖、別worldを読み込んだ際の残像。

## P1以降のテスト
- 報酬の二重付与を一意IDで防止、上限/境界/負数防止、同日多回、前日を後から記録、タイムゾーン変更。
- 生活カテゴリが異なってもすべての主要建築物にアクセスできること。
- AIなしの正常系、Apple Intelligence非対応/無効/ダウンロード未完了/処理失敗のfallback。
- 写真なし、写真消去、許可拒否、書き込み失敗、プライバシー同意撤回。

## CI段階
- **現時点**: `.github/workflows/docs-ci.yml` はPython標準ライブラリでドキュメントリンク/必須ファイル/機密文字列の基本確認（セキュリティ保証ではない）。
- **Xcode初期化後**: 署名不要のSimulator向け `xcodebuild build/test`、format/lint、検証専用schemeを追加。
- **リリース前**: Simulator UI test、実機アクセシビリティ、パフォーマンス、TestFlight配信の手動jobを追加。

## セキュリティ・プライバシー
- 写真・目標・家の中が写るデータをCI成果物やクラッシュログに含めない。
- 権限拒否/通信遮断でコアゲームが使えることを確認。
- App Store Connect秘密キーはCI secrets。PRから秘密にアクセスできない設定を確認。
- データ削除のテスト、ローカルメディアをShare Sheetへ渡す際のEXIF除去を確認。

## 各PRのDefinition of Done
- 変更概要、影響範囲、テストと実行コマンド、検証結果、リスク、rollback手順、残課題。
- format, lint, typecheck, unit test, buildの実施/未実施理由。未実施なのにgreenと書かない。
- P0完了時に実機プレイテストの所見を残し、ゲームの「楽しさ」を仮説検証する。
