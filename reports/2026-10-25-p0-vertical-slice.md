# 2026-10-25 Swift CI整備とP0箱庭Vertical Slice実装報告

- 作成日時: 2026年10月25日 23時36分19秒（JST、作業環境の `date` で取得）
- ブランチ / PR: `claude/hibimachi-p0-impl-auviod` / https://github.com/naki0227/hibimachi/pull/1
- 目的: 機能より先にSwift CIを整え、AI・写真・SNS・認証・課金・同期なしで「置いて、生き物が反応する」箱庭P0を遊べる状態にする。

## 変更（コミット単位）
1. `ci:` Xcodeプロジェクト（app / unit test / UI test、shared scheme）、ローカルSwift Package `HibimachiCore`、`.swift-format`、`scripts/ci/swift-quality.sh`、`.github/workflows/swift-ci.yml`、ADR-0002。
2. `feat(core):` Domain（地形・配置物・`World`検証）、`WorldEditor`（Undo 20段）、`CreatureBrain`（状態機械・4反応）、座標/カメラ計算、`GameStore`、JSON保存（schema v1、原子的書き込み、退避）、unit test 61件。
3. `feat(app):` SpriteKit描画（色ブロックのピクセル風仮アート）、入力（タップ/ドラッグ/ピンチ）、SwiftUI HUD（パレット・確定ボタン・矢印・選択バー・Undo・図鑑・一覧・トースト・保存エラー）、アプリunit test、UI test 3件。
4. `docs:` ADR-0003、本報告、TODO/ROADMAP/README更新。

## 設計意図
- ルールは `HibimachiCore`（SpriteKit/SwiftUIをimportしない）に閉じ込め、Linuxでも `swift test` できる。SceneはStoreの状態を差分描画し入力を委譲するだけ（ADR-0002/0003）。
- 誤操作対策: タップ・ドラッグはプレビューを動かすだけで、確定は必ず「ここに置く」ボタン。置けない理由を文章と ○/× で表示し、確定ボタンは無効化。
- 面白さの仕掛け: 初期島ではベンチ・木・池の3反応がすぐ見られ、**花をベンチの隣に置くと反応が変わる**（`bloom-bench`）。図鑑には未発見の件数を出さない。

## 検証（実行コマンドと結果）
| 項目 | コマンド / 場所 | 結果 |
|---|---|---|
| format | `scripts/ci/swift-quality.sh format-check`（Linux, swift 6.3.3） | PASS |
| lint | `scripts/ci/swift-quality.sh lint` | PASS |
| core unit test | `swift test --package-path HibimachiCore`（Linux） | 61件 PASS |
| docs | `python3 scripts/verify_docs.py` / `python3 -m unittest discover -s scripts -p 'test_*.py'` | PASS |
| CI（`ci:`コミット e1c70ea） | GitHub Actions Swift CI（Linux + macOS-26 / Xcode 26.5 / iPhone 17e iOS 26.5） | 全job success |
| CI（機能コミット） | 同上 | 実行中（結果は追記する） |

- 反応バランス（一時的なテストで計測、コミットしていない）: 初期島・200 seedで初回発見までの中央値7tick（約3秒）、90パーセンタイル14tick、最大62tick（約28秒）。10分あたりの反応はベンチ約17回・木約12回・池約10回、中断0回。

## 未実施と理由
- **実機プレイテスト・ゲーム性の評価**: 実機がなく、この作業環境はLinux。ジェスチャーの操作感、小画面での誤タップ率、楽しさはSimulatorのUI test/スクリーンショットのみで、人による検証はしていない。
- **ローカルでのXcodeビルド・Simulator起動**: 作業環境にXcodeがないため、iOSのbuild/testはGitHub ActionsのmacOS Runnerだけで実施。
- VoiceOver・Dynamic Typeの実操作確認、Reduce Motionの目視確認、性能（fps/メモリ）計測。
- 最小チュートリアル（ROADMAP Stage 1）と2〜5人のプレイテスト。

## リスク・注意点
- 手書きのpbxprojをXcodeで開くと書式が書き換わることがある（差分はレビューで確認）。
- CIのmacOS jobは私有リポジトリでは分数消費が大きい（Linuxの10倍換算）。
- 仮アート（色ブロック）はオリジナル。既存ゲームの画像は使っていない。

## Rollback
- 機能をやめる: `feat(app)` と `feat(core)` を revert（`ci:` は残せる）。保存ファイルは `Application Support/Hibimachi/world.json` のみで、アプリ削除で消える。

## 次回最初に読む / 実行する
- 読む: `TODO.md` → `docs/adr/0003-p0-game-state-and-persistence.md` → `HibimachiCore/Sources/HibimachiCore/UseCases/GameStore.swift`
- 実行: `swift test --package-path HibimachiCore`、`scripts/ci/swift-quality.sh lint`、macOSなら `xcodebuild test -project Hibimachi.xcodeproj -scheme Hibimachi -destination 'platform=iOS Simulator,name=iPhone 17e,OS=26.5'`
