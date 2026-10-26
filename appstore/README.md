# App Store に出す内容（YAMLで管理）

`metadata.yml` が App Store / TestFlight の文章・カテゴリ・年齢制限・審査メモ・スクリーンショットの正本です。
書き換えて GitHub Actions の **「App Store metadata」** を実行すると、App Store Connect に反映されます。

## 一度だけ必要な準備
1. App Store Connect で新規 App を作る（バンドルID `com.enludus.hibimachi`。アプリ作成だけは API でできない）。
2. GitHub の Settings → Secrets and variables → Actions に登録する。
   | 名前 | 中身 |
   |---|---|
   | `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_P8` | App Store Connect API キー（App Manager）。TestFlight と共通 |
   | `APPLE_TEAM_ID` | チームID（TestFlight 用） |
   | `ASC_REVIEW_FIRST_NAME` / `ASC_REVIEW_LAST_NAME` | 審査担当が連絡する人の名前（ローマ字） |
   | `ASC_REVIEW_PHONE` | 電話番号（例 `+81 90-1234-5678`） |
   | `ASC_REVIEW_EMAIL` | メールアドレス（TestFlight のフィードバック先にも使う） |
3. `metadata.yml` の `TODO` を埋める（著作権、プライバシーポリシー URL、サポート URL）。
4. API で設定できない2項目を App Store Connect で入れる。
   - **App のプライバシー**: 「データを収集していません」
   - **価格および配信状況**: 無料、配信国（まずは日本）

## 使い方（Actions → App Store metadata → Run workflow）
| 入力 | 意味 |
|---|---|
| mode = `plan` | 何が変わるかを表示するだけ（何も書き換えない）。まずこれで確認 |
| mode = `apply` | 反映する |
| screenshots | 6.9インチのシミュレータで撮り直して差し替える（`AppStoreScreenshotTests`） |
| build | 審査に出すビルド番号（TestFlight にアップロード済みのもの） |
| submit | `apply` と一緒に指定したときだけ、審査に提出する |

いつもの流れ: TestFlight で確認 → `plan` → `apply`（screenshots / build を指定）→ 問題なければ `apply` + `submit`。

## 手元で確認する
```sh
python3 -m pip install -r scripts/appstore/requirements.txt
python3 scripts/appstore/asc.py validate        # オフライン。TODO と Secrets は警告だけ
python3 -m unittest discover -s scripts/appstore/tests
```

## 書き方のメモ
- キー名は App Store Connect API の属性名に対応している（`age_rating` は API の属性名をそのまま書く。Apple が質問を増やしたらキーを足す）。
- 文字数の上限（名前30・サブタイトル30・キーワード100・プロモーション170・説明4000）は validate が確認する。
- `whats_new` は最初のバージョンでは送られない（Apple の制約）。
- スクリーンショットはフォルダ内の PNG をファイル名順に使う（最大10枚、サイズも確認）。
