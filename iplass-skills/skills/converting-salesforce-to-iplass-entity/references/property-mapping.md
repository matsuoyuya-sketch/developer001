# SF項目型・属性 → iPLAssプロパティ

Salesforceの項目型・項目属性を、iPLAssのEntityプロパティ／バリデーションへどう対応させるかのリファレンス（オブジェクト単位の属性がEntity定義のトップレベルに対応する場合も含む）。
型・多重度・索引可否そのものの一次情報は `iplass-dev:iplass-metadata` / `iplass-dev:iplass-entity` を、EQL文法は `iplass-dev:iplass-query` を参照する。このファイルは「SFの設定をiPLAssでどう表すか」の対応に集中する。

---

## 1. プロパティ共通JSON形状

全プロパティ共通: `@class`, `name`, `displayName`, `updatable`, `readOnly`, `multiplicity`,
`validations:[]`, `normalizers:[]`, `localizedDisplayNameList:[]`, `inherited:false` ＋ 型固有フィールド。

`multiplicity` は数値（単一は `1`、複数は上限の数値、無制限は `-1` でReference型のみ）。値の決め方と型ごとの可否は `SKILL.md` §11 が定義位置。

| 型 | 型固有フィールド |
|---|---|
| ReferenceProperty | `objectDefinitionName`, `referenceType:"ASSOCIATION"` |
| ExpressionProperty | `expression`, `resultType`（文字列）, `javaType`（§14） |
| SelectProperty | `selectValueDefinitionName`（参照）または `selectValueList`（インライン）, `localizedSelectValueList` |

---

## 2. 項目型

まず `<type>` の有無を判定する。**ある**＝カスタム項目→下表。**無い**＝標準項目→下の「標準項目の型推測」。
`@class` は `org.iplass.mtp.entity.definition.properties.` 配下。

| SF `<type>` | iPLAss `@class` / `type` | 実装メモ |
|---|---|---|
| Text | StringProperty / STRING | `<length>` → LengthValidation（§4） |
| TextArea（複数行） | StringProperty / STRING | 複数行入力は**View側**（§11） |
| LongTextArea | LongTextProperty / LONGTEXT | 大容量。検索は完全一致不可 |
| Html | LongTextProperty / LONGTEXT | リッチテキスト（HTML） |
| Email / Phone / Url | StringProperty / STRING + RegexValidation | 形式チェックの正規表現を必ず付与（§13） |
| EncryptedText | StringProperty / STRING | 暗号化型は無く値保持のみ |
| Picklist | SelectProperty / SELECT | §7参照 |
| MultiselectPicklist | SelectProperty / SELECT + **multiplicity 32** | §8参照（**`-1`不可**） |
| Checkbox | BooleanProperty / BOOLEAN | |
| Number `scale=0` | **DecimalProperty / DECIMAL（`scale=0`）** | **IntegerPropertyにはしない（必須ルール。§6）**。`scale:0`,`roundingMode:"HALF_UP"`,`javaType:"java.math.BigDecimal"`。小数入力拒否のRegexValidation（§6）を必ず付与し、桁数（precision）→RangeValidation（§5）を併用 |
| Number `scale>0` / Currency / Percent | DecimalProperty / DECIMAL | `scale`,`roundingMode:"HALF_UP"`。桁数（precision/scale）→RangeValidation（§5） |
| AutoNumber | AutoNumberProperty / AUTONUMBER | 採番書式は `formatScript`（例 `管理番号-${nextVal()}`）＋`fixedNumberOfDigits`/`startsWith`/`numberingType`。**NotNull（必須）を付けない**（自動採番で値が保証される。付けるとGEM/mdcの新規登録画面で「未採番＝空」が必須違反となり保存不可） |
| Date | DateProperty / DATE | |
| DateTime | DateTimeProperty / DATETIME | |
| Lookup / MasterDetail / MetadataRelationship | ReferenceProperty / REFERENCE | `objectDefinitionName=<referenceTo>`。`referenceType` は**LookupもMasterDetailも `ASSOCIATION`**。参照先が無ければStringにフォールバック。存在保証はExistsValidation（§12）。削除時の挙動・カスケード削除・親の付け替えは§19 |
| ExternalLookup / IndirectLookup | StringProperty / STRING | 外部/間接参照。ID・キーをStringで保持 |
| Hierarchy | ReferenceProperty（自己参照。`objectDefinitionName`=自Entity） | 多重度の型変更と同じく、作成後に別のupdateで追加する2段階になる |
| Summary（rollup。`count`/`sum`/`min`/`max`/`avg`） | ExpressionProperty / EXPRESSION（`updatable:false`） | 子レコードの集計は相関スカラーサブクエリで表す（§14） |
| File | BinaryProperty / BINARY | ファイル/添付。全Entity共通の添付ファイル項目は§18（項目の有無に依らず追加する） |
| Location | 2×DecimalProperty | `<name>__Latitude__s` / `<name>__Longitude__s` に分解 |
| Formula（`<formula>`） | ExpressionProperty / EXPRESSION | 型に関わらず優先。`expression`はiPLAssのValue Expression（EQL）文法。SF数式は非互換なのでEQLへ書き換える（§14）。戻り型は**`resultType`（文字列）＋`javaType`**（§14。`resultTypeSpec`は無効） |
| Address（Billing/Shipping等。複合標準） | 5×StringProperty | `Billing/Shipping`×`Street,City,State,PostalCode,Country`に分解 |

**注意:** LongTextProperty/AutoNumberProperty/BinaryPropertyは、登録後に `getDefinition` で `@class`/`type` の受理を照合し、不可なら近い型（String/Decimal等）へフォールバックする。

**標準項目の型推測（`<type>` が無い場合）**: 項目名と既知のSF標準スキーマから推測する。
- Phone/Fax → StringProperty＋Phone用RegexValidation、Website → StringProperty＋URL用RegexValidation、Email系 → StringProperty＋Email用RegexValidation（§13）。Sic等の一般文字列 → StringProperty
- 金額系（AnnualRevenue等）→ DecimalProperty／件数系（NumberOfEmployees等）→ 整数扱い（§6のDecimal(scale0)+RegexValidation）
- フラグ系（Is/Hasで始まる）→ BooleanProperty／日付系（`...Date`で終わる）→ Date/DateTimeProperty
- 参照系（OwnerId/CreatedById等）→ ReferenceProperty（OwnerIdの実体は標準ユーザーEntity `mtp.auth.User`）、参照先が無ければString
- 複合（BillingAddress/ShippingAddress等）→ 上記Address分解
- 判別不能はStringPropertyにフォールバックし、推測した旨を報告する

---

## 3. 必須

SF `<required>true` → NotNullValidation。プロパティ直下に `required` のようなフラグは**無い**。`validations` に追加する:

```json
{"@class":"org.iplass.mtp.entity.definition.validations.NotNullValidation",
 "messageCategory":"mtp/validation","messageId":"NotNull","localizedErrorMessageList":[]}
```

NotNull は null・空文字・サイズ0配列でエラーになる。SF標準の必須／MasterDetailは実質必須として扱う。

---

## 4. 文字数

SF `<length>` → LengthValidation。`validations` に追加する。

- `max` = SF `<length>`。**`min` は指定しない**（キーごと入れない）。
- メッセージは `messageCategory:"mtp/validation"` ＋ **`messageId:"LengthMax"`**（`Length` ではなく `LengthMax`。最大長超過用の標準メッセージ）。個別文言が要るときのみ `errorMessage`＋`localizedErrorMessageList` を併用する。
- `checkBytes:false`（文字数判定）、`surrogatePairAsOneChar:true`（サロゲートペアを1文字と数える）。

```json
{"@class":"org.iplass.mtp.entity.definition.validations.LengthValidation",
 "messageCategory":"mtp/validation","messageId":"LengthMax","localizedErrorMessageList":[],
 "max":50,"checkBytes":false,"surrogatePairAsOneChar":true}
```

**対象**: `<length>` を持つSF項目（Text/TextArea）→StringProperty。LongTextArea（例32000）もLengthValidationを持つ場合は同形式で整形する。数式・参照・実行コンテキスト参照・空Picklistフォールバックで生まれた項目はSFに `<length>` が無いので**付けない**。

