---
name: converting-salesforce-to-iplass-entity
description: Salesforceのオブジェクト(標準オブジェクト・カスタム__cオブジェクト)とその項目メタデータをiPLAssのEntity定義へ変換・移行するとき、SF項目型・必須・桁数・一意・選択肢(グローバル値セット/SelectValueDefinition)・複数選択(多値)・デフォルト値・数式・入力規則をiPLAssプロパティ/バリデーションへマッピングするとき、既にデプロイ済みのEntityへSFメタデータ由来の変更を後追いで適用するとき、SF→iPLAss migration/reverse で使う。
---

# Salesforceオブジェクト → iPLAss Entity 変換

## 1. 変換の流れ

変換は3段階で進む。

1. **変換** — SFの項目メタデータ（XML）を読み、iPLAssプロパティのJSONへマッピングして `EntityDefinition` を組み立てる。
2. **デプロイ** — 組み立てた定義を投入する（経路の選び方・書き込み規則は `iplass-definition-io` が定義位置）。
3. **照合** — 取得し直して、送った項目が実際に保存されたか件数で確認する。

実際の作業順は、対象オブジェクトの特定（§2）→ Entity名の決定（§3）→ 新規作成（§4）または既存更新（§5）→ **保留の検出と報告（§7）** → 必要に応じて §6・§8〜§10、という順になる。

到達点は **Entity定義＋新規SelectValueDefinition（SVD）のデプロイと照合、および保留の状態の報告まで**。詳細View（画面）・メニュー定義は別作業として扱う。保留の記録の更新と保留の解除そのものは、報告した上でユーザーが決める（§7）。

型・数式・参照などで想定外の状況に出会ったら、その都度ユーザーに報告して個別に対処する。個々の判断を機械的なルールで先取りしない。

型・属性のマッピング、入力規則の振り分けの詳細は `references/property-mapping.md` / `references/validation-rule-mapping.md` が定義位置（末尾の「リファレンス」参照）。型以外の属性を扱うときは必ずそちらを見る。

## 2. 対象オブジェクトの特定

指示は日本語ラベルで来ることもあれば、SF API名で来ることもある。ラベルで来た場合は `objects/<Obj>/<Obj>.object-meta.xml` の `<label>` から引き当てる。

**同じ日本語ラベルを持つ別オブジェクトが存在することがある**。絞り込めないときは候補を挙げてユーザーに確認する。厳密なスコープ規則は定めない。

## 3. Entity名の決め方

iPLAss側のEntity名は、移行元SFオブジェクトのAPI名を踏襲する。カスタムオブジェクトの接頭辞や独自プレフィックスは残し、`__c`（カスタム接尾辞）だけ除去して `<パッケージ>.<SF API名（接頭辞付き・__c除去）>` とする。**同一プロジェクト内の既存Entityと接頭辞の付け方を必ず揃える**。

**システム項目との対応**:

- SF `Name` → 各Entityで独自プロパティ `Name` を作成し、`namePropertyName` でEntityの `name` として指定する（基本方針）。標準の `name` は再宣言しない。
- SF `Description` → 標準の `description` に対応させ除外する（再宣言しない）。監査系（作成者・更新日時等）→ 標準の作成/更新系プロパティに対応させ除外する。
- iPLAssのシステム項目の表示名は変更しない。

独自Nameの型条件・JSON形状は `references/property-mapping.md` §15 が定義位置。

## 4. 新規作成（Entity未作成）

対象のEntityがまだ存在しないときだけ、この経路を使う。

