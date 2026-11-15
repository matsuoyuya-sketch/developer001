# scripts/iplass

iPLAss のAPIラッパー3本。`mtp-def.sh` がメタデータ**定義**（`api/mtp/definition`）、
`mtp-entity.sh` が**レコード**（`api/mtp/entity`）、`mtp-api.sh` が**自作のWebApi**
（`api/<WebApi名>`）を扱う。

## mtp-def.sh（メタデータ定義API）

メタデータ定義API（`api/mtp/definition`）のラッパー。接続の4点セットの内容と
トークンの受け渡し方式は `iplass-definition-io` スキル §2 が定義位置（本ラッパーはそれを
隠蔽する実装で、トークンは `curl --config -` で標準入力から渡す）。

**使い分け・書き込み規則・デプロイ手順は `iplass-definition-io` スキルが本体。**
ここには呼び出し方だけを書く。

## 前提

`.claude/settings.local.json` の `env` に `MCP_AUTH_TOKEN` と `IPLASS_HTTP_PROXY` が必要
（雛形: `.claude/settings.local.sample.json`）。未設定なら exit 2 で止まる。
`IPLASS_BASE_URL` は任意（既定値をスクリプト先頭に持つ）。

`env` に書いてあれば**セッションの環境変数として既に入っている**ので、呼ぶ側で `export` し直す必要はない。
`export MCP_AUTH_TOKEN=$(...)` のようにトークンを組み込んだ複合コマンドを作ると、実行が拒否されて
`Permission ... has been denied` で止まることがある。**素の形で1コマンドずつ呼ぶ**。

```bash
# 通る
bash scripts/iplass/mtp-def.sh get entity/<パッケージのパス>/<Entity名> > work/<出力先>.json

# 拒否されることがある
cd <リポジトリ> && export MCP_AUTH_TOKEN=$(...) && bash scripts/iplass/mtp-def.sh post ...
```

書き込み（`post` / `put` / `delete`）を複数まとめて1回で送らず、1件ずつ送って応答を見る。

定義パスは**スラッシュ形式の1引数**で渡す。定義名のドット形式や、種別とEntity名を空白で分けた形は通らない。

```bash
bash scripts/iplass/mtp-def.sh get entity/<パッケージのパス>/<Entity名>   # 通る
bash scripts/iplass/mtp-def.sh get entity <パッケージ>.<Entity名>          # 通らない
```

存在しないパスでも200が返る経路があるため、応答に定義の中身が入っているかを見る（[iplass-definition-io](../../.claude/skills/iplass-definition-io/SKILL.md) §2）。

## サブコマンド

サブコマンドの一覧とMCPツールとの対応は `iplass-definition-io` スキル §2 が定義位置。
ここでは実際の呼び出し例だけ示す。

```bash
bash scripts/iplass/mtp-def.sh get  /entity/<パッケージ>/<Entity名> work/_live-<接頭辞>.json
bash scripts/iplass/mtp-def.sh list /entity/                       work/_live-entity-list.json
bash scripts/iplass/mtp-def.sh list /property/select/              work/_live-svd-list.json
```

`payload.json` は「定義オブジェクトそのまま」。`{"definition":{...}}` でラップしない。
引数なしで実行すると使い方を表示して exit 2 する。

HTTPステータス別の原因は `iplass-definition-io` スキルを参照する。

## mtp-entity.sh（Entity CRUD API）

レコード操作のラッパー。**権限定義（EntityWebApi）・値の形・成否の読み方は
`iplass-entity-crud-api` スキルが本体。** 環境変数の前提は `mtp-def.sh` と同じ。

```bash
bash scripts/iplass/mtp-entity.sh load   <Entity定義名> <oid>
bash scripts/iplass/mtp-entity.sh search <Entity定義名> "prop1 like 'ab%'" "countTotal=true"
bash scripts/iplass/mtp-entity.sh query  "select oid, name from <Entity定義名> limit 10"
bash scripts/iplass/mtp-entity.sh insert <Entity定義名> work/_rec.json
bash scripts/iplass/mtp-entity.sh update <Entity定義名> <oid> work/_rec.json "updateProperties=prop2"
bash scripts/iplass/mtp-entity.sh delete <Entity定義名> <oid>
```

URLに書くのはEntity定義名（ドット区切りのまま。スラッシュへ展開しない）。
`work/_rec.json` は「Entityオブジェクトそのまま」で `definitionName` を含める
（`{"entity":{...}}` でラップしない）。第3〜5引数の後ろに置く文字列はURLへ付ける
クエリ文字列で、操作オプションをここで渡す。引数なしで実行すると使い方を表示して exit 2 する。

`filter` と `query` の値はスクリプト側でUTF-8としてパーセント符号化するので、日本語を含む条件を
そのまま渡せる（`curl --data-urlencode` を使わない理由は `iplass-entity-crud-api` スキル §6）。

## mtp-api.sh（自作WebApiの呼び出し）

自作のWebApi（`api/<WebApi名>`）を叩くラッパー。`get` のみを持つ。環境変数の前提は
`mtp-def.sh` と同じ。

```bash
bash scripts/iplass/mtp-api.sh get mdc/batch/runDailyReportCreateBulk
bash scripts/iplass/mtp-api.sh get mdc/batch/opsDailyReportCreateBulk 'op=start'
bash scripts/iplass/mtp-api.sh get <WebApi名> '<クエリ文字列>' work/_res.json
```

URLに書くのは WebApi 定義の `name`（スラッシュ区切り）。第3引数はURLへ付けるクエリ文字列で、
非ASCIIを含む値は呼び出し側で符号化する（`mtp-entity.sh` のような自動符号化はしない）。
第4引数を渡すと応答をファイルへ落とす。

**呼び出せるのは `supportBearerToken` が true の WebApi だけ。** live の既存WebApiは false の
ものが多く、その場合は `HTTP 403` と `NoPermissionException` が返る。ラッパーの不調ではない。

## fetch-reference-sources.sh（本体ソースの投入）

iPLAss本体のソースを参照用にローカルへ投入する。**メタデータ定義のプロパティ（キー名・許容値・
既定値）を調べるときに引く**ためのもので、調べ方は `iplass-definition-io` スキル §12 が定義位置。

```bash
bash scripts/iplass/fetch-reference-sources.sh          # 既定のバージョン
bash scripts/iplass/fetch-reference-sources.sh 4.1.2    # バージョン指定
```

Java側（Mavenのsources jar）とフロント側（npmパッケージのソースマップから復元）の両方を取る。
`extract-sourcemap.mjs` は後者の復元を担う（単体でも使える）。投入先とバージョンの実体は
`CLAUDE.md` の固有値表を参照する。

**投入先はGit管理外で、開発者が各自の環境で実行する。** 有償版の資格情報（Nexus）が必要で、
`.claude/settings.local.json` の `env` の `IPLASS_NEXUS_USER` / `IPLASS_NEXUS_PASSWORD` を読む。
`IPLASS_HTTP_PROXY` を含めていずれかが未設定なら exit 2 で止まる（`env` を書き足した直後は
起動中のセッションに反映されないので、セッションを開き直す）。何度実行しても同じ内容で上書きされる。