**既存validationの保全**: NotNull/Regex/Scripting等の他バリデーションは残したまま、**LengthValidationだけを差し替える**（配列から `@class` が `LengthValidation` のものを除去→新形式を追加）。

**標準項目の文字数は別途提供が必要**: SF標準項目（`<type>` が無い項目。例: 独自Name項目のもとになる `Name`、`BillingStreet`/`ShippingCity` 等の住所要素、`Phone`、`Fax`、`Website`、`Sic`、`SicDesc`、`Site`、`TickerSymbol`、`Jigsaw`、`SourceSystemIdentifier`、番号系の標準項目 等）は、項目メタデータに `<length>` が存在しない。桁数はSFスキーマ由来の**桁数表を別途提供してもらい**、そこから `max` を設定する。提供が無い標準項目は `max` を勝手に推測せず、未設定として報告する。

---

## 5. 数値の桁数

SFの数値項目（Number/Currency/Percent）は `precision`（全体桁数）と `scale`（小数桁）を持つ。桁数超過の入力拒否をiPLAssにも反映するため、**RangeValidation（値範囲の閉区間）** を付与する。桁数上限を「±(全部9)」の範囲に落とすと整数桁の超過を弾ける（小数桁はDecimalPropertyの `scale`＋`roundingMode:"HALF_UP"` の丸めで吸収するので、両者の組合せでSFの `precision` 制約と等価になる）。

- 整数部桁数 = `precision − scale`。`max` = 整数部に `9` を(precision−scale)個 ＋（`scale>0` なら `.` と `9` を scale 個）。`min` = `"-" + max`（SF Numberは既定で負値可）。**文字列で組む**（浮動小数誤差回避）。整数部0桁（`precision === scale`）は整数部を `"0"`（例 4/4→`0.9999`）。
- `min`/`max` は**文字列**。閉区間: `maxValueExcluded:false`, `minValueExcluded:false`。
- メッセージは `messageCategory:"mtp/validation"` ＋ **`messageId:"Num"`** ＋ `localizedErrorMessageList:[]`（LengthValidationの `LengthMax` と同流儀。独自文言は付けない）。

```json
{"@class":"org.iplass.mtp.entity.definition.validations.RangeValidation",
 "messageCategory":"mtp/validation","messageId":"Num","localizedErrorMessageList":[],
 "min":"-99999999999999.9999","max":"99999999999999.9999",
 "maxValueExcluded":false,"minValueExcluded":false}
```

**対象**: `precision` を持つNumber/Currency/Percentの**入力**プロパティ（Integer/Decimal）。**数式（Expression）・Summary（rollup）・precision無しの標準項目には付けない**（読取専用/桁数情報なし）。既存validationは保全しRangeValidationだけ差し替える（配列から`RangeValidation`を除去→追加。冪等）。

precision/scale → min〜max の対応例:

| precision/scale | min | max |
|---|---|---|
| 18/4 | `-99999999999999.9999` | `99999999999999.9999` |
| 18/0 | `-999999999999999999` | `999999999999999999` |
| 18/1 | `-99999999999999999.9` | `99999999999999999.9` |
| 11/0 | `-99999999999` | `99999999999` |
| 6/1 | `-99999.9` | `99999.9` |
| 4/1 | `-999.9` | `999.9` |

---

## 6. 整数項目の小数入力拒否（小数点以下が0でもエラー）

「整数型項目に小数が入力されたらエラーにする（`5.5` はもちろん `5.0` も拒否）」要件は、**IntegerPropertyのままでは実現できない**。理由: iPLAssのEntityバリデータ（NotNull/Range/Regex/Scripting）は**型変換後の値**に対して走り、IntegerProperty（=`java.lang.Long`）では検証時点で既に小数部が失われている（`5.0`と`5`は区別不能）。Validatorを足しても検知できない。

**対応（基本方針）**: 対象項目を **`DecimalProperty`（`scale:0`）** にした上で **`RegexValidation`** を付与する。DecimalProperty（=`java.math.BigDecimal`）なら検証時の値に小数が残るため、`toString()` が整数パターンに不一致となって `5.5`/`5.0` を弾ける（`scale`/`roundingMode` の丸めは**保存時**に適用され、検証より後の順序になる）。

- プロパティ: `@class`=DecimalProperty / `type:"DECIMAL"` / `javaType:"java.math.BigDecimal"` / **`scale:0`** / `roundingMode:"HALF_UP"`。
- バリデーション（`validations` に追加）:

```json
{"@class":"org.iplass.mtp.entity.definition.validations.RegexValidation",
 "messageCategory":"mtp/validation","messageId":"Integer","localizedErrorMessageList":[],
 "pattern":"^-?\\d+$"}
```

- **`messageId:"Integer"`**（`mtp/validation` の標準メッセージ。`errorMessage` は付けない）。`pattern` の `\d` はJSON内で `\\d` にエスケープする（実データは `^-?\d+$`）。
- 桁数上限も要るなら §5 の**RangeValidationと併用**する（配列にRangeとRegexの2件）。既存validationは保全し、RegexValidationだけ除去→追加で冪等に扱う。
- **対象外**: Expression（読取専用・算出値）、Summary（rollup）。数式（Number）はExpressionPropertyのまま。

**§2との関係（必須ルール）**: SF `Number scale=0` は必ず本方式（Decimal(scale0)+RegexValidation）で移行し、IntegerPropertyにはしない。整数保持と小数入力拒否を常に両立させる。

---

## 7. 選択肢

**選択肢は原則すべて共通選択値定義（SelectValueDefinition。以下SVD）にする。** SF側がグローバル値セット参照でもローカル値セット（項目XMLへの直書き）でも扱いは変えず、SelectPropertyへのインライン `selectValueList` は使わない。値セットを複数項目・複数Entityで共有でき、定義サイズも小さく保てる。

- パス: `/property/select/<名前>`、`@class`: `org.iplass.mtp.entity.definition.properties.selectvalue.SelectValueDefinition`
- **SVD名**: グローバル値セット参照ならその値セット名をそのまま使う（SF側の名前を踏襲）。ローカル値セットなら `<Entity短縮名>_<項目名>`（項目名からカスタム接尾辞 `__c` を除いたもの）。
- 同名のSVDが既にあれば**再利用**し、新規作成しない。

```json
{"@class":"org.iplass.mtp.entity.definition.properties.selectvalue.SelectValueDefinition",
 "name":"<値セット名>",
 "selectValueList":[{"value":"<値>","displayName":"<表示名>"}],
 "localizedSelectValueList":[{"localeName":"ja"},{"localeName":"en"},{"localeName":"zh-CN"},{"localeName":"zh-TW"},{"localeName":"th"}]}
```

SelectPropertyからは **`selectValueDefinitionName`** で参照し、**インライン `selectValueList` は省略**する（送信時に空/未指定でよい。サーバが取得時に解決して埋める）:

```json
{"@class":"org.iplass.mtp.entity.definition.properties.SelectProperty","name":"<Picklist項目>__c",
 "type":"SELECT","javaType":"org.iplass.mtp.entity.SelectValue","multiplicity":1,
 "selectValueDefinitionName":"<値セット名>"}
```

- **注意（インライン優先による意図しない上書き）:** インライン `selectValueList` と参照（`selectValueDefinitionName`）を両方指定すると**インラインが優先され参照がクリア**される。参照だけを入れること。
- **注意（サイズ対策）:** 数百値の選択肢を多数インラインで持つと定義が増大し送信上限を超える。SVD参照にすればEntity定義を大幅に小さく保てる。

**選択肢の解決（SFメタデータから）**:

- `<valueSet><valueSetName>X` → `globalValueSets/X.globalValueSet-meta.xml` の `<customValue>`（value=`fullName`,label=`label`）を順序保持で抽出、`<isActive>false</isActive>` は除外
- `<valueSetDefinition>` インライン → 同様に `isActive` で除外
- 標準SFのPicklist（Type/Industry/Rating等）は値の出所がリポジトリに無い→値0件。**空SELECTは避け**、当面StringPropertyにするか、値が判明してからSVD化する（空のまま登録しない）

