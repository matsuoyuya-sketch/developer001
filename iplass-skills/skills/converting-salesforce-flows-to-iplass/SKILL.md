---
name: converting-salesforce-flows-to-iplass
description: Salesforceのフロー(スケジュール済みフロー・レコードトリガフロー・画面フロー)をiPLAssへ移すとき、移行先(ScheduledTask / EventListener / 画面)を判定するとき、Cronでのスケジュール実行を組むとき、SFの入力規則ではないレコード変更の連鎖をEventListenerで表すとき、SFのIsChangedをiPLAssで表すとき、投入したのにスケジュールが実行されないときに使う。
---

# SFのフロー → iPLAss

SFのフローは1つの機能ではなく、種類ごとに移行先が違う。**まず型を見分けて引き先を決め**、
そのうえで本スキルの規則に従う。環境固有の値（パッケージ名・ベースURL・定義の置き場）は
[CLAUDE.md](../../../CLAUDE.md) の固有値表を見る。道具のCLI仕様は
[scripts/sf-to-iplass/batch/README.md](../../../scripts/sf-to-iplass/batch/README.md)。

## 1. 型を見分ける

`.flow-meta.xml` の `processType` と `start` の中身で決まる。

| SF側 | 移行先 | 引き先 |
|---|---|---|
| `triggerType` が `Scheduled` | ScheduledTask定義 ＋ Command | 本スキル §3・§4 |
| `triggerType` が `RecordAfterSave` / `RecordBeforeSave` | 対象EntityのEventListener | 本スキル §5 |
| `processType` が `Flow`（画面フロー） | 宣言的画面かカスタム画面 | [converting-salesforce-screens-to-iplass](../converting-salesforce-screens-to-iplass/SKILL.md) |
| `processType` が `AutoLaunchedFlow` でサブフロー（他フローから呼ばれるだけ） | 呼び出し側と一緒に1つのCommandへ寄せる | 本スキル §4 |

**移す前に3つを確かめる。**

1. **`status` を見る。** `Obsolete` のフローは移さない。同じ処理がActiveとObsoleteで2本あることが
   あり、Obsolete側にだけある分岐（休日を除く等）を拾うと現行と挙動が変わる。
2. **対になるフローを探す。** SFでは「バッチが日付項目を打つ」「その項目の変化でトリガが子レコードを
   作る」のように2本で1つの処理になっていることがある。**片方だけ移すと動く形にならない。**
   依頼が片方だけでも、対の有無は確認して申し送る。
3. **`formulas` の参照の有無を見る。** フロー定義に数式があっても、そのフローの中から参照されて
   いないことがある（別フローからのコピー由来）。参照されていない数式は移さない。

## 2. 移行先の全体像

2段構えのフローは、iPLAssでも2段のまま写すのが素直である。前段と後段を分けておくと、
SFと同じく後段の起点（日付項目の変化）を画面操作や手動更新からも起こせる。

| 段 | iPLAssの定義 |
|---|---|
| 起動（スケジュール） | ScheduledTask定義 |
| 処理本体 | スクリプト実装のCommand定義 |
| レコード変更の連鎖 | 対象EntityのEventListener（Entity定義の `eventListenerList`） |

処理が1手ならワークフロー定義は使わない（重すぎる）。

## 3. ScheduledTask定義

パス接頭辞は `/schedule/`。クラスとフィールドは次のとおり。**フィールド名は資料より実物に
合わせる**（`historyLogging` は `is` が付かない）。写す実物が要るときは、テナントに元から入って
いる標準のScheduledTask定義を1つ `get` する。

```json
{"@class":"org.iplass.mtp.scheduling.definition.ScheduledCommandDefinition",
 "name":"<定義名>","displayName":"<表示名>","description":"<説明>",
 "schedule":{"@class":"org.iplass.mtp.scheduling.definition.schedules.CronExpressionSchedule",
             "expression":"0 0 8 * * ?"},
 "executeAsUserExpressionSpec":"NONE","queue":"default",
 "exceptionHandlingMode":"ABORT_LOG_FATAL","historyLogging":true,
 "commandConfig":{"@class":"org.iplass.mtp.command.definition.config.SingleCommandConfig",
                  "transactionPropagation":"REQUIRED","rollbackWhenException":true,
                  "throwExceptionIfSetRollbackOnly":false,"commandName":"<Command定義名>"}}
```

