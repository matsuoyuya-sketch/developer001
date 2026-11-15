# iPLAss 移行スキル（共通部分）

Salesforce のメタデータを iPLAss の定義へリバース移行するための Claude Code スキルと、iPLAss メタデータ定義APIのラッパーです。

案件固有の情報を含まない、再利用できる部分だけを収録しています。

## 収録しているもの

| パス | 内容 |
| --- | --- |
| `skills/` | Salesforce→iPLAss 変換のスキル一式（Entity、画面、レイアウト、フロー、帳票、定義API、Entity CRUD API） |
| `skills/README.md` | スキルとリファレンスの索引。どのファイルをいつ参照するかはここを見る |
| `scripts/iplass/` | iPLAss メタデータ定義API・Entity API のラッパー（`mtp-def.sh` / `mtp-entity.sh` / `mtp-api.sh`）とソース取得スクリプト |
| `CLAUDE.md` | 移行プロジェクトでの共通ルールと、環境固有値の参照方法 |

## 収録していないもの

案件固有の実装（`scripts/sf-to-iplass/` 配下の変換器、fixtures、Groovy の Command / Listener、帳票の JRXML など）は、特定顧客の項目定義・業務ロジック・社名を含むため収録していません。
これらが必要な場合は、案件のリポジトリを参照してください。

`CLAUDE.md` の「このプロジェクトの固有値」には、収録していないパス（`scripts/sf-to-iplass/` など）への参照が残っています。
案件側で使うときの読み替え表として残しているものです。

## 使い方

スキルを使う環境へ配置します。

```sh
mkdir -p ~/.claude/skills
cp -r skills/* ~/.claude/skills/
```

プロジェクト単位で使う場合は、対象プロジェクト直下の `.claude/skills/` へ配置します。

`scripts/iplass/` のラッパーは、接続先と認証情報を `.claude/settings.local.json` の `env` から読みます。
必要な環境変数は `CLAUDE.md` の表を参照してください。
認証情報そのものはこのリポジトリに含まれていません。