**値には`fullName`を使い、`label`を値にしない。** SFのグローバル値セットは`fullName`と`label`が違うことがあり、ラベルを値にすると**同じ値セットを共有する他のオブジェクト由来のEntityと値集合が食い違う**。食い違うと、片方のEntityから他方へ選択値を渡す処理（レコードの複製・関連レコードの作成）で、**一致しない値が黙って落ちる**（例外もログも出ない）。移行後に気づいたときは、値集合を揃えるまで保留として扱う（渡す側の処理は落とさずに通す）。値を渡す側の作法は [converting-salesforce-screens-to-iplass](../../converting-salesforce-screens-to-iplass/SKILL.md) §5 が定義位置。

---

## 8. 複数選択

- iPLAssの多重度: **無制限（AdminConsoleの `*`。JSONでは `-1`）を使えるのはReference型だけで、SELECTは有限数にする**（`SKILL.md` §11 が定義位置）。
- 多値SELECTの多重度は **32** にする。SFのMultiselectPicklistのメタデータには選択可能数の指定が無いため、指定が無ければ32を既定値として使う（選択肢数とは無関係に固定）。`selectValueDefinitionName` 併用可。

```json
{"@class":"org.iplass.mtp.entity.definition.properties.SelectProperty","name":"<多値Picklist項目>__c","type":"SELECT","multiplicity":32,
 "javaType":"org.iplass.mtp.entity.SelectValue","selectValueDefinitionName":"<値セット名>"}
```

**注意（SELECT型に `-1` を使用しない）:** SELECT型に無制限多重度（`-1`）を指定すると、画面（詳細View）を開く/保存する際に `PSQLException: syntax error at or near ","` になり、ログに `ViewInitializeCommand` と `MetaGRdbMultiplePropertyStore.getStore() is null` が出る。原因は多値の物理ストアが確保されず、生成SQLのカラム参照が空になること。対処はSELECTの多重度を**有限数**にすること（上記）。`{"status":"SUCCESS"}` が返っても、この不整合は画面表示で初めて顕在化するので注意する。無制限が必要なら別Entity＋Referenceを検討する。

---

## 9. 一意

**(A) 一意インデックス（DBレベル・確実）**: プロパティ直下に `indexType`:

```json
"indexType":"UNIQUE"           // null含めて重複不可
"indexType":"UNIQUE_WITHOUT_NULL"  // nullは許可
```

- 値: `NON_INDEXED` / `NON_UNIQUE` / `UNIQUE` / `UNIQUE_WITHOUT_NULL`
- **注意（付与不可の型）:** 多重度≠1、Expression/Binary/LongText/Reference。
- **注意:** 既存データに重複があると登録/保存でエラーになる。既存データ・索引の後付けの前は**移行データに重複が無いことを事前に確認する**（§16も同じ確認が必要）。

**(B) ScriptingValidation（アプリレベル・DDL不要・任意メッセージ）**:

- `validations` に追加する。バインド変数は `value`（対象値）・`entity`（getterでアクセス）。Manager取得は `ManagerLocator.instance.getManager(XxxManager.class)`。戻り値 `boolean`（`false`=エラー）。

一意チェックの雛形:

```groovy
import org.iplass.mtp.*;
import org.iplass.mtp.entity.*;
import org.iplass.mtp.entity.query.*;
import org.iplass.mtp.entity.query.condition.expr.*;
import org.iplass.mtp.entity.query.condition.predicate.*;
if (value == null) { return true; }
def em = ManagerLocator.instance.getManager(EntityManager.class);
def selfOid = entity.getOid();
def cond;
if (selfOid == null) {
    cond = new Equals("<PROP>", value);
} else {
    cond = new And(new Equals("<PROP>", value), new NotEquals("oid", selfOid));
}
def q = new Query().select("oid").from("<ENTITY>").where(cond);
return em.count(q) == 0;
```

```json
{"@class":"org.iplass.mtp.entity.definition.validations.ScriptingValidation",
 "errorMessage":"この値は既に使用されています。","localizedErrorMessageList":[{"@class":"org.iplass.mtp.definition.LocalizedStringDefinition","localeName":"ja","stringValue":"この値は既に使用されています。"}],
 "script":"<上記Groovy>","asArray":false}
```

**注意:** アプリ層のため同時実行時の競合窓は残る（完全な保証はindex側のみ）。データ登録テストで実際の挙動を確認する。

**(C) 大文字小文字の扱い（SF `<caseSensitive>`）**: この要素は単独の属性ではなく**一意（`<unique>`／`<externalId>`）の修飾**として現れる。基本は値に依らず **(A)の `indexType` だけ**を付ける。

| SF | 扱い |
|---|---|
| `true` | (A)のみ。DBの照合順序どおり大小を区別するのでSFと同じ判定になる |
| `false` | 基本は(A)のみ。**大小違いが別の値として通るためSFより緩くなる**ので、該当項目を挙げてユーザーに確認する |

`false` で(A)では不十分と判断した項目だけ、**(A)を外して(B)へ置き換える**（(A)と(B)は併用しない）。(B)の一意チェックの条件を `UPPER()` 比較にする（EQLの `UPPER` を使う。関数の一次情報は `iplass-dev:iplass-query`）:

```groovy
import org.iplass.mtp.entity.query.value.primary.*;   // Function / EntityField / Literal
def cond = new Equals(new Function("UPPER", new EntityField("<PROP>")),
                      new Function("UPPER", new Literal(value)));
if (selfOid != null) { cond = new And(cond, new NotEquals("oid", selfOid)); }
return em.count(new Query().select("oid").from("<ENTITY>").where(cond)) == 0;
```

(A)を外すとDBレベルの保証が無くなる（(B)はアプリ層のみ）。**一意をやめても索引だけは残せる**ので、検索条件に使う項目は `indexType:"NON_UNIQUE"` にする（索引ごと捨てない）。

**変換器は `<caseSensitive>` を読まない**。`<unique>` から(A)を付けるところまでしかしないので、`false` の項目の洗い出しと(B)への差し替えは手で行う。

**一意制約を持つプロパティは、レコードを丸ごと複製する処理では写さない**（値が入った元レコードで重複エラーになる）。除外規則は [converting-salesforce-screens-to-iplass](../../converting-salesforce-screens-to-iplass/SKILL.md) §7.4 が定義位置。

---

## 10. デフォルト値

- **初期値はEntity定義では設定しない**（AdminConsoleのプロパティ設定に初期値の項目が無い）。
- 実装は **View(EntityView)のPropertyEditor** の初期値、または **EventListener/アプリコード** で行う。Entity変換のスコープ外として扱い、View/リスナ側の課題に回す。

---

## 11. 複数行エディタ・表示

プロパティ型（String/LongText）はEntity定義だが、**複数行入力（TextArea表示）や桁数表示などのエディタ設定はView(EntityView)のPropertyEditor** で行う。Entity定義だけでは入力欄の見た目は変わらない。
複数行入力をSFの型から決める規則は `converting-salesforce-layout-to-iplass-view` §3 が定義位置。

---

## 12. 参照存在チェック

Lookup相当で「参照先が実在すること」を保証したい場合、`validations` に `ExistsValidation`（`org.iplass.mtp.entity.definition.validations.ExistsValidation`）を付与できる（Referenceの参照データ存在チェック）。

---

## 13. 形式バリデーション（Email / Phone / URL）

SFのEmail/Phone/Url型（および標準項目Phone/Fax=電話、Website=URL、`*Email*`=メール）はStringPropertyにしたうえで、`validations` に **RegexValidation** を付与して形式を検証する。設定キーは **`pattern`**。エラーメッセージは `errorMessage` ＋ `localizedErrorMessageList` で持つ（NotNull/Lengthのような `messageCategory`/`messageId` ではない）。

**注意（空値の許容）:** `pattern` の**先頭に `|`（空文字との論理和）を付けて未入力を許容**する（必須はNotNullValidationで別途担保）。`|` を付けないと空欄保存でエラーになる。

```json
{"@class":"org.iplass.mtp.entity.definition.validations.RegexValidation",
 "errorMessage":"メールアドレスをご確認ください。",
 "localizedErrorMessageList":[{"@class":"org.iplass.mtp.definition.LocalizedStringDefinition","localeName":"ja","stringValue":"メールアドレスをご確認ください。"}],
 "pattern":"|^...$"}
```