| 設定 | 決め方 |
|---|---|
| `schedule` | Cronは秒から始まる7フィールド。日を指定したら曜日は `?`。SFの `startTime` は**組織のタイムゾーンで読む**（メタデータ上は `Z` 付きでもUTCとは限らない） |
| `executeAsUserExpressionSpec` | `NONE` はシステムユーザーの特権実行。SFのスケジュール済みフローがフロー作成者の権限で全レコードを対象に走るので、権限で対象を取りこぼさないよう `NONE` にする |
| `exceptionHandlingMode` | `ABORT_LOG_FATAL`。`RESTART` は同じ失敗を繰り返す |
| `historyLogging` | true。実行状況をAdminConsoleのQueueExplorerで追えるようにする |

**`schedule` の他の形**: 一定間隔なら `FixedDelaySchedule` / `FixedRateSchedule`（`unit` と
`period`）、次回実行日時をScriptで返すなら `CustomSchedule`。

### 有効化は定義ではない

**定義を投入しただけでは実行されない。** AdminConsoleの「スケジュールの実行設定」でActiveに
するか、`ScheduledTaskManager.start(定義名, null)` を呼ぶ必要がある。定義APIの経路だけで
済ませたいときは、start / stop / status を行うCommandとWebApiを一時的に置き、有効化を終えたら
削除する（バッチを起こせるAPIを残さない）。

`start` は `RdbQueueService.useQueue=false` で失敗する。スケジューラは非同期キューの上で動くので、
service-config の `org.iplass.mtp.impl.async.rdb.RdbQueueService` に
`<property name="useQueue" value="true" />` が要る（サーバ再起動を伴う）。**定義APIでは直せない**
ので、この状態に当たったら定義の投入までで止めて設定を依頼する。

Active後の予約はサーバを止めても残り、**停止中に実行予定を過ぎた予約は起動後にまとめて実行
される**。この性質が §5 の重複チェックの理由になる。

## 4. 処理本体のCommand

スクリプト実装（`ScriptingCommandDefinition`、パス接頭辞 `/commandClass/`）で書く。書き方の
制約と更新が反映されないときの対処は
[iplass-definition-io](../iplass-definition-io/SKILL.md) §4。**本文には版マーカーを必ず持たせ、
レスポンスかログで反映を判定する。**

| SFのフロー要素 | Commandでの書き方 |
|---|---|
| `recordLookups`（レコードを取得） | `EntityManager#search(Query, Predicate)`。スカラを選ぶなら `Object[]` で受ける |
| `recordUpdates`（レコードを更新） | `EntityManager#update(Entity, UpdateOption)`。`UpdateOption#setUpdateProperties` で対象を絞り、他項目と数式に触らない |
| `recordCreates`（レコードを作成） | `EntityManager#insert(Entity)` |
| `loops` / `assignments` | Groovyのループと変数 |
| `$Flow.CurrentDate` | §4.1 の基準日 |
| `$Label.<名前>`（カスタムラベル） | 値の移し先は [converting-salesforce-screens-to-iplass](../converting-salesforce-screens-to-iplass/SKILL.md) §5 |

**1件ずつトランザクションを分ける**（`Transaction.requiresNew`）。全件を1トランザクションに
すると1件の不整合で当日分が丸ごと落ちる。失敗した件数とoidはログとレスポンスに出す。

処理件数（対象・更新・スキップ・失敗）をレスポンス属性で返すようにしておくと、手動起動での
検証がそのまま結果の確認になる。

### 4.1 基準日は予定日から取る

`$Flow.CurrentDate` をそのまま「実行時の当日」に置き換えない。iPLAssは停止中に過ぎた予約を
起動後にまとめて実行するので、**予定されていた日付**で処理するほうが意図に合う。

予定日時は `RequestContext` の attribute `mtp.scheduling.scheduledTime`
（`ScheduledTaskRequestConstants.SCHEDULED_TIME`）に `java.sql.Timestamp` で入る。手動起動では
入らないので、取れないときは実行時の当日へフォールバックする。

## 5. EventListenerで表す

対象Entityの定義の `eventListenerList` へ、スクリプト実装のリスナを足す。

