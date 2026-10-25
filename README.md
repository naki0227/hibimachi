# HIBIMACHI — 生活と一緒に育つ、小さな箱庭（仮称）

> **ステータス**: 企画・実装引き継ぎ用。プロジェクト名、画風の詳細と数値は仮定。アプリ実装・ビルド・TestFlight配信は未実施。
> **作成**: 2026-10-25 / **対象**: iOS / **方針**: Swift + SwiftUI + SpriteKit、AI任意、ローカルファースト。

## ビジョン
**現実での小さな行動が、自分だけの箱庭と歴史になる。** 「習慣を管理するためにゲームを使う」のではなく、「箱庭が楽しいから、現実も少し楽しくなる」ことを狙う。

## 確定したユーザー方針
- 自由な街づくりを軸に、住人やペットが自律的に暮らす。配置の組み合わせで発見が起きる。
- 片付け、勉強、運動、睡眠など生活全般。開始時に目標を設定し、小タスクへ分割できる。選択・タップ中心。
- 行動に対してXPと共通建築資源を与え、写真・文章による任意の成長アルバムを持つ。Before/After写真評価と共有は将来候補。
- 苦手への挑戦も得意の継続も肯定。身体・時間・環境の違いで建築や進行をロックしない。
- AIがなくても全部の基本ゲームが成立。使える端末ではApple Intelligenceを優先し、Claude APIは必要性が検証されてから。
- **Swiftを採用したい**。App Store Connect CLIによるCDを見据える。
- ゲームの面白さが最優先。最初は生活記録やAI以前に箱庭だけで触りたいかを検証。

## ドキュメントの読む順番
1. [CLAUDE-HANDOFF.md](CLAUDE-HANDOFF.md) — 次にClaudeがすること・守る境界
2. [docs/PRD.md](docs/PRD.md) — 対象ユーザー・体験・スコープ・受入基準
3. [docs/GAME-DESIGN.md](docs/GAME-DESIGN.md) — 基本ループ、建築、発見、育成、XP
4. [docs/VISUAL-DIRECTION.md](docs/VISUAL-DIRECTION.md) — 3案比較と推奨デザインシステム
5. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 分離方針、永続化、AI境界
6. [docs/DATA-MODEL.md](docs/DATA-MODEL.md) — エンティティと整合性
7. [docs/QUALITY-CI.md](docs/QUALITY-CI.md) — 最初のCI整備とテスト計画
8. [docs/ROADMAP.md](docs/ROADMAP.md) — 段階的実装・検証指標
9. [docs/PRIVACY-AI.md](docs/PRIVACY-AI.md) — 個人情報、任意AIと画像取り扱い
10. [docs/adr/0001-ios-native-spritekit.md](docs/adr/0001-ios-native-spritekit.md) — 暫定技術判断
11. [TODO.md](TODO.md) / [reports/2026-10-25-planning.md](reports/2026-10-25-planning.md) — 引き継ぎ管理

## 企画の境界
これは独立した新規プロジェクト。既存の `mikka_bouzu` とは関連するが、**そのリポジトリを置き換えたり、既存コードを流用したとみなさない**。使う場合はコードとライセンス、テストを確認する。

## 品質ゲート
この資料にはドキュメント構造検査CIを含める。Xcodeプロジェクト未作成のため **Swiftのformat/lint/typecheck/test/buildは未実施**。Claudeは機能追加前にアプリ雛形を作成し、macOS Runnerでこれらを実行するCIを別コミットで整えること。

## 参考情報
- [Apple SpriteKit](https://developer.apple.com/documentation/spritekit)
- [SwiftUI SpriteView](https://developer.apple.com/documentation/spritekit/spriteview)
- [Apple Foundation Models](https://developer.apple.com/foundation-models-framework/)
- [asc CLI](https://asccli.sh/)（サードパーティCLI。採用とバージョンを検証する）
- Shared Vault: `naki0227/personal-knowledge/02-Projects/life-gamification-hakoniwa-concept.md`