1. **liveの現況を取得** — Entity一覧と共通SVD一覧を取得する（参照先が移行済みか、既存SVDを再利用できるかの判定に使う）。
2. **変換器で生成** — 対象のSF API名と①の一覧を渡し、テーブル駆動の変換器で `EntityDefinition` と新規SVDを生成する。**項目は手書きしない**。表示名にはSFの `<label>` の値を渡す（渡さないと英語のAPI名がそのまま表示名になる）。呼び出し方は `scripts/sf-to-iplass/README.md` を参照する。`EntityDefinition` は基本的にこの変換器の生成物として手元にある。**手元に無ければ、まずこの変換器で生成する**のが起点。
3. **保留を確認** — 生成物の保留台帳（§7）とレポートに目を通し、保留の内容をユーザーに報告する。申し送りへの記入は報告後にユーザーが決める（§7）。
4. **入力規則の振り分けを確認** — 変換器はSFの入力規則（ValidationRule）も自動で読む。機械変換できない規則は保留台帳に出るので、手書きで実装するか保留にするかをユーザーに確認する（振り分け規則は `references/validation-rule-mapping.md` が定義位置）。
5. **投入して照合** — 新規SVD → Entityの順に投入し、取得し直して件数照合する（投入・照合の作法は `iplass-definition-io` が定義位置）。

**変換器が自動で行うこと**（手作業で足す必要はない。各項目の詳細は `references/property-mapping.md` の該当節が定義位置）: 独自Name＋`namePropertyName`の設定（標準オブジェクトは項目メタデータ、カスタムオブジェクトは`.object-meta.xml`の`<nameField>`から。条件は `references/property-mapping.md` §15 が定義位置） / `SalesforceId`の付与 / 共通の添付ファイル項目 `Attachments` の付与（`references/property-mapping.md` §18 が定義位置。SF側にFile型の項目が無くても足す） / レコードタイプ→`RecordType`（SELECT）＋SVDの付与（`references/property-mapping.md` §20 が定義位置。`recordTypes` ディレクトリがあるオブジェクトにだけ付く） / 必須→NotNull / 桁数→LengthValidation / 一意→`UNIQUE_WITHOUT_NULL` / 整数→Decimal(scale0)+Regex / precision→RangeValidation / 選択肢→SVD参照（SF側がローカル値セットでもSVDにする。同名の既存SVDは再利用） / 多値→multiplicity 32 / 未移行参照→String保留 / 数式→既定でString保留＋台帳記録 / Summary→readOnlyの値保持（Expression化は手当てが必要） / 項目履歴管理→`auditLog`（追跡している項目があり、かつ`<enableHistory>`が`false`でないときだけ有効。有効にしなかった場合は理由を報告する）。

投入前後の誤りやすい点は `references/property-mapping.md` / `references/validation-rule-mapping.md` の各節に事実として書かれているので、そちらを確認する。

## 5. 既存更新（デプロイ済み）

対象のEntityが既にデプロイ済みで、そこにSFメタデータ由来の変更を後追いで当てるときの経路。

**最も重要な注意**: SFメタデータから作り直したpayloadを、既存Entityへそのまま `put`（全置換）してはいけない。liveに積み上がった手当て（数式のExpression化、参照のReference化、一意チェック、形式チェックのRegex、`displayName`の反映、保留メモ 等）を、SFメタデータからの再生成物は再現しない。そのまま送ると、これらの手当てをまとめて踏み潰す。

**使うツール**: SFメタデータから全体を作り直す変換器（§4で使うもの）ではなく、**liveの定義を土台にデルタだけを当てるツール**を使う。呼び出し方は `scripts/sf-to-iplass/README.md` を参照する。

**手順**:

1. **liveを取得** — 対象EntityのliveのEntityDefinitionを取得する。
2. **保留の現況を検出して報告** — 検出ツールで保留と「解除できる状態になったもの」を出し、ユーザーに報告する（§7）。解除するかはユーザーが決めるので、この経路の作業を続けるか差し替えるかもここで確認する。
3. **デルタpayloadを生成** — 手順1のliveとSFメタデータ（入力規則・手書きValidator等の後追い分）を渡し、liveを土台にした全置換用payloadを生成する。
4. **レポートを確認** — 生成結果のレポートで `changedProperties`（変更対象になったプロパティ）・`eventListeners.removed`（削除されるリスナ）・`eventListeners.replaced`（差し替えられるリスナ。他者がAdminConsoleで足したリスナが宣言で上書きされる唯一の信号）・`duplicated`（重複判定）を確認し、想定外の変更・削除が無いかを見る。
5. **diffを取る** — liveと手順3で生成した投入予定JSONのdiffを取り、意図した差分だけになっているか確認する。
6. **投入して照合** — `put` で投入し、取得し直して照合する（作法は `iplass-definition-io` が定義位置）。
7. **保留の状態を再検出して報告** — 投入後にもう一度検出し、状態が変わった点を報告する。申し送りの更新（解除できた行の削除・新しい保留の追記）はユーザーが決めてから行う（§7）。

