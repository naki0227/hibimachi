# 2026-10-26 v1.0: 中身の拡充・思い出と次の提案・音と設定・英語対応 作業報告

- 作成日時: 2026年10月26日 15時33分28秒（JST、`date -u` で 06時33分28秒 UTC を実測）
- ブランチ / PR: `claude/hibimachi-p0-impl-auviod` / PR #3
- ユーザー決定（2026-10-26）: 「このゲーム完成させてほしい」。範囲は「中身を増やす」「思い出と次の提案」「音と設定画面」「英語対応」の4つ。全部作ってから TestFlight で一度に確認する。

## 変更（コミット単位）
1. `70968b7` コア: 配置物13種追加（計20種）、レベルか発見での解放、反応11種追加（計15種）、住人3種（発見0/3/7でやってくる、種ごとの好み）、保存 schema v4。
2. `b06307f` アプリ: 新しい配置物と住人の絵（コード描画）、名前と説明、解放前のパレット表示、住人到着カード。
3. `f0ae611` 建物の思い出（迎えた日のアルバムを開く）と、クエスト後の「次の一手」1件（`NextStep`）。
4. `4d26aee` コード合成の効果音8種と音楽、せってい画面（効果音・音楽・ふるえる・案内の再表示・リンク・バージョン）。
5. `86f2b30` iOS ビルド修正（音の描画クロージャで非Sendableのバッファを捕まえていた）。
6. `e6bb362` 目標の英語プリセット（件数と分数は日本語と同じ。題名は30字以内）。
7. `4013e62` 英語対応（`Shared/Localizable.xcstrings`、258鍵）、アプリ名、日付のロケール表示、漏れ検査 `scripts/check_localization.py`（docs CI）、`EnglishUITests`。
8. `931765e` App Store の en-US 情報、日英のスクリーンショット撮影。日本語の説明文も新要素に合わせて更新。
9. `78a483d` ADR-0009〜0011、DATA-MODEL（schema v4）、TODO。
10. `7a0485f` せっていのスイッチは標準の値（VoiceOver が利用者の言語で読む）に任せる。UIテストの期待値を修正。

## 設計の要点
- 解放は「レベル **または** 発見数」。クエストを使わない人も置き方の工夫で先へ進める（ADR-0009）。
- 音はファイルを持たずに合成し、`ambient` で消音スイッチとほかの音楽を尊重（ADR-0010）。
- 日本語を原文の鍵にしたまま英語を足し、「訳されない場所の日本語」と「英語のない鍵」をCIで止める（ADR-0011）。

## 検証
| 項目 | 結果 |
|---|---|
| `swift build -Xswiftc -warnings-as-errors && swift test`（HibimachiCore, Linux, Swift 6.3.3） | 132件 PASS |
| format-check / lint（ローカル） | PASS |
| `python3 scripts/check_localization.py` / `python3 -m unittest discover -s scripts -p 'test_*.py'` | PASS / 8件 PASS |
| `python3 scripts/appstore/asc.py validate` | OK（ja, en-US。スクリーンショット未撮影の警告のみ） |
| Docs quality / App Store metadata（head `7a0485f`） | success |
| Swift CI（head `4d26aee`→`86f2b30`） | 1回目: iOS ビルド失敗（手順5で修正）／2回目: ビルド成功、UIテスト1件失敗（手順10で修正） |
| Swift CI（head `7a0485f`） | 下の追記を参照 |

## 未実施・残課題
- 英語の文言はネイティブ確認前。enludus.com のサポート/プライバシーは日本語のみ。
- App Store の screenshots 付き plan / apply は未実行（本人の操作が必要）。
- 実機での音量・音楽の印象、住人が増えたときの反応の頻度は TestFlight で確認する。
- 解放段階と価格は暫定値（7日間テストで調整）。

## 次回最初に読むもの
- `TODO.md` の「要確認（v1.0）」、`docs/adr/0009`〜`0011`。
- コマンド: `cd HibimachiCore && swift test`、`python3 scripts/check_localization.py`。