```json
{"@class":"org.iplass.mtp.entity.definition.listeners.ScriptingEventListenerDefinition",
 "withoutMappedByReference":true,"listenEvent":["AFTER_UPDATE"],"script":"<本文>"}
```

`listenEvent` に置ける値は `BEFORE_VALIDATE` / `BEFORE_INSERT` / `AFTER_INSERT` /
`BEFORE_UPDATE` / `AFTER_UPDATE` / `BEFORE_DELETE` / `AFTER_DELETE` / `ON_LOAD` /
`AFTER_RESTORE` / `AFTER_PURGE`。SFの `RecordAfterSave` は `AFTER_INSERT` / `AFTER_UPDATE`、
`RecordBeforeSave` は `BEFORE_INSERT` / `BEFORE_UPDATE` に対応する。

本文には `entity` / `event` / `context` / `user` / `date` がバインドされる。

**Entity定義への追記は全置換更新になる。** liveを土台に `eventListenerList` の1キーだけを
足し、投入前に「差分がその1キーだけか」を機械で確かめる。`propertyList` を取り違えると
`{"status":"SUCCESS"}` を返しながら全項目が消える（規則は
[iplass-definition-io](../iplass-definition-io/SKILL.md) §4）。投入後は件数とプロパティ名の
集合を照合し、あわせて対象Entityのmdc Viewが読めることも見る。

### 5.1 IsChanged を表す

SFの起動条件 `IsChanged` は、`AFTER_UPDATE` と `EntityEventContext` の attribute
`beforeUpdateEntity` の組で表す。この attribute は、リスナが1つ以上あって `notifyListeners` が
true のとき**サーバが毎回ロードして入れる**ので、自分で取りに行かなくてよい。

判定は次の順で行う。**順番を守る。**

1. `EntityEventContext` の attribute `updateOption` から `getUpdateProperties()` を取り、
   対象プロパティが含まれていなければ何もしない。**対象プロパティを絞った更新では `entity` に
   載っていない項目が null に見えるため**、値の比較より先にこれを見る必要がある。
   `getUpdateProperties()` が null なら全項目更新なので値の比較へ進む。
2. `entity` 側の値が null なら何もしない（項目が空になる更新）。
3. `beforeUpdateEntity` 側の値と一致するなら何もしない。

`withoutMappedByReference` を true にすると `beforeUpdateEntity` のロードが軽くなる。被参照を
見ないリスナでは true にする。

### 5.2 SFに無いガードを足す

スケジューラの積み残し実行（§3）があるため、**レコードを作るリスナには重複チェックを入れる。**
「同じ親・同じ日付の子レコードが既にあれば作らない」を作成前に確かめる。SFにこのガードは無いが、
入れないと同じ日付の子レコードが2件できる。

日付が空になる更新でレコードを作らないのも、SFとの意図的な差である（SFは空の日付で作ってしまう）。
**このような意図的な差は、移した本文のコメントと申し送りの両方に残す。**

### 5.3 独自のNameプロパティ

このプロジェクトのEntityは必須の宣言プロパティ `Name` を持つ。これは
`GenericEntity#setName()` が設定するシステム項目 `name` とは**別のプロパティ**である。
`setName()` だけではその `Name` が null のまま `EntityValidationException` になる。
`setValue('Name', 値)` で入れる（定型プロパティの位置づけは
[converting-salesforce-to-iplass-entity/references/property-mapping.md](../converting-salesforce-to-iplass-entity/references/property-mapping.md) §15）。

### 5.4 after-saveで自レコードを更新するフロー

SFの `RecordAfterSave` のうち、`recordUpdates` の `inputReference` が `$Record` のもの
（自分自身の項目を打つだけのフロー）は、`AFTER_*` ではなく **`BEFORE_INSERT` /
`BEFORE_UPDATE` で保存前の `entity` へ直接書く**。SFのafter-saveによる `$Record` 更新は
再帰しない特別扱いなので、そのまま `AFTER_*` へ写して `EntityManager#update` を呼ぶと、
更新が二重になり履歴も2件になる。この差は意図的なものとして本文のコメントに残す。

