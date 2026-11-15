# SF入力規則 → Validator / EventListener

Salesforceの入力規則（ValidationRule）を、iPLAssのプロパティValidator（`RegexValidation` / `ScriptingValidation`）または `BEFORE_VALIDATE` の EventListener へどう振り分け・実装するかのリファレンス。`ScriptingValidation` のJSON形状そのものは `property-mapping.md` §9 が定義位置であり、ここでは再掲せず参照する。

---

## 1. 振り分けの判断

対象は `active=true` の入力規則（`objects/<Obj>/validationRules/*.validationRule-meta.xml`）のみ。変換器はこのディレクトリを自動で読み込み、`active=false` は除外する。振り分けは次の順で判断する。

1. **単一項目・自己完結** → プロパティの `RegexValidation`（形式チェック）または `ScriptingValidation`（それ以外）
2. **複数項目の相関 / 更新前値（`ISCHANGED`・`ISNEW`）も、原則プロパティの `ScriptingValidation`** にする。`ScriptingValidation` は `entity` から他項目を読めるので相関判定ができ、更新前値は `EntityManager.load` で取れる。**プロパティValidatorのエラーはiPLAssがネイティブに集約して全部表示する**（`NotNullValidation`/`LengthValidation`/`RegexValidation` が同時に出るのと同じ仕組み）のが決定的な利点で、複数の規則が同時に違反しても1回の保存で全部出る
3. **`BEFORE_VALIDATE` の EventListener は「どのプロパティにも紐づけられない」場合の最後の手段**にする。`EntityValidationException` に `ValidateError` を1件以上積むと、GEMは `validateResults` があればそちらだけを描画し、例外メッセージ（画面上部ぶん）は表示されない。`ValidateError` の `propertyName` を未設定にした場合の描画は公式ドキュメントに記載が無く依存できない。EventListenerが必要になるのは、`ScriptingValidation` のバインド変数（`value`/`entity`/`propertyName`/`context`）では判定できないもの（実行ユーザーの権限など）
4. 出し先はSFの `errorDisplayField` に合わせるのが基本だが、**「確実に表示されること」を優先する**。`errorDisplayField` が無い（＝SFでは画面上部）規則も、原因項目のプロパティに紐づけて出す
5. iPLAss側に対応概念が無くて判定できないもの（ロール未確定等）は実装せず、保留台帳（`SKILL.md` §7）に理由と解除条件を書く

上記の判断で全件を①〜⑤のいずれかに振り分ける（自動変換 / 手書き / 保留のいずれかに必ず落とす）。

---

## 2. 機械変換できる形

`REGEX()` 単独の3パターンだけを変換器が `RegexValidation` へ機械変換し、それ以外は保留台帳に理由付きで残す。SFの `REGEX()` は文字列全体一致なので、`^`/`$` を補えば iPLAss の `RegexValidation` と同じ判定になる。

| # | `errorConditionFormula` | 空許容（先頭 `\|`） |
|---|---|---|
| P1 | `NOT(REGEX(<f>, "<pat>"))` | `<pat>` が空文字に全体一致するときだけ付ける |
| P2 | `!ISBLANK(<f>) && !REGEX(<f>, "<pat>")` | 常に付ける |
| P3 | `IF(ISBLANK(<f>), False, NOT(REGEX(<f>, "<pat>")))` | 常に付ける |

`^[0-9]*$` は空文字にマッチするのでSFでも空はエラーにならない → `\|` を付ける。`^[0-9]+$` はSFでも空がエラー → 付けない。一律で付けると挙動がずれる。

---

## 3. 既存 validations の扱い

入力規則由来のRegexで差し替えるのは**型由来の既定Regex（`messageId` を持たない `RegexValidation`）だけ**。整数ガード（`messageId:"Integer"`）・`LengthValidation`・`NotNullValidation`・`RangeValidation`・一意チェックの `ScriptingValidation` はすべて保全する。**入力規則が無い項目の既定Regexは触らない**。