推奨パターン（`pattern` にそのまま入れる。JSON内は `\` を `\\` にエスケープ）:

| 用途 | pattern（表内では `\|` と表記。実データは `|`） | 備考 |
|---|---|---|
| Email | `mtp.auth.User.mail` の正規表現をそのまま流用 | RFC準拠。先頭が空許容の `\|`。手書きせず既存定義から採取するのが安全 |
| Phone/Fax | `\|^[-+0-9() 　]+$` | 数字・ハイフン・+・括弧・半/全角スペース。SFは「ハイフン込み」入力を想定 |
| URL | `\|^(https?://)?([^ 　.]+[.])+[^ 　.]+.*$` | **`http://` を許容する**。スキーム部 `https?` の `?` が `http://` と `https://` の両方を通し、外側の `(...)?` がスキーム自体の省略を許す。ドット区切りホスト、空許容 |

Phone/URLは緩め（実在の多様な表記を弾かない）にしている。

---

## 14. 数式（Formula）とSummary（rollup）

**評価時点で値が変わる関数を含む数式はExpression化しない。** 本日日付・現在時刻を返す関数（`TODAY` / `NOW` 相当）がその代表で、実行コンテキスト参照（`$User` 等）と同じ扱いにする。Expressionは検索時に評価されるため、この経路で本日日付を組む書き方が要るが、**`CURRENT_DATE` / `TODAY()` / `SYSDATE` はいずれもこの環境のクエリで通らない**（症状の確かめ方は [../../iplass-entity-crud-api/SKILL.md](../../iplass-entity-crud-api/SKILL.md) §8）。

移行先では**値を保持する形にして保留に起こし、日付に依存する判定は使う側（画面のCommand・イベントリスナ）で都度計算する**。移行時点のスナップショット値をそのまま判定に使うと、日が変わった時点で結果がずれる。EQLの関数の可否そのものは `iplass-dev:iplass-query` が定義位置。

SFの数式項目は `ExpressionProperty`（`type:"EXPRESSION"`）にし、`expression` に **iPLAssのValue Expression（EQL）** を設定する。EQL文法は `iplass-dev:iplass-query` を参照する。SFのSummary項目（子レコードの集計）も同じ `ExpressionProperty` で表す（本節末尾）。

**戻り型の指定（重要）**: ExpressionPropertyの戻り型は **`resultType`（文字列）＋`javaType`（具象型）** で指定する。オブジェクトの **`resultTypeSpec`（`{@class,type,multiplicity}`）は無効フィールドで無視される**（`resultTypeSpec` を指定して `updateDefinition` しても、AdminConsoleのResult Typeが空欄のまま／`getDefinition` にも出ない）。`getDefinition` は `resultType` を**正しく応答に返す**。

| resultType | javaType |
|---|---|
| `STRING` | `java.lang.String` |
| `INTEGER` | `java.lang.Long` |
| `DECIMAL` | `java.math.BigDecimal` |
| `BOOLEAN` | `java.lang.Boolean` |
| `DATE` | `java.sql.Date` |
| `DATETIME` | `java.sql.Timestamp` |

`DATE`/`DATETIME` を使う場合は、登録後に `getDefinition` で受理を照合する。

例: `{"@class":"org.iplass.mtp.entity.definition.properties.ExpressionProperty","type":"EXPRESSION","expression":"...","resultType":"STRING","javaType":"java.lang.String"}`。

**注意（`readOnly` は保持されない）:** `ExpressionProperty` は `readOnly:true` を送っても `getDefinition` が `false` を返す。算出値であることは **`updatable:false` だけで表す**（`readOnly` の値で読み取り専用かを判定しない）。

**注意（getから再構築するとresultTypeが脱落する）:** `getDefinition` の応答から全置換用payloadを作り直す経路（他項目の追加・修正のため定義全体を再送する場合）では、Expressionの `resultType`/`javaType` を再構築後に明示的に再付与する必要がある。検証は `updateDefinition` の `SUCCESS` だけでは不十分で、get再取得で `declaredPropertyList` 件数照合＋Expression各件の `resultType` を照合する。

**注意（変換の可否・移行順序ルール）:** 数式が**未移行のEntityを参照**（`__r`参照）、または `$User` 等の実行コンテキストを参照する場合は**まだ変換しない**（Stringのまま値保持）。参照先Entityが移行済みになってからExpression化する。未変換で保留する項目は保留台帳に記録する。

**他Entity参照（`__r`）はEQLのパス式にする**: SFの `<関係名>__r.<項目>__c` は、iPLAssでは**参照プロパティ名を起点にしたパス式** `<参照プロパティ>.<項目>` になる（`__r` という表記はiPLAss側に無い）。参照プロパティ名はSFのLookup項目のAPI名を踏襲しているので、`<関係名>__r` → `<関係名>__c` と読み替えればよい。

`__r` 由来の保留が解除できる状態かどうかは、**理由の字面ではなく参照先Entityの実在で判定する**（検出ツールが `<関係名>__c` の `<referenceTo>` からEntity名を引いて確かめる）。ただし**多段参照の2段目以降は自Entityの項目から辿れないため判定不能**で、検出ツールは「待ち」に残す。この場合は参照先Entityの定義を見て手で確認する。

**SF関数 → EQL 対応**:

| SF数式 | EQL | 備考 |
|---|---|---|
| `IF(c, a, b)` | `CASE WHEN c THEN a ELSE b END` | 入れ子IFはWHENを連ねる |
| `CASE(x, v1,r1, v2,r2, else)` | `CASE WHEN x=v1 THEN r1 WHEN x=v2 THEN r2 ELSE else END` | |
| `AND(x,y)` / `OR(x,y)` / `NOT(x)` | `x AND y` / `x OR y` / `NOT x` | 条件式内で |
| `ISPICKVAL(f,'v')` | `CAST(f AS STRING) = 'v'` | SELECT値の比較。`'v's`（SelectValueリテラル）でも可 |
| `TEXT(x)` | `CAST(x AS STRING)` | 型変換。data type: BOOLEAN/STRING/INTEGER/FLOAT/DECIMAL/DATE/DATETIME/TIME/SELECT |
| `ISNULL(x)` / `ISBLANK(x)` | `x IS NULL` | |
| `a & b`（文字列連結） | `CONCAT(a, b)` | `+` は算術。連結はCONCAT |
| `a + b`, `a * b` 等 | `a + b`, `a * b` | 算術はそのまま |
| 真偽リテラル | `TRUE` / `FALSE` | |
| 文字列リテラル | `'...'`（シングルクォート） | EQL出力側の話。SF入力側のパースとは別 |

**注意（大規模CASEは全分岐を漏れなく変換する）:** Picklist値→コード等の大きな `CASE(x, v1,r1, …)` は、**SFの全選択肢を漏れなく** `WHEN` に展開する。数件だけのサンプルで済ませない。対策として `field-meta.xml` の `<formula>` をパースして全分岐を機械生成し、**生成した `WHEN` 数がSF選択肢数と一致するか照合**する（手書きしない）。SFの数式内文字列リテラルは項目により `'`（`&apos;`）と `"`（`&quot;`）の**両方**が使われる（例: 同じEntity内でも、ある項目の数式は `'` を使い、別の項目の数式は `"` を使う）ため、パース時は両クォートに対応する（片方だけだとその項目の分岐を取りこぼす）。

**注意（BOOLEAN値の扱い）:** Value Expressionは単独の条件式（`a = b`）を値にできない。BOOLEAN結果は `CASE WHEN cond THEN TRUE ELSE FALSE END` で包む。

**注意（HYPERLINK）:** EQLに相当なし（UIリンク生成）。Expression化せず、リンク表現は**View側**で行う（保留）。

**注意（Percent項目の`/100`）:** SFは**Percent型を数式内で`/100`する**（20%→formula値0.2）。iPLAssのDecimalに`/100`は無く、値は生のまま。したがって**SF数式中のPercent項目参照は `P/100` に**、`P * 100`（SFの`/100`打ち消し）は**`P`（そのまま）**に変換する。例: SF `TEXT(<Percent項目>__c * 100) & '%'` → iPLAss `CONCAT(CAST(<Percent項目>__c AS STRING), '%')`。これで値も桁数（項目のscale）もSFと一致する。

**注意（小数スケールの増大）:** DECIMAL同士の乗算（`* 100`等）は結果scaleが増え `CAST … AS STRING` で末尾ゼロが大量に付く。不要な乗算をしない/`ROUND(x, scale)` で桁を項目のscaleに合わせる。整形のみならView側でも可。

**注意（SELECT比較）:** `CAST(selectProp AS STRING)` はSelectValueの`value`を返す（`value`と`displayName`を同値で定義している場合は表示文字列と一致）。

**空欄の扱い（SF `<formulaTreatBlanksAs>`）**: SF数式は参照項目が空欄（null）のとき `BlankAsZero`=0（数値）/空文字（テキスト）、`BlankAsBlank`=空欄（null）のまま扱う（SF既定は`BlankAsZero`）。iPLAssのValue Expressionには **`NVL`/`COALESCE`/`IFNULL` 等のnull置換関数が無く**、かつ算術演算でのnull伝播はエンジンの既定挙動に頼れない。したがって**式に明示的にnull処理を書く**。null置換は `CASE WHEN x IS NULL THEN <0/''> ELSE x END` が唯一の手段。

- **BlankAsZero**（算術）: 各被演算子をnull→0で包む。例 `(CASE WHEN A IS NULL THEN 0 ELSE A END) + (CASE WHEN B IS NULL THEN 0 ELSE B END) + …`。テキスト連結（`CONCAT`）なら `THEN ''`。
- **BlankAsBlank**: どれか一つでもnullなら結果null。例 `CASE WHEN A IS NULL OR B IS NULL … THEN NULL ELSE (A + B + …) END`。
- **0変換は必要な場合に限って行う**。null→0（または→`''`）の包みは、null が伝播して結果が壊れる**算術演算に絡む数値項目参照だけ**に適用する。比較・CASE（`ISPICKVAL`/`>` 等）はnullが自動で不成立→ELSEに落ちてSFと同じ結果になるため**包まない**（無用な包みで式を肥大させない）。**四則演算する項目はmultiplicity=1であること**（多重度≠1では正確に計算されない）。

**Expressionの最終戻り値は空文字列 `''` ではなくNULLを返す**: ExpressionProperty全体の出力として「値なし／未該当」を表すときは、空文字列ではなく**`NULL`を返す**（`THEN NULL`/`ELSE NULL`）。空文字とNULLは意味が異なり、未入力・未該当はNULLが適切（後続の `IS NULL` 判定・未設定扱い・表示が正しく効く）。EQLでNULLリテラルは有効。該当パターン: ①ガード節 `CASE WHEN <参照> IS NULL THEN NULL ELSE <本体> END`（参照項目が空欄なら結果もNULLにする形）。②大規模CASEでどの `WHEN` にも該当しない `ELSE` は `ELSE NULL`（Picklist値→コードの変換等で、全分岐に当たらない場合の既定値）。上の「BlankAsZeroのテキスト連結で`THEN ''`」とは別物（あちらは`CONCAT`の被演算子をnull→`''`で包む内部処理。ここで言うのは式全体の戻り値であり、「値なし」は`''`ではなくNULL）。

**Summary（rollup）**: SFのSummary項目も `ExpressionProperty`（`updatable:false`）で表す。iPLAssに集計値を保持する仕組みは無いが、Expressionの式には**相関スカラーサブクエリ**が書けるため、集計そのものを式で表現できる（集計関数は `SUM` / `COUNT` / `AVG` / `MIN` / `MAX`）。式の形は次のとおりで、**外側（自Entity）の項目参照には先頭に `.` を付ける**。

```text
(SELECT <集計関数>(<集計元項目>) FROM <子Entity名> WHERE <絞り込み条件> ON .oid = <子の親参照項目>.oid)
```

- 行数を数えるときは `COUNT()`（`COUNT(*)` ではない）。
- SFメタデータとの対応: `<summaryForeignKey>`（`<子オブジェクト>.<親参照項目>` の形）→ 子Entity名と結合キー / `<summarizedField>` → 集計元項目（`count` では持たない） / `<summaryOperation>` → 集計関数 / `<summaryFilterItems>` → サブクエリの `WHERE`。
- `resultType`: `count` は `INTEGER`。`sum`/`avg`/`min`/`max` は集計元項目の型に合わせる（小数なし数値 `INTEGER` / 小数あり `DECIMAL` / 日付 `DATE`・`DATETIME`）。
- **保留の条件**（未移行参照の数式と同じ扱い）: 子Entityが未移行のとき、または `<summaryFilterItems>` が機械変換できないとき（多値Picklistの複数値・数式項目を参照する等）は変換せずStringで値保持し、保留台帳に記録する。
- SFは集計値を保持して非同期に更新するが、iPLAssは参照時に算出する。集計元の変更が即座に反映される点が異なる。
- 変換器はSummary項目をreadOnlyの数値/日付プロパティとして出力する（Expression化には追随していない）。**生成物を使うときは、Summary項目を上記の形へ手当てする**。

### 14.1 Expressionが評価できるかを確かめる

**登録できることは評価できることを意味しない。** 式が評価できないExpressionが1件でもあると**レコードの取得そのものが失敗し、詳細画面が開かなくなる**。定義の取得・照合では露出しないので、投入後に別途確かめる。

確かめ方は Entity CRUD API で**プロパティ名を指定して取得する**（`iplass-entity-crud-api`）。

```text
select oid, <Expressionのプロパティ名> from <Entity定義名>
```

| 事実 | 理由 |
|---|---|
| `oid` を必ず添える | select の項目が1つだけだと失敗する |
| **式そのものを select に書く方法は使えない** | 参照のパス式（`<参照>.<項目>`）とReferenceプロパティは select に直接書けない。Expressionプロパティとして評価させれば通る |

失敗したExpressionは**Stringで値保持へ戻して保留に回す**（画面が開かない状態より、値が空欄のほうが良い）。戻すときは式を手元に退避する。EXPRESSION→STRING は in-place で通る（`iplass-definition-io` §10）。

評価できない式の形は、条件の位置に入れ子の `CASE` を置いたもの・`CAST` の中に `CASE` を置いたもの・多段のパス式を含む複合条件で現れる。**変換器の出力もこの形になり得る**ので、投入した分は全件この方法で確かめる。

---

## 15. 標準Name項目

**方針**: SFの標準 `Name` 項目は、iPLAss標準の共通プロパティ `name`（lowercase）を再宣言（displayName上書き）するのではなく、**各Entityで独自プロパティ `Name` を作成し、それをEntityの `name` として指定する**（独自項目であることが画面・定義上明確になる）。

**Name情報の取得元（標準／カスタムで場所が違う。どちらも変換器が独自Name＋`namePropertyName`を生成する）**:

| オブジェクト種別 | Name情報の場所 | 桁数 |
|---|---|---|
| 標準オブジェクト | `fields/Name.field-meta.xml`（通常の項目メタデータとして存在） | 項目の `<length>`。無ければ§4の「標準項目の文字数」に従う |
| カスタムオブジェクト（`__c`） | `<Obj>.object-meta.xml` の `<nameField>` ブロック（`<label>`＝表示名 / `<type>`＝`Text` か `AutoNumber` / `<displayFormat>`＝採番書式。`fields/` 配下には出ない） | Textは **80**（SFのカスタムNameは80桁固定。メタデータに桁数は出ない） |

**採番書式の対応**: `<type>` が `AutoNumber` のときは `<displayFormat>` を採番設定へ移す。`<接頭辞>{0…0}<接尾辞>` の形は `formatScript`（`0…0` の位置を `${nextVal()}` に置換）＋`fixedNumberOfDigits`（`0` の個数）になる。日付トークン等が混ざる形式は機械変換せず、レポートに出して個別に決める（推測で書かない）。

**仕組み（iPLAssの「共通Propertyの変更」機能）**: iPLAssは全Entityに共通プロパティ `oid`/`name` を持つが、`EntityDefinition` トップレベルの以下で**別プロパティをoid/nameとして指定**できる。

| フィールド | 型 | 意味 |
|---|---|---|
| `namePropertyName` | `String`（1つのみ・複合不可） | Entityの `name` として使うプロパティ名 |
| `oidPropertyName` | `List<String>`（複合可＝上から`-`連結） | Entityの `oid` として使うプロパティ名 |

- **name指定できるプロパティの条件**: 型が 基本型/AutoNumber/Select、**必須**、**多重度1**（oidは 基本型/AutoNumber、必須、多重度1）。
  - **注意（AutoNumberをname指定する場合）:** SFのNameがAutoNumber（自動採番）のときは、独自 `Name` を**AutoNumberPropertyで作成しNotNullは付けない**。自動採番が実質的に「必須」条件を満たすためNotNull不要で、むしろ**NotNullを付けるとGEM/mdcの新規登録画面で「未採番＝空」が必須違反となり保存できない**。この場合§4のLengthValidationも不要。
- **保存時の挙動**: `namePropertyName` を指定すると、データ保存時に指定プロパティの値が**標準`name`にコピー**される（標準`name`は消えない）。

**手順**:

1. 独自プロパティ `Name` を追加（StringProperty・必須NotNull・多重度1、`<length>` があればLengthValidation、表示名はSFのName項目ラベル）。
2. トップレベルに `"namePropertyName":"Name"` を設定。
3. 標準 `name` は**再宣言しない**（`propertyList` に入れない）。標準既定（`inherited:true`）のままにする。
4. `updateDefinition`（全置換）→ `getDefinition` で `namePropertyName` が独自Name名／標準`name`が`inherited:true`／独自`Name`が`declared`に存在、を照合する。

```json
{ "@class":"org.iplass.mtp.entity.definition.EntityDefinition", "name":"<Entity名>",
  "namePropertyName":"Name",
  "propertyList":[
    {"@class":"org.iplass.mtp.entity.definition.properties.StringProperty","name":"Name","displayName":"<Name項目ラベル>","type":"STRING","multiplicity":1,
     "validations":[
       {"@class":"org.iplass.mtp.entity.definition.validations.NotNullValidation","messageCategory":"mtp/validation","messageId":"NotNull","localizedErrorMessageList":[]},
       {"@class":"org.iplass.mtp.entity.definition.validations.LengthValidation","messageCategory":"mtp/validation","messageId":"LengthMax","localizedErrorMessageList":[],"max":255,"checkBytes":false,"surrogatePairAsOneChar":true}],
     "localizedDisplayNameList":[
       {"@class":"org.iplass.mtp.definition.LocalizedStringDefinition","localeName":"ja","stringValue":"<ラベル>"},
       {"@class":"org.iplass.mtp.definition.LocalizedStringDefinition","localeName":"en","stringValue":"Name"}]}
  ]}
```

（標準`name`は`propertyList`に**入れない**＝再宣言しない）

- **注意（GEM画面）:** 汎用画面は標準で `name`/`description` を検索・詳細に表示する。独自 `Name` を画面に表示する・標準 `name` を隠すには**View(EntityView)側のレイアウト調整**が必要（Entity定義のスコープ外）。
- **注意（既存データ）:** name指定プロパティを後から変えても既存レコードは自動更新されない。独自 `Name` が未設定の既存データは、次回更新時にエラーになり得るためエクスポート/インポートで補完する。
- **代替手段（採用しない）:** システム共通プロパティ（`name` 等）の表示名だけを変えたい場合、そのプロパティを対応する型で `displayName` 指定＋既定バリデーション保持で送るという最小変更もできる（取得時 `propertyList` にシステム既定`inherited:true`と上書き`inherited:false`が併存し、上書きが有効になる）。ただし本方針では独自項目として明示するため、この`name`のdisplayName上書きは使わない。

---

## 16. SalesforceId項目

**方針**: SFレコードデータをiPLAssへ移行する際、**移行元SFレコードのID（15/18桁）を突合キーとして保持する**ため、**移行対象の全Entityに共通で `SalesforceId` プロパティを1件追加する**。SFの項目メタデータ由来ではなく「移行運用のためにこちらで足す項目」で、独自Name（§15）と同様に各Entity共通の定型として扱う。

**固定仕様（Entityによらず同一。SFのIDは常に18桁ASCIIの大小英数字）**:

| 属性 | 値 | 理由 |
|---|---|---|
| API名 | `SalesforceId` | 全Entity共通名で機械処理しやすい |
| 表示名 | `SalesforceID`（ja/en共通） | — |
| 型 | String（`StringProperty`） | SF IDは英数字 |
| 桁数 | LengthValidation `max:18`（§4準拠） | SF IDは18桁（15桁短縮形も18桁枠に収まる） |
| multiplicity | 1 | — |
| 必須（NotNull） | **付けない** | 移行前は空。既存レコードのnullで保存不能になるのを避ける |
| 一意 | **`indexType:"UNIQUE_WITHOUT_NULL"`**（§9のindexType方式） | SF IDはレコード一意。ただし**`UNIQUE`（null含め重複不可）は不可**——移行前の既存レコードは本項目がnullで、null同士が重複違反になる。**必ず`UNIQUE_WITHOUT_NULL`**（値がある時だけ一意）にする |

- **name/oid指定はしない**（突合キーであって表示名ではない）。§15の `namePropertyName` とは無関係。
- **ExpressionやReferenceではなく素のString**（移行時に外部から値を流し込むだけ。式で導出しない）。

```json
{"@class":"org.iplass.mtp.entity.definition.properties.StringProperty",
 "name":"SalesforceId","displayName":"SalesforceID","type":"STRING",
 "updatable":true,"readOnly":false,"multiplicity":1,
 "indexType":"UNIQUE_WITHOUT_NULL",
 "validations":[
   {"@class":"org.iplass.mtp.entity.definition.validations.LengthValidation","messageCategory":"mtp/validation","messageId":"LengthMax","localizedErrorMessageList":[],"max":18,"checkBytes":false,"surrogatePairAsOneChar":true}],
 "normalizers":[],
 "localizedDisplayNameList":[
   {"@class":"org.iplass.mtp.definition.LocalizedStringDefinition","localeName":"ja","stringValue":"SalesforceID"},
   {"@class":"org.iplass.mtp.definition.LocalizedStringDefinition","localeName":"en","stringValue":"SalesforceID"}]
}
```

**手順**:

1. 新規Entity作成時: 上記オブジェクトを `propertyList` に1件足すだけ。
2. 既存Entityへ後付け時: `getDefinition` → live全項目を保持したまま `SalesforceId` を1件追加 → `updateDefinition`（全置換）→ `getDefinition` で declared件数が**+1**かつ `SalesforceId` が存在することを照合する。
3. 索引付与（`indexType`）はin-place updateで反映できる（事前の重複確認は§9参照）。

**理由**: 移行後の追随更新・再取込・SF↔iPLAssの突合をキー1本で機械化できる。全Entityで名前・型・一意方式を固定しておくと、変換ツール側も一律に自動付与でき、移行スクリプトが単純になる。

**レコードを丸ごと複製する処理では、この項目を写さない。** 新しいレコードは元レコードとは別のレコードなので、元の移行元IDを名乗ると**突合が1対多に壊れる**。`UNIQUE_WITHOUT_NULL`による重複エラーはその症状の一部にすぎず、**移行前の環境ではこの項目が空のため保存が通ってしまう**（症状が出ないことを根拠にできない）。SFの項目メタデータ由来ではないため、SFの複製処理を写すだけでは除外が漏れる。除外規則は [converting-salesforce-screens-to-iplass](../../converting-salesforce-screens-to-iplass/SKILL.md) §7.4 が定義位置。

---

## 17. 項目履歴管理

SFの項目履歴管理は、iPLAssのEntity単位のCRUD操作ログ（AdminConsoleのEntity定義の「save audit log」）に対応させる。プロパティではなく `EntityDefinition` のトップレベルの設定になる。

**判定はSFの2箇所を見る**。SFはオブジェクトで履歴管理を有効にした上で、項目ごとに `<trackHistory>` で追跡対象を選ぶ二段構えなので、**「追跡している項目が実際にあるか」を軸に判定する**。

| SF側 | iPLAss側 |
|---|---|
| `<trackHistory>` が `true` の項目が1件以上あり、`<Obj>.object-meta.xml` の `<enableHistory>` が `false` でない | トップレベルに `"auditLog": true` |
| 上記以外 | キーを書かない（＝`false`） |

**`<enableHistory>` だけを見てはいけない**。履歴管理は有効なのに追跡対象の項目が1件も無いオブジェクトがあり、SF側では何も記録されていない。ここで `auditLog` を有効にすると、移行元に無い記録を新たに始めることになる。

**`<enableHistory>` 要素の不在を無効と読まない**。履歴が常に有効で切り替えられない標準オブジェクトは、この要素を持たないまま項目側に `<trackHistory>true</trackHistory>` を持つ。SF側では実際に記録されているので、**要素が無い場合は追跡項目の有無だけで判定する**。無効と扱うのは `false` と明示されているときだけ。

変換器は判定に使った材料（`enableHistory` の `true`/`false`/要素なし、追跡項目の一覧）をレポートに出し、片方の条件しか満たさなかった場合は理由を標準出力に出す。

**粒度が違う**: iPLAssの `auditLog` はEntity単位のON/OFFだけで、プロパティ単位の切り替えは無い。**項目ごとの選択（`<trackHistory>`）は有効/無効の判定にだけ使い、対象の絞り込みは落とす**（宣言プロパティが一律に記録対象になる）。記録されるのは操作種別（登録／参照／更新／削除）・操作ユーザー・プロパティ名・更新前後の値。

**キーを省略すると `false` になる**。更新は全置換なので、`auditLog: true` のEntityへ他の変更を当てるときは、payloadに `"auditLog": true` を必ず載せる（liveを土台に作れば保持される）。値の切り替え自体は型・ストア構造に触れないため、全置換update1回で反映される。

**参照プロパティの `auditLogMappedBy`**: 参照側の操作ログを被参照側のEntityにも記録するかの設定。SFの項目履歴管理に対応する概念が無いため、変換では既定の `false` のままにする。

---

## 18. 添付ファイル項目

**方針**: レコードにファイルを添付できるようにするため、**移行対象の全Entityに共通で `Attachments` プロパティを1件追加する**。SFの項目メタデータ由来ではなく「こちらで足す項目」で、独自Name（§15）・`SalesforceId`（§16）と同様に各Entity共通の定型として扱う。SF側に `<type>File</type>` の項目（§2）があるかどうかとは無関係に追加する。

**固定仕様（Entityによらず同一）**:

| 属性 | 値 | 理由 |
|---|---|---|
| API名 | `Attachments` | 全Entity共通名で機械処理しやすい |
| 表示名 | `添付ファイル` | — |
| 型 | Binary（`BinaryProperty` / `BINARY`） | ファイル本体はBinaryストアに入り、プロパティ値は `BinaryReference`（`javaType` はサーバが付与する） |
| multiplicity | **32** | 1レコードに複数添付できるようにする。`-1`（無制限）は使わない（下記） |
| 必須（NotNull） | **付けない** | 添付が無いレコードで保存不能になるのを避ける |
| 索引（`indexType`） | **持たない** | BinaryPropertyにこのフィールドは無い（検索条件には使えない） |

```json
{"@class":"org.iplass.mtp.entity.definition.properties.BinaryProperty",
 "name":"Attachments","displayName":"添付ファイル","type":"BINARY",
 "updatable":true,"readOnly":false,"multiplicity":32,
 "validations":[],"normalizers":[],"localizedDisplayNameList":[]}
```

**手順**:

1. 新規Entity作成時: 上記オブジェクトを `propertyList` に1件足すだけ。
2. 既存Entityへ後付け時: `getDefinition` → live全項目を保持したまま `Attachments` を1件追加 → `updateDefinition`（全置換）→ `getDefinition` で declared件数が**+1**かつ `multiplicity` が32であることを照合する。プロパティの追加だけなので全置換update1回で反映される（他のプロパティ・`auditLog`・`eventListenerList` は保持される）。

**注意（`-1` にすると有限値へ戻せない）:** 多重度の変更は片方向にしか通らない。BinaryPropertyは無制限多重度（`-1`）も受理し、`32` → `-1` はin-place updateで通るが、**逆向き（`-1` → 有限値）はHTTP 500**になる。件数を絞るには、プロパティを一度 `propertyList` から外して全置換したうえで多重度32で作り直す2段階が必要で、**既存レコードの添付は失われる**。だから**最初から32で作る**。

**注意（画面表示）:** プロパティを足しても添付欄は画面に出ない。表示にはView(EntityView)側の調整が必要（§11と同じくEntity定義のスコープ外）。

**変換器は独自Name（§15）・`SalesforceId`（§16）と同様にこの項目を自動で付与する**（無効化する指定はCLIオプションで用意する）。同名の項目が既にあるときは二重に足さない。既存Entityへの後追いは自動化の対象外なので、上記JSONを手で1件足す。

---

## 19. 参照関係の付随属性（削除時の挙動・カスケード削除・親の付け替え）

SFの参照項目（Lookup / MasterDetail）が持つ「関係の性質」をiPLAssでどう表すか。プロパティ本体の型・`objectDefinitionName` は§2、参照先が未移行のときのフォールバックと自己参照の2段階投入は `SKILL.md` §6 が定義位置。

**方針: 参照は向きを変えず、LookupもMasterDetailも子側の `ASSOCIATION` にする。** iPLAssの `referenceType:"COMPOSITION"`（親子関係）は**プロパティを持っている側が親**で、親レコードの削除時に参照先（＝子）も削除される。SFのMasterDetail項目は子オブジェクトに置かれて親を指すため、`COMPOSITION` で表すには宣言を親Entity側へ反転させることになり、項目名も項目の所属Entityも移行元と食い違う。**反転はせず、カスケード削除はEventListenerで実装する**（§19.2）。

### 19.1 SF側の判別

| 判定 | 材料 |
|---|---|
| 主従関係（カスケード削除の対象） | 項目XMLの `<type>MasterDetail</type>` |
| 通常の参照（カスケード削除しない） | `<type>Lookup</type>` |

`<type>` は参照項目に必ず存在するので、これだけで排他的に切り分けられる。`<relationshipOrder>` / `<reparentableMasterDetail>` / `<writeRequiresMasterRead>` はMasterDetailにしか付かず、`<deleteConstraint>` はLookupにしか付かない（裏付けには使えるが、判定は `<type>` で行う）。

**`<referenceTo>` を持たないMasterDetail項目がある**。SF標準オブジェクトの主従関係項目は `<type>MasterDetail</type>` だけを持ち、親オブジェクト名がメタデータに出ない。主従だと判別はできても親が特定できないので、**親を推測せず「親が特定できない主従関係」としてレポートに出し**、カスケード削除の実装対象から外す。

### 19.2 カスケード削除（MasterDetail）

**親Entity**の `eventListenerList` に `BEFORE_DELETE` の `ScriptingEventListenerDefinition` を置く。EventListenerは宣言したEntityのCRUDイベントで発火するので、「親の削除」を契機にするなら設置先は親Entityになる（規則の出どころは子側のMasterDetail項目だが、リスナは親に置く）。リスナのJSON形状とバインド変数は `validation-rule-mapping.md` §5 が定義位置。

```json
{"@class":"org.iplass.mtp.entity.definition.listeners.ScriptingEventListenerDefinition",
 "withoutMappedByReference":false,"listenEvent":["BEFORE_DELETE"],"script":"<下記Groovy>"}
```

```groovy
import org.iplass.mtp.*;
import org.iplass.mtp.entity.*;
import org.iplass.mtp.entity.query.*;
import org.iplass.mtp.entity.query.condition.predicate.*;
def em = ManagerLocator.instance.getManager(EntityManager.class);
def q = new Query().select("oid", "version").from("<子Entity>")
        .where(new Equals("<子側の親参照項目>.oid", entity.getOid()));
em.searchEntity(q).getList().each { row ->
    def child = new GenericEntity("<子Entity>");
    child.setOid(row.getValue("oid"));
    child.setVersion(row.getValue("version"));
    em.delete(child);
}
```

- `AFTER_DELETE` ではなく **`BEFORE_DELETE`** を使う。子の削除に失敗したときに親ごとロールバックでき、§19.3 の削除拒否と同じ位置に揃う。
- 孫がある場合は `em.delete` が子側のリスナを呼ぶので連鎖する。
- **親Entityごとに1本のスクリプトにまとめる**。1つの親に複数の子Entityがぶら下がる場合も、子Entityごとのブロックを並べて1本にする。

### 19.3 参照先削除時の挙動（SF `<deleteConstraint>`）

`<deleteConstraint>` はLookup項目に付く。

| SF | iPLAss |
|---|---|
| `SetNull`（SF既定） | `ASSOCIATION` のまま。追加の実装はしない |
| `Restrict` | **参照される側**のEntityに `BEFORE_DELETE` のリスナを置き、参照元の件数を数えて0件でなければ例外を投げる |
| `Cascade` | §19.2 と同じ（参照される側のリスナで参照元を削除する） |

`Restrict` の判定（importと `em` の取得は §19.2 と同じ）:

```groovy
def cnt = em.count(new Query().select("oid").from("<参照元Entity>")
          .where(new Equals("<参照項目>.oid", entity.getOid())));
if (cnt > 0) { throw new ApplicationException("参照されているため削除できません。"); }
```

`ApplicationException` は `org.iplass.mtp.ApplicationException`（メッセージの出し方は `validation-rule-mapping.md` §5）。

同じEntityが §19.2 の親でもあり `Restrict` の参照先でもある場合は、**1本の `BEFORE_DELETE` スクリプトに「消す子」と「あれば拒否する参照元」を同居**させる（同じ `listenEvent` のリスナを複数置かない）。

### 19.4 親の付け替え（SF `<reparentableMasterDetail>`）

| SF | iPLAss |
|---|---|
| `false`（SF既定。要素が無い場合も同じ） | **子側の親参照プロパティ**の `validations` に `ScriptingValidation` を足し、既存レコードで参照先が変わったらエラーにする |
| `true` | 何も足さない（既定で変更できる） |

```groovy
import org.iplass.mtp.*;
import org.iplass.mtp.entity.*;
import org.iplass.mtp.entity.query.*;
import org.iplass.mtp.entity.query.condition.predicate.*;
if (entity.getOid() == null) { return true; }          // 新規登録は自由
def em = ManagerLocator.instance.getManager(EntityManager.class);
def rows = em.searchEntity(new Query().select("<PROP>").from("<子Entity>")
           .where(new Equals("oid", entity.getOid()))).getList();
if (rows.isEmpty()) { return true; }
def old = rows.get(0).getValue("<PROP>");
def oldOid = (old == null) ? null : old.getOid();
def newOid = (value == null) ? null : value.getOid();
return oldOid == newOid;
```

- `ScriptingValidation` のJSON形状は§9(B)と同じ。Reference（多重度1）のバインド変数 `value` は `Entity` なので **`getOid()` で比べる**（`GenericEntity` は `equals` 未オーバーライドなので実体比較はできない。`validation-rule-mapping.md` §4 と同じ理由）。
- 新規登録では通るので、移行データの初期投入を妨げない。
- MasterDetailは実質必須なので、このプロパティには `NotNullValidation`（§3）も並ぶ。

### 19.5 実装の扱い

**変換器はこの節の実装に追随していない**。生成物に載るのは子側の `ASSOCIATION` の `ReferenceProperty` だけで、`<deleteConstraint>` / `<reparentableMasterDetail>` / 主従関係の判別結果は読まれない。§19.2・§19.3 のリスナと §19.4 の `ScriptingValidation` は**手で足す**。手書き分の置き場と、全置換のたびにpayloadへ再度載せる必要があることは `validation-rule-mapping.md` §6 が定義位置。まだ足していないものは保留台帳に残す（`SKILL.md` §7）。

---

## 20. レコードタイプ

**方針**: SFのレコードタイプ（`objects/<Obj>/recordTypes/*.recordType-meta.xml`）は、iPLAss側では**選択肢1項目として持つ**。レコードタイプがあるオブジェクトにだけ `RecordType` プロパティを1件足す（無いオブジェクトには足さない。独自Name（§15）・`SalesforceId`（§16）・`Attachments`（§18）と違い**全Entity共通ではない**点に注意）。

レコードタイプは項目メタデータ（`fields/`）に現れないので、`recordTypes` ディレクトリを直接読む。

**固定仕様**:

| 属性 | 値 | 理由 |
|---|---|---|
| API名 | `RecordType` | オブジェクトによらず同名にして機械処理しやすくする |
| 表示名 | `レコードタイプ` | — |
| 型 | Select（`SelectProperty` / `SELECT`） | 値の集合が定義側で閉じているため |
| multiplicity | 1 | SFのレコードタイプはレコードにつき1つ |
| 選択肢 | SVD参照（`selectValueDefinitionName`）のみ | §7と同じ扱い。インライン `selectValueList` は書かない（併記すると参照がクリアされる） |
| 必須（NotNull） | **付けない** | 移行前・移行途中のレコードで保存不能になるのを避ける（§16・§18と同じ判断） |
| 索引（`indexType`） | 持たせない | — |

**SVDの作り方**:

- **SVD名**: `<Entity短縮名>_RecordType`。ローカル値セットの命名規則（§7）に揃える。**レコードタイプはオブジェクト固有なのでSVDを他Entityと共有しない**——ラベルがたまたま同一の別オブジェクトがあっても、片方の増減がもう片方に及ばないようEntityごとに作る。
- **値**: 各レコードタイプの `<label>` を `value` と `displayName` の**両方**に入れる（`<fullName>`（API名）ではなくラベル。既存の選択肢が表示用の接頭辞込みの値を持つのと同じ流儀で、`a.` `01.` のような並び順を表す接頭辞も落とさずそのまま使う）。`<label>` が無いものは `<fullName>` を使う。
- **順序**: ラベル昇順。接頭辞が並び順を表しているため、ファイル名（API名）順にはしない。
- **非active**: `<active>false</active>` のレコードタイプは選択肢に入れない（§7のPicklistの `isActive` と同じ扱い）。除外した事実は変換器のレポートと標準出力に出す。
- **displayName**: SVD自体の表示名は `レコードタイプ`。
- 同名のSVDが既にあれば**再利用**する（§7と同じ）。

```json
{"@class":"org.iplass.mtp.entity.definition.properties.SelectProperty",
 "name":"RecordType","displayName":"レコードタイプ","type":"SELECT",
 "javaType":"org.iplass.mtp.entity.SelectValue",
 "updatable":true,"readOnly":false,"multiplicity":1,
 "validations":[],"normalizers":[],"localizedDisplayNameList":[],
 "selectValueDefinitionName":"<Entity短縮名>_RecordType"}
```

**移行しないもの**: レコードタイプの `<picklistValues>`（レコードタイプごとに選択可能なPicklist値を絞り込む設定）と `<compactLayoutAssignment>` は、iPLAssのEntity定義に対応する概念が無いので**移行しない**。レコードタイプ別に選択肢を絞る要件が残る場合は、画面側（View）またはEventListenerでの実現になるので保留として扱う（`SKILL.md` §7）。SFのレコードタイプはページレイアウトの割り当ても兼ねるが、Viewの作り分けはEntity定義のスコープ外（§11と同じ）。

**手順**:

1. 新規Entity作成時: 新規SVDを投入したうえで、上記オブジェクトを `propertyList` に1件足す。**SVDより先にEntityを投入すると参照先が無く失敗する**。
2. 既存Entityへ後付け時: SVDを投入 → `getDefinition` → live全項目を保持したまま `RecordType` を1件追加 → `updateDefinition`（全置換）→ `getDefinition` で declared件数が**+1**、`selectValueDefinitionName` が効いている（取得結果の `selectValueList` にレコードタイプのラベルが並ぶ）ことを照合する。プロパティの追加だけなので全置換update1回で反映される。

**変換器は独自Name（§15）・`SalesforceId`（§16）・`Attachments`（§18）と同様にこの項目とSVDを自動で付与する**（`recordTypes` ディレクトリの有無が唯一のスイッチで、無効化オプションは無い）。SF側に `RecordType` という名前の項目があるときは二重に足さない。既存Entityへの後追いは自動化の対象外で、liveを土台に1件足す（`iplass-definition-io` §9）。

**注意（画面表示）:** プロパティを足しても画面には出ない。表示にはView側の調整が必要（§11・§18と同じくEntity定義のスコープ外）。