**手書きValidator/EventListenerの再適用**: 手書きのValidator・EventListenerの正本はlive自身（デプロイのたびに再度payloadへ載せないと次回の全置換で消える）。再適用が必要なときは、Groovy本文を推測で書き直さず、live定義の `script` の値をそのまま取り出して使う（詳細は `references/validation-rule-mapping.md` §6）。

**この経路の適用範囲**: 上記のデルタ適用ツールが機械的に当てるのは入力規則由来のRegexと手書きValidator/EventListenerのデルタだけである。SF側で項目やレコードタイプが追加された、または桁数・選択肢が変わった場合は対象外（§4の変換器は既存Entityには使えないため、この経路では手が届かない）。この場合は、liveを土台に該当キーだけ機械的に書き換えて全置換する（手順は `iplass-definition-io` §9、マッピングは `references/property-mapping.md` が定義位置）。

**新規作成との使い分け**:

| | 新規作成（§4） | 既存更新（この節） |
|---|---|---|
| 起点 | SFメタデータのみ | liveの定義＋SFメタデータ |
| 投入 | `post` | `put`（全置換） |
| 差分確認 | 不要 | 必須（diff・レポートの確認） |
| 用いるツール | 変換器（全体生成） | liveを土台にしたデルタ適用ツール |

初回デプロイまでは§4の変換器、一度でも手当てが入った既存Entityはこの節のデルタ経路、という判断になる。変換のコアロジック（入力規則の機械変換・手書き分のマージ等）は両経路で共有しているため、判断の分岐点はどちらのツールを起動するかだけである。

投入前後の誤りやすい点は `references/property-mapping.md` / `references/validation-rule-mapping.md` の各節に事実として書かれているので、そちらを確認する。

## 6. 参照項目の扱い

**自己参照**: 自Entity名を指す `ReferenceProperty`（例: 自身の親を指す項目）は、作成時点では自Entityがまだ存在しないため `<EntityName> is undefined` になる。この項目を**除いて作成し、その後のupdateで追加する**2段階で進める（自己参照そのものは以降、通常の `ReferenceProperty` と同じ扱いでよい）。

**関係の性質**: `referenceType` はLookupもMasterDetailも `ASSOCIATION` にし、SFと同じ向き（子が親を指す）を保つ。主従関係のカスケード削除・`deleteConstraint`・親の付け替え禁止は `references/property-mapping.md` §19 が定義位置。

**参照先が存在しない場合のフォールバック**: SFのLookup相当で参照先EntityがiPLAss側にまだ存在しない場合、登録が失敗する。参照先が無い `ReferenceProperty` は `StringProperty`（参照先ID保持）へ差し替える。標準の所有者項目（SFのOwnerId相当）は、iPLAss側の実体が認証ユーザーEntityであることに注意する。

**保留の記録**: どの項目がString保留（参照先未移行によるフォールバック）かは保留台帳に残す（§7）。参照先が後から移行できた場合にReferenceへ戻す手順は §10。

既存Entityへ上記の2段階（自己参照追加、Stringフォールバックの解除）を後から当てる場合も、liveに積み上がった手当てを踏み潰さないよう §5 のデルタ経路を使う。

## 7. 保留事項の記録

保留の置き場（状態は導出／判断は申し送り／スナップショットは `work/`）・申し送りの書式・検出と更新の境界・並行作業の進め方は `coordinating-migration-work` が定義位置。**状態の正は検出ツールの出力**で、呼び出し方は `scripts/sf-to-iplass/README.md` を参照する。

