# ADR-0002: ローカルSwift Package分離とCIツール選定

- **日付**: 2026-10-25
- **状態**: Accepted（CI上で検証。実機未検証）

## 背景
AGENTS.md は「Domain/UseCaseはSpriteKit・SwiftUI・DBを知らない」「CIを機能より先に整備」を求める。作業環境はLinuxでXcodeがなく、macOS Runnerは私有リポジトリでは消費分数が大きい（Linuxの10倍換算）。

## 決定
1. **ゲームルールと保存を `HibimachiCore/`（ローカルSwift Package）に置く**。`HibimachiCore`（Domain/UseCase）と `HibimachiStorage`（JSONファイル保存）の2 target。アプリ本体（SwiftUI/SpriteKit）は `Hibimachi.xcodeproj` から参照する。
2. **format/lint は Swift toolchain 同梱の `swift format`**（追加依存なし）。設定は `.swift-format`。lint は `swift format lint --strict`。
3. **CIは2段**: Linux（`swift:6.3.3-noble` をdigest固定）で format-check / lint / core build / core test。通過後に macOS（`macos-26`、Xcode 26.5固定、iPhone 17e / iOS 26.5 Simulator）で core test・アプリbuild・unit/UI test。
4. Xcodeプロジェクトは Xcode 16以降の folder-synchronized group（objectVersion 77）で手書き。ファイル追加でpbxprojを編集しない。
5. 最低iOS 17.0（Observation / `@Observable` を使うため）。iPhone・縦画面のみ。Bundle ID `dev.naki0227.hibimachi` は仮値。→ 2026-10-26 ユーザー決定で `com.enludus.hibimachi`（ウィジェット `.widget`、App Group `group.com.enludus.hibimachi`）に変更。TestFlight/App Store Connect 登録後は変更できない。

## 選択肢と比較
| 案 | 利点 | 欠点 |
|---|---|---|
| **ローカルPackage分離（採用）** | 依存方向をモジュール境界で強制。Linuxで高速にテスト可能 | pbxprojにpackage参照が増える |
| アプリtarget内にDomainを置く | 構成が単純 | SpriteKit importを防げない。テストにSimulatorが必須 |
| XcodeGen / Tuist | pbxprojを生成できる | 新規依存とインストール手順が増える |
| SwiftLint | ルールが豊富 | 新規依存（バイナリ/プラグイン）。現段階は swift-format の lint で足りる |

## トレードオフ / リスク
- macOSローカルの `xcrun swift-format` はXcode同梱版で、CIの6.3.3とわずかに出力が異なる可能性がある。**CIのLinux jobを正**とする。
- 手書きpbxprojは Xcode で開いたときに書き換えられることがある。差分はレビューで確認する。
- 型検査は build（`swift build` / `xcodebuild build-for-testing`）で兼ねる。独立した typecheck job は設けない。

## 見直し条件
- lintで検出したい規約（複雑度・命名等）が swift-format で足りなくなったら SwiftLint を比較導入する。
- macOS分数がコスト上問題になったら、iOS jobをPRのみ・パス絞り込みにする。
- Runner image から Xcode 26.5 が消えたら、固定バージョンを更新する（`.github/workflows/swift-ci.yml`）。
