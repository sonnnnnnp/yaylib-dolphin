# examples

[ekkx/yaylib](https://github.com/ekkx/yaylib) の `examples/` と同じ題材のサンプルです。

- `timeline.dol` — 認証 + タイムライン取得
- `post.dol` — テキスト投稿
- `image_post.dol` — 画像つきの投稿（アップロード → 投稿）
- `event_stream.dol` — イベントストリームの簡単なボット
- `session_and_errors.dol` — セッション永続化とエラー処理

いずれも `YAY_EMAIL` / `YAY_PASSWORD` を環境変数で渡して、リポジトリの中から実行します（`../mod.dol` を読みます）。
`yaylib` を `dolphin_modules/` に置いて使うときは、`import["../mod.dol"]` を `import["yaylib"]` に変えてください。

```bash
# bash / macOS / Linux
YAY_EMAIL=... YAY_PASSWORD=... dolphin examples/timeline.dol

# PowerShell
$env:YAY_EMAIL = "..."; $env:YAY_PASSWORD = "..."; dolphin examples\timeline.dol
```

画像つきの投稿は、画像のパスを引数で渡します。

```bash
YAY_EMAIL=... YAY_PASSWORD=... dolphin examples/image_post.dol photo.png "写真を載せます"
```

`YAY_BASE_URL` を渡すと、接続先（API のホスト）を変えられます。本物のサーバーに送らずに試すには、`tests/e2e/mock_server.dol` で偽のサーバーを立てて、`YAY_BASE_URL=http://127.0.0.1:18765` を指します。

> 非公式の API です。アカウントのメールアドレスとパスワードを使うので、取り扱いに気をつけてください。