Entity変換で出る保留は次の種類。解除の手順はそれぞれの定義位置に従う。

| 保留 | 解除 |
|---|---|
| **対象Entityがそのものとして未作成**（画面やViewの移行が先に来て、土台のEntityが無いと分かった） | このEntityを新規作成する（§2の新規作成の経路）。参照項目のフォールバック（§10）は**既にあるEntityの参照が未移行**のときの話で、Entity自体が無いケースには使えない |
| 参照がStringのまま（参照先が未移行） | 参照先の移行後に `ReferenceProperty` へ戻す（§10） |
| 自己参照が未追加（作成時には載せられない） | 作成後の別のupdateで追加する（§6） |
| 数式が未Expression化 | 参照先の移行後、または実行コンテキスト依存が解消してからExpression化する（`references/property-mapping.md` §14） |
| Summaryが未Expression化 | 子Entityの移行後に相関スカラーサブクエリで表す（同 §14） |
| 選択肢が未確定でStringのまま | 値が判明したらSVD参照のSELECTにする（同 §7） |
| `RecordType` が未追加・型がSELECTでない・選択肢がSFのレコードタイプとずれている | SVDを投入し、liveへ `RecordType` を1件足す（同 §20） |
| 主従関係のカスケード削除・参照先の削除拒否が未実装 | 親（参照される側）Entityに `BEFORE_DELETE` のリスナを足す（同 §19.2・§19.3） |
| 親の付け替え禁止が未実装 | 子側の親参照プロパティに `ScriptingValidation` を足す（同 §19.4） |
| View側で対応するもの（複数行入力・初期値・リンク表現） | View作業へ回す（同 §10・§11） |
| 数式・Summaryをカスタム画面だけが使うもの | やらない: 画面側で算出する（`converting-salesforce-screens-to-iplass` §5）。Entity側をExpression化せずに済み、Summaryが値保持で自動更新されない問題も画面側の算出で回避できる |

Entityの `description` に保留メモは書かない。

## 8. 表示名の反映

SFの `objectTranslations/<Obj>-<lang>/*.fieldTranslation-meta.xml` から `displayName` を反映する。

翻訳キーは項目API名と一致しないことがある。SF標準の翻訳キーはスネークケース（`<obj>_<項目の意味>` のような形）で、項目APIのキャメル/パスカルケース表記と文字面が一致しない。加えて、セクション・関連リスト・ボタン等、項目に対応しない**非項目キー**も混在する。項目に対応するキーだけを反映し、非項目・対応プロパティ無し・対応が不確実なものは除外してユーザーに報告する。

**表示名の出所は3つあり、SF標準項目だけ翻訳ファイルから引けない。**

| 対象 | 出所 |
|---|---|
| カスタム項目（`__c`） | 項目XMLの `<label>`。変換器が既定で反映する |
| 表示名を上書きしている項目 | `objectTranslations` の項目翻訳 |
| **SF標準項目** | **SF組織の describe**。項目XMLに `<label>` が無く、`objectTranslations` にも載らない |

標準項目は上2つで埋まらないので英字のAPI名が残る。SF組織へ接続できるなら describe のラベルを出所にする（組織の既定言語が日本語なら日本語で返る）。**describeで引いてもラベルが英字の項目がある**（SF側でも英語の項目）ので、その場合は英字のままが正しい。反映できなかった項目は理由を分けて報告する（describeに無い／SF側も英語）。

`displayName` だけの変更でも `updateDefinition` は全置換のため、全項目を再送する必要がある（送信サイズの縮小は `iplass-definition-io` §8 が定義位置）。

**照合**: 取得し直して、対象 `displayName` が期待値になっているか、`declared` 件数が一致しているか、選択肢が破損していないかを確認する（`displayName` のみの変更は型・ストア変更を伴わないため保存時SQLエラーのリスクは無い）。

