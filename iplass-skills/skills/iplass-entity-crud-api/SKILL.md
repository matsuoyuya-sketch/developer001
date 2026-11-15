---
name: iplass-entity-crud-api
description: iPLAssのEntity CRUD API(api/mtp/entity)でレコードを検索・取得・登録・更新・削除するとき、対象EntityをAPIへ公開する権限定義(EntityWebApi)を作る・変更するとき、EQLやwhere句で検索するとき、レコード操作のオプション(バリデーション省略・更新対象プロパティ指定・件数取得)を使うとき、200 SUCCESSなのにデータが入っていない・意味の分からない500が返る・日本語条件で1件も一致しないといった症状に当たったときに使う。
---

# Entity CRUD APIでのレコード操作

メタデータ**定義**の読み書きは [iplass-definition-io](../iplass-definition-io/SKILL.md) が担う。本スキルは**レコード(データ)**の操作を担う。EQLの文法は `iplass-dev:iplass-query`、プロパティ型の意味は `iplass-dev:iplass-entity` が一次情報。

環境固有の値(ベースURL・Entityパッケージ名・認証用の環境変数)は [CLAUDE.md](../../../CLAUDE.md) の固有値表を参照する。

## 1. 経路とエンドポイント

エンドポイントは `<ベースURL>/api/mtp/entity`。ラッパー `scripts/iplass/mtp-entity.sh` が接続の4点セット(社内プロキシ・自己署名証明書・`X-Requested-With`・`Authorization: Bearer`)を隠蔽する。定義APIのラッパーと同じ環境変数を使い、未設定なら終了コード2で止まる。

| サブコマンド | HTTP | 用途 |
|---|---|---|
| `load <Entity定義名> <oid> [version] [追加クエリ]` | GET | oid指定でロード |
| `search <Entity定義名> <where句> [追加クエリ]` | GET | `filter`でwhere句を指定して検索 |
| `query <EQL> [追加クエリ]` | GET | EQL文で検索(Entity名はEQL側に書く) |
| `insert <Entity定義名> <entity.json> [追加クエリ]` | POST | 登録 |
| `update <Entity定義名> <oid> <entity.json> [追加クエリ]` | PUT | 更新 |
| `delete <Entity定義名> <oid> [追加クエリ]` | DELETE | 削除 |

URLに現れるのは**Entity定義名(ドット区切りのまま)**である。定義APIのパスのようにスラッシュへ展開しない(例: `api/mtp/entity/<パッケージ>.<Entity名>/<oid>`)。

メソッドごとに受け付ける形式が違う。ラッパーはこの組み合わせを固定している。

| メソッド | 受け付ける形式 | 送り方 |
|---|---|---|
| GET / DELETE | `REST_FORM`のみ | パラメータはクエリ文字列で送る。`Content-Type`は付けない |
| POST / PUT | `REST_JSON`(POSTは`REST_FORM`も) | 本文にEntityのJSONを生で送る。オプションはクエリ文字列 |

## 2. 権限定義(EntityWebApi)

**Entityは既定でこのAPIに公開されていない。** 操作するには `/entityWebapi/<Entity定義名をスラッシュに展開したパス>` に `EntityWebApiDefinition` が存在し、該当操作のフラグが `true` である必要がある。定義の読み書きは定義API/MCP経由で行う(手順は [iplass-definition-io](../iplass-definition-io/SKILL.md))。

```json
{"@class":"org.iplass.mtp.webapi.definition.EntityWebApiDefinition",
 "name":"<Entity定義名>","query":true,"load":true,"insert":true,"update":true,"delete":true}
```

| フラグ | 許可する操作 |
|---|---|
| `load` | `load`(oid指定のロード) |
| `query` | `search`(filter) / `query`(EQL) |
| `insert` | `insert` |
| `update` | `update` |
| `delete` | `delete` |

`name` はEntity定義名(ドット区切り)、パスはそれをスラッシュへ展開した形。未存在なら `post`、既存なら `put`(全置換なのでフラグ5つを毎回すべて載せる)。定義を `delete` すればそのEntityは再び非公開に戻る。

権限が無い状態(定義が無い / 該当フラグが `false`)での呼び出しは、どちらも同じ**HTTP 500 + `WebApiRuntimeException` "System error occurred. See server log detail."** になる。原因が本文から読み取れないので、この500を見たらまず `/entityWebapi/` の一覧と対象定義のフラグを確認する。

## 3. リクエスト本文とプロパティ値の形

`insert` / `update` の本文は**Entityオブジェクトそのまま**。`{"entity":{...}}` でラップすると400になる。`definitionName` は必須で、欠けていると400になる(URLにEntity名があっても補われない)。`update` では `oid` も本文に入れる。

```json
{"definitionName":"testa","name":"レコード名","prop1":"abc","prop2":10,"prop4":true}
```

JSON形式での値の書き方(型ごと)。

