# ADR-0001: SwiftUI + SpriteKitを暫定採用する

- **日付**: 2026-10-25
- **状態**: Proposed（設計案。Xcode実機検証前）

## 背景
生活ゲーミフィケーションアプリだが、最初に証明すべき価値はピクセルアート箱庭を自由配置して遊ぶ楽しさ。ユーザーはSwift採用を希望し、Apple IntelligenceとApp Store Connect CLIによるCDにも関心がある。3DやAndroid同時展開は優先しない。

## 選択肢
1. **SwiftUI + SpriteKit** — Apple標準の2D描画、Swift統一、オフライン・Foundation Models連携が容易。SpriteKit固有の学習とiOS中心になる。
2. SwiftUIのみ — 画面は簡単だが、タイル配置と連続アニメーションの管理が複雑になる恐れ。
3. Unity / Godot — ゲーム開発機能・ツールは豊富だが、配信・UI/ネイティブAI統合・依存/容量/学習運用コストが増えうる。
4. React Native / Expo — 共通UIが利点だが、2D描画とAppleネイティブAPIとの接続に橋渡しが必要。

## 推奨
SwiftUIをアプリのUI、SpriteKitを2Dゲーム描画に採用し、ゲームルールをフレームワーク非依存のSwiftに分離。保存はSwiftDataを優先候補とし、事前テストで運用可能性を確認。

## トレードオフ
- iOSファースト。Androidに同時対応するメリットを現時点では取らない。
- 独自の描画ルール・シーン/モデル同期の設計が必要。
- SpriteKitへ業務ルールを入れない責務分離を守る。

## 見直し条件
- ゲーム表現やアセット制作の制約がSpriteKitで大きい、複数プラットフォームが明確な必須要件になった、開発コストと実機評価が逆転した場合に検討し直す。
