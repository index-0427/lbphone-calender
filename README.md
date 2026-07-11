# lbphone-calender

lb-phone 用のサーバー共有カレンダーアプリ(qbox 向け)。
全プレイヤーが同じカレンダーを閲覧でき、管理者やジョブ/ギャングのボスが予定を追加・編集・削除できます。

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

3. `server.cfg` に追記する(lb-phone・oxmysql より後に読み込むこと)

   ```
   ensure lbphone-calender
   ```

4. サーバーを再起動する。lb-phone のホーム画面に「カレンダー」アプリが追加されます(`defaultApp = true` のため全員に自動配布)。

## 設定

`shared/config.lua`:

| 項目 | 説明 |
|------|------|
| `Config.AdminAce` | 管理者判定に使う ACE 権限名(既定: `admin`) |
| `Config.CanAddEvent` | 予定の追加を許可する条件。既定ではジョブまたはギャングのボスに許可 |

## トラブルシューティング

- **アプリが表示されない**: コンソールに `[lbphone-calender] Could not add app:` が出ていないか確認。lb-phone より先に起動していると失敗します。
- **アイコンが古いまま**: `client/main.lua` のアイコン URL 末尾 `?v=2` の数字を上げると再取得されます。