---

## 4. ScriptingValidation で相関・更新前値を判定する

`ScriptingValidation`（プロパティ）のバインド変数は `value`（対象値）/ `entity` / `propertyName` / `context`（`ValidationContext`）、戻り値は `boolean`（`false`=エラー）。JSON形状は `property-mapping.md` §9 と同じ。

`ValidationContext` には `UPDATE_OPTION` / `BEFORE_UPDATE_ENTITY` のような更新前情報への**アクセス手段が無い**（これらは `EntityEventContext` 専用）。したがって:

1. 新規登録の判定は `entity.getOid() == null`（SFの `ISCHANGED` は挿入時 false なので、`ISCHANGED` 由来の規則は新規では判定しない）
2. **`ISCHANGED` 相当（＝値そのものが変わったかを見る）は `EntityManager.load` で旧値を取り、`value` と比較する。** `GenericEntity` は `equals` を**未オーバーライド**（同一性比較）なので、Reference型（`Entity`）を比較する場合は素の `==` だと同一参照先でもインスタンスが違えば「変更あり」と誤判定する。`value`/旧値の双方を、Entityなら `getOid()`、それ以外ならそのまま、という形に正規化してから比較する
3. **相関先の項目（判定に使うだけで、それ自体の変更は見ない項目）は `entity.getValue(名)` だけを見る。旧値へフォールバックしない。** `GenericEntity.setValue(name, null)` は**キーを作らない**ため、「送られた `null`（＝クリア）」と「未送信」を entity 側からは区別できない。旧値へフォールバックすると、「相関先の項目をクリアして規則の条件を満たさなくする」という、規則が本来通すべき保存を誤って弾いてしまう。画面（GEM/mdc）は全項目送信するため、フォールバックしなくても検出力は落ちない。API部分更新でこの判定が働かない穴は許容する
4. 上記のとおり、相関先の項目だけを見る判定は `EntityManager.load` が不要になり得る。`load` を呼ぶのは「`ISCHANGED` 相当の比較に旧値が要る」場合だけにする（呼びすぎない）

---

## 5. BEFORE_VALIDATE の EventListener

`eventListenerList` に `ScriptingEventListenerDefinition`（`script` / `listenEvent` / `withoutMappedByReference`）を置く。バインド変数は `entity` / `context`（`EntityEventContext`） / `event` / `user` / `date`。

エラーの送出:

```groovy
// 画面上部に1本
throw new ApplicationException("メッセージ");              // org.iplass.mtp.ApplicationException

// 項目単位（errorDisplayField 相当）
def e = new ValidateError();                                // org.iplass.mtp.entity.ValidateError
e.setPropertyName("<プロパティ名>");
e.addErrorMessage("この項目は変更できません。");
throw new EntityValidationException("入力エラーがあります。", [e]);  // org.iplass.mtp.entity.EntityValidationException
```

SFは複数の規則違反をまとめて表示するので、リスナ内で全違反を収集して**最後に1度だけ**送出する。項目単位が1件以上あれば `EntityValidationException`（画面上部ぶんは例外メッセージに集約）、項目単位が0件なら `ApplicationException`。`ValidateError` を1件以上積むと例外メッセージ側は表示されない（§1）。項目単位と画面上部を同時に出す必要がある規則は、EventListener 1本への集約では実現できないため、§1 の方針②（プロパティ `ScriptingValidation`）に倒す。

**更新前値と部分更新**: `BEFORE_VALIDATE` の `entity` には**その更新で送られた項目だけ**が入る。`ISCHANGED` 相当や複数項目の相関を正しく判定するには次の順で解決する（`ScriptingValidation` の場合は §4 を見る。`UPDATE_OPTION`/`BEFORE_UPDATE_ENTITY` はEventListener限定でしか使えない）。