`BEFORE_UPDATE` で書くときは、**書いたプロパティを更新対象へ足す**。
`UpdateOption#setUpdateProperties` で対象を絞った更新では、載っていないプロパティは
書かれずに消える。作法は `org.iplass.mtp.impl.auth.UserEntityEventListener#beforeUpdate`
と同じで、`EntityEventContext` の attribute `updateOption` から取った
`getUpdateProperties()` へプロパティ名を `add` する（このリストは可変である）。

```groovy
entity.setValue(FLAG_PROP, expected)
if (updateProps != null && !updateProps.contains(FLAG_PROP)) {
    updateProps.add(FLAG_PROP)
}
```

判定の材料の取り方には順番がある。**§5.1 と同じ理由で、値を見る前に更新対象を見る。**

1. 更新対象に材料のプロパティが含まれていれば `entity` から取る。
2. 含まれていなければ `beforeUpdateEntity` から取る（`entity` 側は null に見える）。

材料が数式プロパティのときは、**その数式が読んでいる素のプロパティから引き直す**。数式
プロパティは保存前の `entity` に値が載らず、書き込みもできない。参照先の値を材料にするなら
参照プロパティのoidから参照先をロードし、参照先の宣言プロパティ（`Name` 等）を読む。
このロードは `AuthContext.doPrivileged` で行う。保存した利用者が参照先を読めないと、
材料が引けずに誤った値を書いてしまう。

## 6. 条件の移し方

SFのフィルタ条件をそのままEQLへ置き換えると当たらないことがある。

| SF側 | iPLAssでの扱い |
|---|---|
| 積み上げ集計項目（`type` が `Summary`）を使った条件 | iPLAssでは数式プロパティ（EQLサブクエリ）になる。**WHERE句に置かず、同じ条件を子Entity側から直接引く。**「件数 >= 1」は「条件を満たす子レコードが1件以上ある」と同義 |
| チェックボックスの `EqualTo false` | iPLAssのBOOLEANは**nullを取り得る**。移行後のデータがnullだと `= false` は1件も当たらない。`is null or = false` で書く |
| 選択リストの `EqualTo` | `CAST(<プロパティ> as STRING) = '<値>'` |
| 数式項目を使った条件 | 数式の中身を展開して素の項目の条件にする。展開できないものは申し送る |

**条件は必ず実機のデータで当たることを確かめる。** 条件を1つずつ足しながら件数を見れば、
どの条件で0件になるかが分かる。

## 7. 検証

手動起動用のWebApiを一時的に置いてCommandを叩く。呼び出しは
[scripts/iplass/mtp-api.sh](../../../scripts/iplass/README.md)。

| 見るもの | 確かめ方 |
|---|---|
| 本文が実行されている | レスポンスの版マーカーが投入した値と一致する |
| 引き当て | `targetCount` が実データから期待した件数と一致する |
| 前段の結果 | 対象レコードの日付項目が基準日になっている |
| 後段の結果 | 子レコードが1件でき、各項目が期待値になっている |
| 二重にならない | もう一度流して `updatedCount` が0・`skippedCount` が対象件数になり、子レコードが増えない |

**対象が0件のまま検証を終えない。** 0件では「正しく0件」と「動いていない」が区別できない。
実データで対象が0件なら、条件を満たすレコードを一時的に作るか既存を書き換える。その場合は
**元の値を記録してから触り、戻したことを取得して確認する。** 戻し忘れると本番のデータで
バッチが動き続ける。

検証のために公開したEntityWebApi・手動起動WebApi・運用操作の定義は、終わったら消す
（残す/消すの判断は [coordinating-migration-work](../coordinating-migration-work/SKILL.md)）。

### 7.1 Entity CRUD APIの制約

検証はEntity CRUD APIで行うが、Command内の `EntityManager` には無い制約がある。**Command側の
実装をこの制約に合わせて曲げない。**

| 症状 | 原因 |
|---|---|
| SELECT句に参照パス（`<参照プロパティ>.oid`）を置くとHTTP 500 | 参照先Entityが未公開。参照先もEntityWebApiを置けば通る。WHERE句では未公開でも通る |
| `count(...)` を使うとHTTP 500 | 集約関数は使えない。`select oid` と件数で数える |
| `update` が必須項目の `EntityValidationException` になる | **原因が更新対象のEntityとは限らない。** リスナが作る側のレコードの検証違反が同じ形で返る（§5.3） |
