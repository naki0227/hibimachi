# ADR-0008: App Store の掲載情報をYAMLで管理し、App Store Connect API で反映する

- **日付**: 2026-10-26
- **状態**: Accepted（実際の App Store Connect への反映は未実行。Secrets 登録後に plan で確認する）

## 背景
ユーザー要望（2026-10-26）: 「yaml とかで審査に出す内容とか全部指定して入れられるようにしてほしい」。
ROADMAP Stage 5 は TestFlight の手動起動から始めるCD。掲載文・年齢制限・審査メモ・スクリーンショットを手入力すると、変更の履歴が残らず、版ごとの差も確認できない。

## 決定
1. `appstore/metadata.yml` を正本にする。キーは API の属性名に対応させ、年齢制限の回答は API 属性名のまま通す（Apple が質問を増やしてもコード変更なしで足せる）。
2. `scripts/appstore/`（Python）で App Store Connect API を直接呼ぶ。`plan` は読み取りだけで差分を表示し、`apply` は差分だけを送る。審査提出は `apply --submit` を明示したときだけ。
3. 個人の連絡先（名前・電話・メール）は YAML に書かず `${NAME}` で GitHub Secrets から読む。ログでは電話・メール・パスワードを `***` にする。
4. スクリーンショットは UI テスト `AppStoreScreenshotTests` で 6.9 インチのシミュレータ（ステータスバー固定）から撮る。
5. API で設定できない「App のプライバシー」と「価格・配信国」は README に手順を残し、手で一度だけ入れる。

## 選択肢
| 論点 | 採用 | 不採用と理由 |
|---|---|---|
| 反映ツール | 自前の小さな Python（依存は PyYAML と cryptography、版固定） | fastlane deliver: Ruby と多数の gem が増える。YAML ではなく専用フォルダ形式 |
| | | asc 系 CLI: 掲載情報の項目対応が限られ、YAML を正本にするには結局変換が要る |
| 認証 | API キーの ES256 JWT を cryptography で署名 | PyJWT: JWT は数行で作れるので依存を増やさない |
| スクショ | UI テストで自動撮影 | 手で撮る: 画面の変更に追随しにくい |

## リスク・見直し条件
- API の属性名・状態名が変わると `plan` が失敗する（エラーに Apple の説明が出る）。その時点で `sync.py` を直す。
- 2025年の年齢制限の改定で増えた質問は `age_rating` に未記入。提出時に不足と言われたら、App Store Connect の表示に合わせてキーを足す。
- 英語など他の言語は `localizations` にロケールを足せば同じ仕組みで出せる。
