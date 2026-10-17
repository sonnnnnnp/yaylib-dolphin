# yaylib-dolphin

[Yay!](https://yay.space) の非公式 API クライアントを、[Dolphin](https://github.com/sonnnnnnp/dolphin) で書いたものです。[ekkx/yaylib](https://github.com/ekkx/yaylib)（Go・TypeScript・Python・Rust、MIT）の移植契約（`PORTING.md`）に沿って作っています。

> **非公式です。** Yay! の公式なものではなく、API は予告なく変わります。利用規約を守り、サーバーに負担をかけない範囲で、自己責任で使ってください。
>
> **実サーバーでは確かめていません。** 署名の期待値（`PORTING.md` のゴールデン値）と、偽のサーバーに対するテストだけで確かめています。ログインして動かす場合は、最初は小さく試してください。

## できること

- **全 247 オペレーション**を、`yaylib.get_timeline[@c, {…}]` のような関数で呼べる（元の `gen/api_*.go` から `tools/gen.py` が表を作る）
- **ログイン**: セッションのキャッシュ → ブラウザ版 → アプリ版（`error_code` が 401 のときだけ切り替え）。トークンの自動更新（401 で 1 回だけ更新して送り直す）。セッションをファイルに保存
- **署名**: `signed_info`・`signed_version`・`X-Jwt`（期待値と一致するテストあり）
- **アップロード**: 画像（縦横を調べ、サムネイルを作り、署名付き URL へ PUT）・動画。13 種類のカテゴリ
- **イベントストリーム**: `wss://cable.yay.space`（ActionCable）。購読・自動再接続・購読のやり直し
- **再試行**: 5xx と通信の失敗は GET などだけ、429 はすべて。サーバーの `retry_in` に従う
- **ホストの振り分け**・必須ヘッダーの付与・エラーの構造化（種類 `"api"`、詳細は `err_data`）

## 使うには

Dolphin **0.47.0 以降**が要ります（`wss://`・`ws.connect_async`・`std:image`・パッケージ・エラー値の詳細を使うため）。

```
git clone https://github.com/sonnnnnnp/yaylib-dolphin dolphin_modules/yaylib
```

`dolphin_modules/` は、使うスクリプトのあるディレクトリか、その上の階層に置きます（または環境変数 `DOLPHIN_PATH` で指すディレクトリに）。そうすれば `import["yaylib"]` で読めます。

```
@yay := import["yaylib"]
@c := @yay.new_client[{"session_store": @yay.file_session_store["session.json"]}]

// ログイン（失敗はエラー値。`?` で呼んだ関数からそのまま返せる）
@yay.login_with_email[@c, {"email": "me\@example.com", "password": "…"}]?

// タイムラインを読む
@tl := @yay.get_timeline[@c, {"noreply_mode": "", "number": 20}]?
for @post in @tl{"posts"} (
    log[@post{"id"}, @post{"text"}]
)

// 画像つきで投稿する
@data := file_read_bytes["photo.png"]?
@names := @yay.upload_post_images[@c, {{"filename": "photo.png", "data": @data}}]?
@yay.create_post[@c, {"post_type": "image", "text": "こんにちは", "attachment_filename": @names{0}}]?
```

パラメーターは 1 つのマップで渡します。キーは、パスの `{名前}`・クエリ・フォーム・ヘッダー（`X-Jwt` は `x_jwt`）の名前、JSON の本文は `body` です。使えるキーは `mod.dol` の各関数の上のコメント（LSP のホバーにも出ます）か、`yay.operations[]` で見られます。表にないキーは実行時エラーです。渡さなかったものは送りません。

### エラー

サーバーが 2xx 以外を返すと、種類 `"api"` のエラー値になります。

```
@r := @yay.get_timeline[@c, {"noreply_mode": ""}]
if is_error[@r] (
    if err_kind[@r] == "api" (
        log[@yay.status_of[@r], @yay.code_of[@r], err_message[@r]]
        // 詳細（本文・ヘッダー・retry_in など）
        log[err_data[@r]]
    )
    // 通信の失敗は std:http のエラー値のまま（"network" "timeout"）
)
// 名前でコードを比べる
if @yay.code_of[@r] == @yay.error_codes[]{"required_2fa"} ( log["2 要素認証のコードが要ります"] )
```

### イベントストリーム

```
@s := @yay.open_event_stream[@c, {"on_error": [@e] ( log["あきらめました:", err_message[@e]] )}]
@yay.subscribe[@s, @yay.chat_room_channel[], {
    "on_event": [@ev] (
        if @ev{"type"} == "NewMessageEvent" ( log["新着:", @ev{"data"}] )
    )
}]
@yay.run[]      // イベントループ。Ctrl+C で終わるまで動く
```

イベントは `{"type": "NewMessageEvent", "name": "new_message", "data": …}`。知らないイベントは `"type": "RawEvent"` で届きます。

## サンプル

[`examples/`](examples/) に、本家の `examples/` と同じ題材（タイムライン・投稿・イベントストリーム・セッションとエラー処理）と、画像つきの投稿があります。

```
YAY_EMAIL=... YAY_PASSWORD=... dolphin examples/timeline.dol
```

## 設定

`new_client` のオプションで変えられます（Go 版の `WithXxx` と同じ名前を snake_case に）: `base_url`・`cassandra_base_url`・`event_stream_url`・`api_key`・`web_api_key`・`api_version_key`・`api_version_name`・`app_version`・`device_*`・`user_agent`・`device_info`・`connection_type`・`accept_language`・`http_timeout`・`retry`（`max_attempts` `base_delay` `max_delay` `retry_on_post`）・`session_store`・`logger`・`device_uuid`・`client_ip`。

ロガーは `[@level, @event, @fields]` を受ける関数です（既定は何も出しません。トークン・パスワード・署名・本文は渡しません）。

## 作りと再生成

```
src/mod_head.dol   mod.dol の手書きの前半（公開 API）
mod.dol            生成物。オペレーションの関数が並ぶ
src/ops_table.dol  生成物。オペレーションの表
src/call.dol       表の 1 行からリクエストを組み立てて送る
src/transport.dol  ヘッダー・ホスト・再試行・401 の更新
src/auth.dol       ログインとセッション
src/session.dol    セッションストア
src/upload.dol     アップロード
src/event_stream.dol  イベントストリーム
src/signing.dol / errors.dol / client.dol / util.dol
tools/gen.py       ekkx/yaylib の gen/ から表を作る
```

```
python tools/gen.py --fetch   # 元のソースを取得して、表と mod.dol を作り直す
dolphin test tests            # テスト（偽の通信で動く。ネットワーク不要）
```

通信はクライアントの `send` 関数を通ります（既定は `std:http`）。テストでは偽物に差し替えています。

実際の HTTP 通信での確認には、`tests/e2e/run.sh`（Dolphin で書いた偽の Yay! サーバーを立てて、ログイン・トークンの更新・投稿を通す）を使えます。実サーバーには何も送りません。

## Go 版との違い

- 言語に合わせて、ビルダー（`.Number(20).Execute()`）ではなく、パラメーターのマップで渡します
- 同時実行はありません。呼び出しはブロッキングで、イベントストリームだけがコールバックです
- 複数の失敗を同時には返せないので、`login_with_email` でセッションを保存できなかったときは、種類 `"session_save_failed"` のエラー値（`err_data` の `"response"` に応答。トークンは設定済み）にします
- `X-Client-IP` は、最初のリクエストのあとで同期的に 1 回だけ調べます
- 署名付き URL への PUT は、順番に送ります（最初の失敗で止まります）
- セッションファイルの権限（`0600`）は設定できません

## ライセンス

MIT。元の [ekkx/yaylib](https://github.com/ekkx/yaylib)（© ekkx）の移植を含みます。`LICENSE` を見てください。