| 型 | 送信時 | 取得時のレスポンス |
|---|---|---|
| Date | `"yyyy-MM-dd"` | 同じ文字列 |
| DateTime / Timestamp | エポックミリ秒(数値) | エポックミリ秒 |
| Time | `"HH:mm:ss"` | 同じ文字列 |
| Select | 値の文字列、または `{"value":"<値>"}`。多値なら配列 | `{"value":..,"displayName":..}` の配列/オブジェクト |
| Reference | `{"definitionName":"<参照先Entity定義名>","oid":"<oid>"}` | 同形 |
| Binary | lobId | lobId |
| Boolean | `true` / `false` | 同じ |

**送信形と取得形は非対称**(Select・stateは取得時だけ `displayName` が付く)。取得した結果をそのまま送り返す運用にはせず、更新は変えたいプロパティだけを送る。

**型に合わない値は例外にならず黙って変換される**: Integerプロパティへ数値でない文字列を送ると `{"status":"SUCCESS"}` が返り、値は `0` になる。バリデーションでも捕まらないので、**送信前に型を合わせる**か、投入後に `load` して値を照合する。

## 4. 操作ごとのオプションと戻り

オプションはクエリ文字列で渡す。`withValidation` 等の各オプションは、対象ロール(`PermitEntityCrudApiOptionsRoles`)または管理者でのみ有効。

| 操作 | 主なオプション | 戻り |
|---|---|---|
| `load` | `withMappedByReference`(既定false) | `entity` |
| `search` / `query` | `countTotal`(件数を`count`で返す) / `tabular`(表形式。`listHeader`と値配列で返す) | `list` / `listHeader` / `count` |
| `insert` | `withValidation`(既定true) / `notifyListeners`(既定true) / `regenerateOid`(既定true) / `regenerateAutoNumber` / `versionSpecified` | `oid` |
| `update` | `updateProperties`(カンマ区切り) / `withValidation` / `notifyListeners` / `checkTimestamp`(既定true) / `forceUpdate` / `targetVersion`(`CURRENT_VALID`/`SPECIFIC`/`NEW`) | `oid`(バージョン管理時は`version`も) |
| `delete` | `timestamp` | `status` |

**`update` は送ったプロパティだけを更新する**(本文に無いプロパティは元の値を保つ)。**値をNULLにするときだけ `updateProperties` を使う**: 本文からそのプロパティを省き、`updateProperties=<プロパティ名>` を付けると対象がNULL化される。

## 5. 成否の読み方

レスポンスは常に `status`("SUCCESS" / "FAILURE")を持ち、失敗時は `exceptionType` と `exceptionMessage` が付く。HTTPステータスと `status` の組み合わせで原因を分ける。

| 症状 | 原因 |
|---|---|
| 500 + `WebApiRuntimeException` "System error occurred..." | 権限(§2)。またはEntity定義名の誤り |
| 500 + `EntityValidationException` | バリデーション違反。`exceptionMessage` にプロパティ名と理由が入る |
| 500 + `EntityConcurrentUpdateException` "already been deleted" | `update` 対象のoidが存在しない、またはタイムスタンプ不一致 |
| 400(本文なし) | 本文の形が違う(`{"entity":{...}}` でラップした / `definitionName` が無い) |
| 415 | GET/DELETEに`Content-Type`を付けた、または本文の形式がWebApi定義の`accepts`と合わない |
| 401 | `Authorization: Bearer` の欠落・不正 |
| 500(本文なし・`Content-Length:0`) | `X-Requested-With: XMLHttpRequest` ヘッダの欠落 |
| 200 SUCCESS だが `entity` キーが無い | 対象oidが存在しない(不在はエラーにならない) |
| 200 SUCCESS の `delete` | 不在のoidでも成功が返る。消えたことは `search` で確認する |

**`{"status":"SUCCESS"}` は意図どおり入った証拠ではない**(§3の黙った型変換、不在oidの`delete`)。登録・更新のあとは `load` か `search` で値を照合する。

## 6. 検索条件の非ASCII文字とクエリ文字列の符号化

日本語を含む値の登録・取得・検索はいずれも可能。ただし `search` の `filter` と `query` の EQL は**クエリ文字列**で送るため、条件中の非ASCII文字をUTF-8でパーセント符号化しないと**エラーにならずに空の `list`** が返る(データが無いのと区別できない)。

**`curl --data-urlencode` は使わない**: Windows版curlはこのオプションの値をANSIコードページ(日本語環境ではCP932)へ変換するため、シェル上はUTF-8の文字列でも別のバイト列で送信され、条件が一致しなくなる。ラッパーはこれを避けて自前でパーセント符号化しており、`search` / `query` に日本語の条件をそのまま渡せる。

素のcurlで叩くときは、クエリ文字列を**UTF-8として符号化した文字列**を組み立ててURLへ埋める(未符号化の非ASCII文字を直接URLに置くと、Tomcatが `Invalid character found in the request target` の400を返す。このときエラー本文に実際の送信バイトが出るので、意図した文字コードで送れているかを確かめられる)。

同じ症状に見えても原因が違うものと切り分ける。

