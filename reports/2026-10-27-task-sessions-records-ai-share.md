# 2026-10-27 「今からやる」・タスクに合った記録・端末内AIのひとこと・日記とシェア 作業報告

- 作成日時: 2026年10月27日 10時37分（JST、`date` で 2026-10-27 01時37分01秒 UTC を実測）
- ブランチ / PR: `claude/hibimachi-p0-impl-auviod` / PR #5
- ユーザー決定（2026-10-27）: タスクを押して始め、タスクに合った写真や量を残す構想。AI は今回から使う、記録ボーナスは少しだけ、PR #4 をマージしてから新 PR（ADR-0015）。

## 変更（コミット単位）
1. `b71d657` Core: 記録のしかた（`RecordStyle`）、セッション、記録の判定（`RecordCheck`）、記録ボーナス（XP+5・きらめき+2、取り消しで一緒に戻す）、ルールのひとこと。保存 schema v7・報酬規則 v3。
2. `9fb3425` App: クエストの「今からやる」、カメラ/写真での前・途中・あとの写真、「おわった」で量・ひとことを入れて「やった！」。カメラ権限の文言。
3. `c7c87ec` App: 端末内AIのひとこと（Vision の分類ラベル＋Foundation Models、8秒・120字で打ち切り、使えないときはルールの定型文）。設定でオフにできる。
4. `740022c` App: タスクの記録カードと日記カードのシェア。写真・量とひとこと・AIのひとことを毎回選ぶ（写真は初期オフ）。
5. ドキュメント: ADR-0015、DATA-MODEL（v7）、GAME-DESIGN（記録ボーナス）、PRIVACY-AI（AI・共有カード）、本報告、TODO。

## 設計の要点
- 報酬の判定は決定的なルール。AI はひとことを書くだけで、ボーナスの有無に関わらない（端末差で不公平にならない）。
- どの記録の種類も写真なしで「そろう」道がある（カメラが使えない人が不利にならない）。
- 共有はOSの共有シートだけ。アプリから通信しない。目標の名前・統計は入れない。

## 検証
| 項目 | 結果 |
|---|---|
| `swift test`（HibimachiCore, Linux, Swift 6.3.3） | 168件 PASS（`c7c87ec` 時点） |
| format-check / lint、`check_localization.py`、`verify_docs.py` | PASS |
| Swift CI（`9fb3425`）Linux ジョブ | success。iOS build/test は本報告作成時に実行中 |
| AI コーチ・シェア（`c7c87ec`〜） | iOS のコンパイルとテストは PR #5 の CI で確認する（ローカルでは不可） |

## 未実施・残課題
- Foundation Models の実際の出力は CI で確認できない（フォールバック経路のみテスト）。対応端末での確認が必要。
- カメラ撮影・写真選択は UI テストで自動化していない。写真なしの経路を UI テストで確認する。
- ボーナス量（+5/+2）と文言はプレイテストで調整。英語の文言はネイティブ確認前。

## 次回最初に読むもの
- `docs/adr/0015-task-sessions-records-and-on-device-ai.md`、`TODO.md`
- コマンド: `cd HibimachiCore && swift test`、`python3 scripts/check_localization.py`