## 9. SF原本との照合

過去の変換で、日本語のラベル・選択肢値が別の文字に化けたまま登録されていることがある。iPLAss側だけを見ても「不自然だが有り得なくはない表記」に見えるため気づきにくい。

**照合先は常にSFメタデータ側**（一次情報）。

- 表示名 → 項目XMLの `<label>`
- 選択肢値 → 項目XMLの `<valueSetName>` を引いて、対応するグローバル値セットの `<fullName>`。ローカル値セットの場合は項目XML内の `<valueSetDefinition>`

**項目API名と値セット名は一致しない**ので、選択肢の照合は必ず `<valueSetName>` を経由する（項目API名から値セット名を推測しない。項目名とは大きく異なる名前の値セットを参照するケースもある）。

選択肢の `value` は業務データそのもの（レコード側にも同じ文字列が入る）なので、`displayName` だけでなく `value` も直す。**データ投入後は既存レコードとの不一致になるため、スキーマ構築フェーズのうちに直す**。

**洗い出し方**: 疑わしい文字やXMLエスケープの復号漏れ（`&amp;` 等）を、全Entityの取得結果に対して横断的にgrepすると一括で見つかる。Entity単位の作業ではなく、テナント全体で1回行う点検として扱う。

選択肢の値・`displayName` の修正は型変更を伴わないため、`updateDefinition` の全置換1回で済む（§10のような除去→再追加の2段階は不要）。

## 10. 参照先が後から移行できたとき

§6でStringにフォールバックした項目を、参照先Entityの移行後に `ReferenceProperty` へ戻す作業。

**in-place変更は不可**: 既存のStringプロパティをそのまま `ReferenceProperty` に差し替えて `updateDefinition` すると、`Illegal Type Convert. PrimitiveProperty to ReferenceProperty cannot support.` で失敗する。

**手順（全置換update×2回）**:

1. 該当プロパティを**除去**した定義で更新する。
2. `ReferenceProperty` として**再追加**した定義で更新し、取得し直して照合する。

項目が何件あっても2回で済むので、**同一Entity内の複数項目はまとめて1往復で変換する**。

**式の同時扱い**: 変換対象を参照する `ExpressionProperty` があれば、①で同時に除去し、②で書き戻す。式中の参照は `<項目> IS NULL` を `<項目>.oid IS NULL` に書き換え、View表示で確認する。

**データ未投入時の縮小**: レコードが未投入のスキーマ構築フェーズなら、①の定義を独自Name＋`SalesforceId`だけの最小定義にして出力量を半減できる（データ投入後は使えない）。宣言プロパティが100件を超える規模のEntityでも、この最小化手法は1回の出力で機能する。**独自NameがAutoNumberのEntityを最小定義に落とすと、採番プロパティも作り直しになり採番がリセットされる**（データ未投入なら問題ない）。

## 11. 多重度の決め方

**JSONでの書き方**: `multiplicity` は**数値**。AdminConsoleの `*` はJSONには現れない。

| 表したいこと | JSONに書く値 | AdminConsoleの表示 |
|---|---|---|
| 単一値 | `1` | `1` |
| 複数値（上限あり） | 上限の数値（例 `32`） | `32` |
| 無制限 | `-1` | `*` |

- `"*"` のような非数値の文字列を書くと **HTTP 400** で弾かれ、定義は書き換わらない。
- `"32"` のような数値文字列は数値に変換されて通る（取得すると数値で返る）が、**数値で書く**。

**無制限（`-1`）を設定できるのはReference型だけ**。単一値は `1`、複数値は必要な数（指定が無ければ32）を入れる。`0` は値を持てない指定なのでどの型でも使わない。

| 型 | `-1` |
|---|---|
| REFERENCE | 使える。被参照の件数を制限しないときはこれにする |
| SELECT | 不可。画面（詳細View）の表示・保存で失敗する（`references/property-mapping.md` §8） |
| その他（BINARY等） | 使わない。BINARYは有限値へ戻す更新が通らず、プロパティの作り直しになる（同 §18） |