| 症状 | 原因 |
|---|---|
| 条件を付けると空、条件なしなら取得できる | 条件の符号化(本節)。ASCIIのみの条件で試すと切り分けられる |
| select の項目を1つだけ書くと500 | **選択項目は2つ以上必要**。`oid` を添える(`select oid, <項目>`) |
| Referenceプロパティや参照のパス式(`<参照>.<項目>`)を select に書くと500 | **`.oid` 以外は select に書けない**。参照先の値が要るなら、参照先Entityを別に検索するか、Expressionプロパティとして評価させる |
| 宣言項目をまとめて select すると500、個別なら通る | 上の2つが混ざっている。Referenceを含む範囲は必ず失敗するので、**この方法で「壊れた項目」を二分探索してはいけない**(APIの制約を項目の不具合と読み違える) |
| where句に `<参照> is not null` と書くと500 | 参照そのものはwhere句でもnull判定できない。`<参照>.oid is not null` の形にする(select と同じく `.oid` は書ける) |
| 条件なしでも空 | データが無い、または対象Entity名の誤り |
| 400 `Invalid character found in the request target` | 非ASCII文字を未符号化でURLに置いた |

## 7. 検証の手順

レコード操作を伴う作業は、本番相当のEntityへ直接当てず次の順で確かめる。

1. **権限を確認**: `/entityWebapi/` の一覧を取り、対象Entityの定義とフラグを見る(§2)。無ければ作る。作った場合は**作業後に元の状態へ戻す**(元から無かったなら定義を削除する)。
   **開ける前のフラグを記録してから開ける。** 更新は全置換なので、戻すときに元の値を知らないと戻せない。**全フラグを `false` にするのは「元の状態」ではない**——既存の定義で一部のフラグだけを足した場合、全部 `false` にすると開ける前より狭くなり、その経路を使っている他の作業を壊す。足したフラグだけを `false` に戻す。
2. **1件で往復させる**: `insert` → `load` で値を照合 → `update` → `load` → `delete` → `search` で消滅を確認。型ごとの値の形(§3)はこの往復で確かめる。
3. **検索を確かめる**: 条件に非ASCIIを含まない形で `search` / `query` を実行する(§6)。
4. **検証で作ったレコードを消す**: `delete` で片付け、`search` で残っていないことを確認する。
   **消したレコードを指している参照は、明示的に外す。** 参照先の削除で参照側が自動で空になる挙動を
   見かけても、それを前提に後片付けを設計しない（保証を確かめていない）。消す順は「参照を外す →
   レコードを消す」にする。**権限を閉じる前に消滅を確認する**（閉じると引けなくなる）。

## 8. 引けない・一致しないときに見るところ

権限(§2)と符号化(§6)が問題ない場合に残る症状。

| 症状 | 見るところ |
|---|---|
| 参照プロパティを辿るパス式で500になる | **参照先の宣言プロパティは選択できない。** `<参照項目>.oid` は通るが、参照先が持つ宣言プロパティを選ぶと500になる(参照先のEntityの権限を開けても変わらない)。参照先の値が必要なら、`.oid` で参照先のoidを取って別途 `load` する。**Commandの中では参照先を読み直せる**ので、この制約はこのAPI経路だけの話である(読み直しの作法は [converting-salesforce-screens-to-iplass](../converting-salesforce-screens-to-iplass/SKILL.md) §3) |
| 日付の比較で500になる | **日付はクォートした文字列リテラルで書く**(`<日付項目> < 'YYYY-MM-DD'`)。型を明示する接頭辞を付けた形(`date'…'`)は通らない |
| 本日日付を条件に入れたい | **`CURRENT_DATE` / `TODAY()` / `SYSDATE` はいずれも通らない**（選択項目に置いても条件に置いても500）。日付は**呼び出す側で組んで文字列リテラルとして渡す**。評価時点で値が変わる計算をEntityの数式に持たせない判断は [../converting-salesforce-to-iplass-entity/references/property-mapping.md](../converting-salesforce-to-iplass-entity/references/property-mapping.md) §14 が定義位置 |
| Boolean(SFのCheckbox由来)の条件で1件も一致しない | **移行しただけのレコードはこの型の値を持たない。** `= false` は値が `false` の行だけを拾うので、値が無い行には一致しない(`= true` は真の行を拾うので機能する)。件数を数えるだけなら `= true` を使い、「真でないもの」を選ぶときは**条件を外して取得し、取得後に値を見る**。iPLAss側の判定も値が無い場合を「真でない」として扱う形になっているか併せて確かめる |

どちらも例外の本文からは読み取れない。**条件を1つずつ外して、どこで500や0件に変わるかを見る**のが最短である。

## リファレンス

| 参照先 | 用途 |
|---|---|
| [iplass-definition-io](../iplass-definition-io/SKILL.md) | 権限定義(EntityWebApi)そのものの取得・作成・更新・削除、接続の4点セット |
| `iplass-dev:iplass-query` | EQL(where句・集約・パス式)の文法 |
| `iplass-dev:iplass-entity` | プロパティ型と多重度の意味 |
| [../../../scripts/iplass/README.md](../../../scripts/iplass/README.md) | ラッパーの呼び出し例 |
