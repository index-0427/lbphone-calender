# lbphone-calender

lb-phone 用のサーバー共有カレンダーアプリ(qbox 向け)。
全プレイヤーが同じカレンダーを閲覧・参加予約でき、管理者やジョブ/ギャングのボスが予定を追加・編集・削除できます。
イベント通知は10分前・30分前・1時間前・1日前・3日前から選択でき、既定ではオフライン中の住民にも保存されます。
予定の作成・編集時には、LB Phoneの写真フォルダから画像を1枚選び、イベントカードの背景として保存できます。
Adminは予定ごとに追加者名を非表示にでき、非Adminへのイベントデータにも名前は含まれません。
LB Phone本体のライト／ダークモード設定に自動追従します。

## 依存

- [lb-phone](https://lbscripts.com/)
- [oxmysql](https://github.com/overextended/oxmysql)
- qbox (qbx_core)

## 導入方法

1. このリポジトリを `resources` フォルダに配置する

   ```
   git clone https://github.com/index-0427/lbphone-calender.git
   ```

2. `calendar.sql` をデータベースに流してテーブルを作成する

   ```
   mysql -u ユーザー名 -p データベース名 < calendar.sql
   ```

   既存環境は、リソース起動時に不足している列・インデックス・参加者テーブルが自動追加されるため、通常は移行SQLの手動実行は不要です。DBユーザーに `ALTER` / `CREATE` 権限がない場合だけ、権限のあるユーザーで次のSQLを実行してください。いずれも再実行可能で、既存データを削除しません。

   ```
   mysql -u ユーザー名 -p データベース名 < calendar_reminders.sql
   ```

   ```
   mysql -u ユーザー名 -p データベース名 < calendar_participants.sql
   ```

   ```
   mysql -u ユーザー名 -p データベース名 < calendar_images.sql
   ```

   ```
   mysql -u ユーザー名 -p データベース名 < calendar_author_visibility.sql
   ```

3. `server.cfg` に追記する(lb-phone・oxmysql より後に読み込むこと)

   ```
   ensure lbphone-calender
   ```

4. サーバーを再起動する。lb-phone のホーム画面に「カレンダー」アプリが追加されます(`defaultApp = true` のため全員に自動配布)。

## 自動DB移行

リソース起動時に `INFORMATION_SCHEMA` から現在のテーブル構造を確認し、必要な構造が不足している場合だけ `CREATE TABLE IF NOT EXISTS` または `ALTER TABLE ... ADD` を実行します。

- `DROP`、`TRUNCATE`、`CREATE OR REPLACE` は実行しません。
- 既存の予定・リマインダー・参加予約データは保持されます。
- 正常時はサーバーコンソールへ `Database schema is ready (existing data preserved)` と表示されます。
- DB権限などで移行に失敗した場合は、カレンダー処理を開始せずエラーをコンソールへ表示します。

## 設定

`shared/config.lua`:

| 項目 | 説明 |
|------|------|
| `Config.AdminAce` | 管理者判定に使う ACE 権限名(既定: `admin`) |
| `Config.ReminderCheckInterval` | リマインダー確認間隔（既定: 60000ミリ秒） |
| `Config.ReminderAudience` | 通知対象。既定の`all`は全住民へ保存し、オフライン時は次回ログイン後に届く。`online`はオンライン中のみ |
| `Config.ReminderNotificationTitle` | LB Phone通知のタイトル |
| `Config.CanAddEvent` | 予定の追加を許可する条件。既定ではジョブまたはギャングのボスに許可 |

## トラブルシューティング

- **アプリが表示されない**: コンソールに `[lbphone-calender] Could not add app:` が出ていないか確認。lb-phone より先に起動していると失敗します。
- **アイコンが古いまま**: `client/main.lua` のアイコン URL 末尾 `?v=2` の数字を上げると再取得されます。
