# Architecture — iOS Native / Local-first

## 最小スタック（提案）
- Swift + SwiftUI（画面遷移、目標、クエスト、アルバム、設定）
- SpriteKit + SpriteView（箱庭の描画、入力、演出）。物理演算やGameplayKitは必要になってから。
- SwiftData（永続化候補）。モデル移行・整合性の見通しが悪ければSQLite/GRDB等と比較し、安易に外部依存を増やさない。
- Foundation Models（任意・P3以降。availability判定しNo-AIへ戻す）。
- 外部認証/クラウド/APIサーバーはP0/P1では作らない。

## 責務の境界
```
App (SwiftUI views, App composition root)
  ├─ Presentation (HUD, palette, tasks, album, game state bindings)
  ├─ GameRendering (SKScene, sprites, camera, animations, input mapping)
  ├─ UseCases (place/move/remove, complete quest, grant reward, save/load)
  ├─ Domain (Map, Coordinates, Objects, NPC state, Rules, Reward)
  └─ Infrastructure (SwiftData adapters, Assets, optional AI adapters)
```
- DomainはUI/DB/AIに依存しないSwift struct/enum中心。時刻/乱数もテストで差し替えられる。
- UseCaseはDomainを組み合わせて結果とイベントを返し、repositoryで状態を永続化。
- SpriteKitシーンは結果のレンダリング/入力イベント委譲。Sceneに経済ロジック・DBクエリを持たせない。
- SwiftUIはUXと入力のための薄いビュー。API通信やゲームルールを散在させない。

## ゲーム状態
- 確定状態: WorldSnapshot（マップ/オブジェクト/住人状態/所有物/アンロック/ゲームバージョン）。
- 短期演出: scene effect（パーティクル、アニメーション、選択状態）。永続化不要。
- 反応: 決定的ルール `WorldEventRule` に対する `WorldEvent`。シード付き疑似乱数で選択とテストを再現可能にする。
- 保存: 重要な操作はリポジトリの原子的トランザクション（もしくは安全なスナップショット）で確定。保存失敗時は再試行・告知・重複防止。

## ターゲットOS
- 最低iOSバージョンは初回Xcodeセットアップで対応端末の範囲を確認して決める。**AIに合わせて最低OSを上げない**。Foundation Modelsの利用不可ならルール版へフォールバック。
- Apple AIモデルを使う際は言語・端末対応・初期ダウンロード・無効化・処理失敗をすべて正常系として扱う。

## AIを追加する際
```
QuestSuggestionProvider.suggest(context) -> [QuestProposal]
  ├─ RuleBasedQuestProvider       (常に使える)
  ├─ AppleFoundationModelProvider (使用可能な端末のみ)
  └─ ExternalModelProvider        (後続フェーズ・明示同意・サーバー代理)
```
- AIが返すのは「候補・説明・信頼度/観察結果」。XPと所有物の実際の更新は禁止。必ずスキーマと件数/長さを検証。
- 画像はローカル保存が基本。外部APIキーをiOSアプリに埋め込まない。

## CI/CD
- P0の前にXcode project + schemeを共有、ビルド再現、formatter/lint/test/buildをmacOS Runnerで構築する。
- TestFlight用CDはビルドと署名→IPA作成→asc CLIアップロードの順。証明書/ASC APIキーはCI Secrets、最小権限。最初は手動トリガーで配信。
- `asc` CLIはサードパーティ。インストールバージョンを固定し、実行引数・署名方式は公式ドキュメントに照らして検証する。

## 性能・保守
- 起動/描画fps/初期メモリを実機測定。静止時は不要なフレーム更新を抑える。
- 16x16マップなどの数値は初期仮値。ベンチマーク・操作性テストで変更可能。
- Assetカタログ/texture atlasを使い分け、拡大表示のぼやけ・境界にじみを防止。