**定義APIはReference以外の型でも `-1` を受理する**。`{"status":"SUCCESS"}` や取得結果に `-1` が入っていることは、その型で使えることの証拠にならない。**Reference以外で無制限が必要に見えるときは、別Entity＋Referenceで表す**。変換器は多重度が0以下のプロパティを検査エラーとして弾く（通すのはReferenceの `-1` だけ）。

## 12. レコードトリガのFlow → EventListener

SFのレコードトリガFlow（レコードの登録・更新を契機に走る自動処理）は、対象EntityのEntity定義の
`eventListenerList` に `ScriptingEventListenerDefinition` として置く。JSON形状とバインド変数は
`references/validation-rule-mapping.md` §5 が定義位置。

| Flowがやっていること | 置く場所 |
|---|---|
| 別Entityへ履歴レコードを作る | `AFTER_UPDATE` / `AFTER_INSERT` |
| 自Entityの項目を書き換える（最終更新者・日時の類） | `BEFORE_UPDATE` / `BEFORE_INSERT`。`entity.setValue` で足す |
| 更新前の値との比較が必要 | `BEFORE_UPDATE` で控えて `context.setAttribute` へ置き、`AFTER_UPDATE` で受け取る |
| 連番・採番 | リスナで採らない（下記） |

**同一Entityへの検索を、そのEntityの登録・更新と同じトランザクションの中でやらない。**
`BEFORE_INSERT` のリスナから自Entityを検索して最大値を採る形（当日連番の採番など）は、リクエストが
応答を返さないまま滞留し、滞留したリクエストがDB接続を握るためコネクションプールが枯れる。枯れると
そのEntityだけでなく**他Entityのレコード操作も定義APIの書き込みも通らなくなり、リスナを外す更新も
送れない**（復旧はアプリケーションサーバの再起動）。連番は `AutoNumber` プロパティの書式で作るか、
`AFTER_INSERT` で自Entityを触らない形に設計する。

**EventListenerのスクリプトからUtilityClassは参照できない。** `UtilityClassDefinition` を作って
リスナから呼ぶと、レコードの登録が `WebApiRuntimeException: System error occurred.`（HTTP 500）になる
（定義名をピリオド区切りにして `package` を付けても同じ）。共通の処理は**各リスナの中に直接書く**。
複数のリスナが同じ処理を持つときは、片方だけ直して食い違わないよう、両方に同じ意図のコメントを置く。

**投入前に用意すること**: リスナを載せる更新を送る前に、リスナ無しへ戻すペイロードを `work/` に置く。
リスナが原因で環境が応答しなくなると、その時点から戻すペイロードを組み立てられない。

## リファレンス

| 参照先 | 用途 |
|---|---|
| [references/property-mapping.md](references/property-mapping.md) | SF項目型・属性 → iPLAssプロパティ/バリデーションの型・属性マッピング（このSKILL固有。まずここを見る） |
| [references/validation-rule-mapping.md](references/validation-rule-mapping.md) | SF入力規則（ValidationRule）→ iPLAssのプロパティValidator/EventListenerへの振り分けと実装 |
| `coordinating-migration-work` | 保留の置き場と申し送りの書式、検出と更新の境界、複数人で並行して進めるときの規約 |
| `iplass-definition-io` | 定義API/MCPでの取得・作成・更新・削除の作法（経路選択・書き込み規則・サイズ対策・安全策） |
| `iplass-dev` プラグインの各スキル（`iplass-metadata` / `iplass-entity` / `iplass-query` / `iplass-docs`） | Entity定義・プロパティ型・EQL文法・公式仕様のiPLAss側一次情報 |

iPLAssの仕様・JSON形状・EQL文法が不明なときは記憶で補わず、上のスキルを参照する。環境固有の値（ラッパーの実体パス・パッケージ名・認証用の環境変数・MCPサーバ名等）は [CLAUDE.md](../../../CLAUDE.md) の固有値表を参照する。
