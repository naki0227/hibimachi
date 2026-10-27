# Data Model — 主要ドメイン（概念モデル）

## P0 entities
| 名称 | 主なフィールド | 不変条件 |
|---|---|---|
| `World` | id, schemaVersion, width, height, terrainTiles, objects, discoveredEvents | タイル範囲内、schemaVersionあり |
| `TileCoord` | x:Int, y:Int | 0 <= x < width, 0 <= y < height |
| `WorldObject` | id:UUID, kind, origin, footprint, rotation, createdAt, sourceCompletionID? | 重複IDなし、配置可能領域に収まる |
| `NPC` | id, species, position, state, targetObjectID?, lastInteractionAt | targetObjectIDがなくなってもfallback |
| `WorldEvent` | id, kind, occurredAt, sourceObjectIDs, outcome | 連打/二重発火を制御 |
| `WorldSnapshot` | world, time, checksum?, version | 不明な版を黙って上書きしない |

## P1 entities
| 名称 | 主なフィールド | 不変条件 |
|---|---|---|
| `Goal` | id, title, category?, priority, status, createdAt | 有効なタイトル長、削除で履歴破損なし |
| `QuestTemplate` | id, goalID, title, suggestedDuration, difficultyByUser?, active | 1件完了可能な単位 |
| `QuestCompletion` | id, questID, createdAt, localDate, note?, evidenceIDs? | ID一意、イベント再実行で報酬二重付与なし |
| `RewardTransaction` | completionID, ruleVersion, xpDelta, currencyDelta, grantedAt | completionIDにつき1回だけ |
| `Wallet` | totalXP, currencyBalance | currencyBalance >= 0、算出値の改ざん耐性を設計 |
| `Unlock` | objectKind, unlockedAt, source? | 必須建物を特定行動でロックしない |

## P2 entities
| 名称 | 主なフィールド | 不変条件 |
|---|---|---|
| `MemoryEntry` | id, completionID?, text?, mediaReferences, createdAt, linkedObjectIDs | 空データ/写真なし可、本人非公開が既定 |
| `LocalMediaReference` | id, relativePath, format, bytes, createdAt, deletionState | 写真の絶対パスやEXIFに依存しない |

## 実装状況（2026-10-26）
- 保存は1つのJSONファイル。schema v2 は v1 に `progress`（goals, quests, completions, transactions, owned, skipped）を追加したもの。v1 は読み込み時に移行する（置いてある物を所持扱いにし、ようこそのきらめき30を付与）。
- schema v3（2026-10-26）は `album`（`MemoryEntry`: day, createdAt, text?, photo{id, fileName, bytes, createdAt}?, completionID?）を追加。v1/v2 は空のアルバムとして読む。写真は保存JSONに入れず、アプリ専用フォルダの `media/<id>.jpg` に置く（ADR-0007）。
- schema v4（2026-10-26）は住人の一覧 `residents`（2匹目以降。各住人に `species`: mochi/kotori/tanuki）と、配置物の `placedAt`（迎えた日時。最初からある物と旧版は無し）を追加。v1〜v3 は「もち1匹」として読み、未知の種は読み込みエラーにする（ADR-0009）。
- schema v5（2026-10-26）は住人記録に `friendship`（points, petDay, petsOnPetDay）を追加。v1〜v4 は0から（ADR-0013）。報酬規則は v2（所要時間で変わる。ADR-0012）。
- schema v6（2026-10-26）は `growthStage` を追加し、地図は 20x20。v5 以前の 16x16 の保存は読み込み時に (+2, +2) ずらして中央へ移す（ADR-0014）。
- 同じ v6 の範囲で、クエスト記録に `retired`（もう出さない。履歴があるとき）、アルバムの記録に `beforeEntryID`（Before/After のつながり）を追加した。どちらも省略可で、古い保存はそのまま読める。
- 保存場所は App Group `group.com.enludus.hibimachi` の `Hibimachi/world.json`（ウィジェットと共有。使えないときはアプリの Application Support）。ウィジェットは副作用なしの `peek()` で読み、達成だけを書き込む（ADR-0006）。島の絵 `widget-island.png` も同じコンテナに置く。
- `Wallet` は保存しない。台帳（transactions）の合計から XP ときらめきを算出する。`Unlock` は保存しない。解放は「レベルか発見数」から毎回算出する（`Unlocks`、ADR-0009。ADR-0005 の「すべて買える」を v1.0 で変更）。設定（効果音・音楽・ふるえる）は保存JSONではなく UserDefaults（ADR-0010）。

## Save/loadの要件
- Domain modelとSwiftDataのstorage modelは別。storageの都合をDomainへ混ぜない。
- スキーマ移行: v1→v2のテストフィクスチャを保存し、古い保存データを移行できるか確認。
- 変更順序: 検証→ドメイン状態更新→トランザクション保存→描画の更新通知。保存失敗時に不整合表示を残さない。
- 削除時: 建物を撤去しても過去の達成記録まで消さない。写真削除時は参照を解決して必要ならサムネイルも消す。
- ローカル日付: DSTやタイムゾーン変更を考慮し、時刻UTC＋ユーザーのローカル日付識別を必要に応じて分ける。

## 実装案の署名例（擬似Swift）
```
struct PlacementRequest { let kind: ObjectKind; let origin: TileCoord }
func validatePlacement(_ request: PlacementRequest, in world: World) -> PlacementResult
func applyPlacement(_ request: PlacementRequest, to world: World) throws -> (World, [WorldEvent])
func evaluateNPCReaction(world: World, npc: NPC, seed: UInt64) -> NPCAction
func grantReward(for completion: QuestCompletion, using rule: RewardRule) -> RewardTransaction
```
※実際のAPI、型名はXcode初期化時に適切なSwiftの命名規則とともに決定。