1. `context.getAttribute(EntityEventContext.BEFORE_UPDATE_ENTITY)` で更新前Entityを取る
2. 取れなければ `EntityManager.load(oid, "<Entity名>")` にフォールバック
3. `context.getAttribute(EntityEventContext.UPDATE_OPTION)` の `getUpdateProperties()`（`List<String>`）に含まれない項目は更新前値を使う
4. 新規登録の判定は `entity.getOid() == null`

**「更新前値で補う」フォールバックは入れない**（§4と同じ理由）。`GenericEntity.setValue(name, null)` はキーを作らないので、`getValue(name) == null` は「未送信」と「画面でクリアした」を区別できない。判定は `entity.getValue(name)` が返す値だけで行い、`null` は「値なし」として扱う。

なお `BEFORE_VALIDATE` では `BEFORE_UPDATE_ENTITY` は常に `null`（`UPDATE_OPTION` は取れる）。GEM/mdcの画面保存は全項目を送るため、画面経由なら未送信の心配自体が無い。

**導出項目を入れるリスナ**（他Entityの値を写す等。SFの before-save フロー相当）は、検証ではなく値の生成なので作法が変わる。

| 事実 | 守り方 |
|---|---|
| 更新対象が明示されていると、指定に無い項目は保存されない | 導出した項目名を更新対象へ足す |
| **`getUpdateProperties()` が返すリストは変更できない** | `add` すると更新が原因の読み取れないHTTP 500で落ちる。新しいリストを作って `setUpdateProperties` で戻す |
| 送られていない項目は `entity` に入らない | **入力が揃っている導出項目だけ書き換える**。送られていない参照を「空」と誤認すると、既存の導出値を消す |
| 更新前値を `EntityManager.load` で補うとHTTP 500になる | 更新前値の再取得に頼らず、上の「揃っているものだけ」で組む |

画面保存は全項目を送るので、この作法を守れば画面経由の挙動はSFのフローと一致する。

---

## 6. 手書き分の置き場と契約

対象は入力規則由来のものだけではない。**参照関係の付随属性から生まれるリスナ・Validator（`property-mapping.md` §19）も、変換器が生成しない手書き分としてこの節の扱いに従う。**

機械変換分は変換器が自動生成する。機械変換できない分は宣言（`<SF API名>.json`）とGroovy本文（`<SF API名>/*.groovy`）に置く。**iPLAssの更新は全置換なので、手書き分もデプロイのたびにpayloadへ再度載せる必要がある**（載せなければ次回デプロイで消える）。**置き場は `work/manual-validations/` で、Git管理しない。正本は環境のメタデータそのもの**（宣言・Groovyはそのつどメタデータから取り出す作業用の写しであり、コミット対象ではない）。未変換・保留は保留台帳に出る。

**`eventListeners` キーの有無が契約**: 宣言ファイルに `eventListeners` キーが存在するか自体が契約になる。キーが**無ければ**、live の `eventListenerList` に一切触れない。キーが**あれば**（空配列でも）宣言が権威になり、liveのリスナは宣言どおりに丸ごと置き換わる。宣言ファイルが無ければ、liveの `validations` も無変更のままになる。

宣言ファイルを作るときは `eventListeners` キーを**書かないのを既定**とし、意図的に置き換える／消すときだけ書く。再適用が必要なときは、Groovyを推測で書き直さず live 定義の `script` の値をそのまま取り出す（冪等判定は `@class`＋`script` の完全一致なので、字面が変わると旧版が残り新版が足される）。

宣言の各エントリには由来のSF入力規則名を `sfRule`（単数）または `sfRules`（複数）で書く。実装はこの値を読み、保留台帳の「手書きで実装済み」表の対応列に出す（省略しても保存には影響しないが、台帳の由来列が空になる）。

投入前にはレポートの `changedProperties` / `eventListeners.removed` / `eventListeners.replaced` / `duplicated` を確認する。既存Entityへの後追いは live 起点のデルタ経路を使う（SFメタデータから作り直す全置換は live の手当てを踏み潰す）。
