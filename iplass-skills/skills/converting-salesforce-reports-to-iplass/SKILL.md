---
name: converting-salesforce-reports-to-iplass
description: SalesforceのPDF帳票(OPROARTSテンプレート＋Visualforceのボタン)をiPLAssへ移植するとき、JRXMLで帳票のレイアウトを作るとき、帳票の値をどう渡すかを決めるとき、生成したPDFをレコードの添付ファイルへ保存するとき、お手本のPDFからロゴ画像を取り出すとき、帳票が「このファイルを開くことができません」だけで失敗して原因が見えないときに使う。
---

# SFのPDF帳票のiPLAssへの移植

SFの帳票は外部サービス(OPROARTS)のテンプレートで組まれており、**レイアウトの定義は移行元のメタデータに含まれない**。`force-app/` 側に残るのはテンプレート名とボタンを呼ぶVisualforceだけなので、レイアウトはお手本のPDFを見て作り直すことになる。

移行元で見るのは次の2つ。それ以外に手がかりは無い。

| 見るもの | 分かること |
|---|---|
| `force-app/main/default/pages/` のVisualforce | 呼んでいるテンプレート名、対象オブジェクト、出力形式、ドキュメントをレコードへ添付するかどうかのオプション |
| `force-app/main/default/objects/` の項目メタデータ | 帳票に出す項目の型と、数式なら定義 |

**お手本のPDFは画面を見られる人に依頼して1件もらう。** レイアウトの一次情報はこれだけなので、無い状態で作り始めない。

本スキルは帳票(PDF)の生成だけを扱う。詳細画面へのボタンの追加は [converting-salesforce-screens-to-iplass](../converting-salesforce-screens-to-iplass/SKILL.md) §4.4、定義の取得・投入の作法は [iplass-definition-io](../iplass-definition-io/SKILL.md)、レコードの読み書きは [iplass-entity-crud-api](../iplass-entity-crud-api/SKILL.md) が定義位置。環境固有の値は [CLAUDE.md](../../../CLAUDE.md) の固有値表にある。

## 1. 構成 — 帳票Templateを使わない

iPLAssには帳票用のTemplate定義(`ReportTemplateDefinition`)があるが、**この構成は選ばない**。理由は定義APIで完結しないことにある。

| 帳票Templateを使うと | 影響 |
|---|---|
| Report Type / Format / DataSource属性名 / パラメータの対応付けが定義APIで投入できない | 帳票ごとに管理コンソールでの手作業が必要になる |
| 上の設定は定義APIの更新で**nullに上書きされて消える** | JRXMLを差し替えるだけの更新でも、そのたびに手作業をやり直すことになる |
| JRXMLの差し替えは管理コンソールのファイル選択でしか安全に行えない | レイアウトを詰める往復のたびに人の操作が入る |

代わりに、**JasperReportsをCommandから直接動かしてPDFのバイト列を作り、ストリームとして応答へ流す**。定義は4つで、すべて定義APIで投入できる。

| 定義 | 役割 |
|---|---|
| `GroovyTemplateDefinition` | **JRXMLの本文を持つ**。描画しないので中身はテンプレートとして評価されない。`contentType` は `text/xml; charset=utf-8` |
| `ScriptingCommandDefinition` | JRXMLを読み、データを組み、コンパイル・差し込み・PDF化し、リクエスト属性へ置く |
| `ActionMappingDefinition` | URLを作る。`result` に `StreamResultDefinition`(成功時)と `TemplateResultDefinition`(失敗時)を並べる |
| `GroovyTemplateDefinition` | 失敗時に原因を出すためのテキスト(§7) |

`StreamResultDefinition` のフィールドは次のとおり。値はリクエスト属性の**名前**を指す。

| フィールド | 内容 |
|---|---|
| `inputStreamAttributeName` | PDFのバイト列を入れた属性の名前(`byte[]` / `InputStream` を受け付ける) |
| `contentTypeAttributeName` | Content-Typeを入れた属性の名前 |
| `fileNameAttributeName` | ファイル名を入れた属性の名前 |
| `useContentDisposition` / `contentDispositionType` | `true` と `INLINE` でブラウザ内表示、`ATTACHMENT` でダウンロード |

`ActionMappingDefinition` は次の形になる。`result` は状態ごとに1つずつ並べる。

```json
{"@class":"org.iplass.mtp.web.actionmapping.definition.ActionMappingDefinition",
 "name":"<URLのパス>", "clientCacheMaxAge":-1,
 "commandConfig":{"@class":"org.iplass.mtp.command.definition.config.SingleCommandConfig",
   "transactionPropagation":"REQUIRED","rollbackWhenException":true,
   "throwExceptionIfSetRollbackOnly":false,"commandName":"<Commandの定義名>"},
 "result":[
  {"@class":"org.iplass.mtp.web.actionmapping.definition.result.StreamResultDefinition",
   "commandResultStatus":"SUCCESS",
   "inputStreamAttributeName":"<PDFを入れる属性名>",
   "contentTypeAttributeName":"<Content-Typeを入れる属性名>",
   "fileNameAttributeName":"<ファイル名を入れる属性名>",
   "useContentDisposition":true,"contentDispositionType":"INLINE","acceptRanges":false},
  {"@class":"org.iplass.mtp.web.actionmapping.definition.result.TemplateResultDefinition",
   "commandResultStatus":"ERROR","templateName":"<失敗用テンプレートの定義名>",
   "useContentDisposition":false,"contentDispositionType":"INLINE"}],
 "synchronizeOnSession":false,"needTrustedAuthenticate":false,
 "privileged":false,"parts":false,"publicAction":false}
```

Commandは `{"@class":"org.iplass.mtp.command.definition.ScriptingCommandDefinition", "name":..., "readOnly":false, "newInstancePerRequest":true, "script":<本文>}`、
テンプレート2つは `{"@class":"org.iplass.mtp.web.template.definition.GroovyTemplateDefinition", "name":..., "contentType":..., "localizedSourceList":[], "source":<本文>}` の形。

投入はいずれも定義APIのラッパーで行う(サブコマンドと照合の作法は [iplass-definition-io](../iplass-definition-io/SKILL.md) §5)。未存在なら `post`、既存なら `put`。

```
bash scripts/iplass/mtp-def.sh post /template/<JRXMLの定義名> <payload.json>
bash scripts/iplass/mtp-def.sh post /commandClass/<Commandの定義名> <payload.json>
bash scripts/iplass/mtp-def.sh put  /action/<Actionの定義名> <payload.json>
```

**本文が長い定義(スクリプト・JRXML)は、投入後に取得して正本のファイルと文字列で突き合わせる。** JRXMLは6万文字を超えるので、目視では欠落に気づけない。

定義名は**ローマ字**で付ける(定義パスはURLになるため)。

**参照先のテンプレートを作る前にActionを投入すると、`templateName` だけが黙って落ちる**(行き先の無い分岐になり、画面はアプリ共通のエラーになる)。テンプレートを先に作り、投入後に取得して `templateName` が残っているか照合する。

定義名は帳票ごとに揃える。この環境での実体は [CLAUDE.md](../../../CLAUDE.md) の固有値表にある。

| 定義 | 名前の付け方 |
|---|---|
| Action | `<帳票の置き場>/<帳票名>`。これがURLのパスになる |
| Command | `<帳票の置き場>/<帳票名>ReportCommand` |
| JRXML | `<帳票の置き場>/<帳票名>Jrxml` |
| 失敗用テンプレート | `<帳票の置き場>/<帳票名>Error` |

Command側でPDFを作る流れは次のとおり。クラス名は `iplass-dev` プラグインのスキルで確かめる。

```groovy
def design = net.sf.jasperreports.engine.xml.JRXmlLoader.load(
        new java.io.ByteArrayInputStream(jrxml.getBytes('UTF-8')))
def report = net.sf.jasperreports.engine.JasperCompileManager.compileReport(design)
def print = net.sf.jasperreports.engine.JasperFillManager.fillReport(
        report, new java.util.HashMap(), dataSource)
java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream()
net.sf.jasperreports.engine.JasperExportManager.exportReportToPdfStream(print, bos)
```

JRXMLをテンプレート定義から読むときは、`DefinitionManager` に `get(Class, String)` は無い。`getTypedDefinitionManager(<定義クラス>)` を取ってから `get(<定義名>)` を呼び、`getSource()` で本文を取る。

## 2. JRXMLは7系の書き方で投入する

サーバのJasperReportsの版は、Command内から `JasperCompileManager.class.getPackage().getImplementationVersion()` で読める。**7系は6系のJRXMLを読めない。** 読み込みは `Unable to load report` の1行で失敗し、**内容のどこが悪いのかは出ない**。

6系と7系の違いは次の5点。

| 事項 | 6系 | 7系 |
|---|---|---|
| ルート要素の名前空間 | `xmlns` と `xsi:schemaLocation` を付ける | **付けてはいけない**。読み込み側が「ローカル名が `jasperReport` かつ名前空間が空」を帳票と判定する条件にしているため、付けると帳票として認識されない |
| セクションの中の `band` | `<pageHeader><band height="..">` | セクション自身がbandになる(`<pageHeader height="..">`)。ただし `detail` は複数bandを持てるので `band` が残る |
| 要素 | `<staticText>` / `<textField>` 等のタグ | `<element kind="staticText">`。`reportElement` / `textElement` / `font` / `graphicElement` は無くなり、属性は element へ平らに移る |
| 真偽・別名の属性 | `isBlankWhenNull` / `textAlignment` / `isStretchWithOverflow` | `blankWhenNull` / `hTextAlign`・`vTextAlign` / `textAdjust="StretchHeight"` |
| 式を持つ子要素 | `textFieldExpression` / `imageExpression` | どちらも `expression` |

日本語PDFに必要な `pdfFontName` / `pdfEncoding` / `pdfEmbedded` は7系にも残っている。一方で画像の `hAlign` / `vAlign` は削除されたので付けない。

**`fontName` はJVMの論理フォント名である。** ハイフンを入れた綴りは存在せず、差し込みの時点で「フォントが無い」という例外になる。

**要素の文書順は変えてはいけない。** 描画順がそのまま重なり順になるため、順序を崩すと背景の矩形が文字の上に乗り、**その文字だけが消えたように見える**。種類ごとにまとめて出力する変換を書くとこれが起きる。

正本は読みやすい6系の書き方で持ち、投入時に7系へ変換する。変換の実体は [scripts/sf-to-iplass/report/README.md](../../../scripts/sf-to-iplass/report/README.md) が定義位置。

## 3. 値の渡し方 — データソースに寄せる

**Commandがリクエスト属性へ置いた値は、JRXMLのパラメータ(`$P{}`)へ自動では渡らない。** 渡すには管理コンソールで属性名とパラメータ名を1件ずつ対応付ける必要があり、その設定は§1のとおり定義APIで投入できない。

そこで**ヘッダ項目もすべてデータソース経由にする**。JRXMLはヘッダも明細も `$F{}` で読む。

| 事項 | 決め |
|---|---|
| データソース | Commandが `Map` のリストを作り、`JRMapCollectionDataSource` でラップして属性へ置く。属性名はActionのStream設定とは別に、JRXMLのfield名と**キー名を一致させる** |
| ヘッダの値 | **明細の各行に同じ値を載せる**。ページヘッダ・フッタの `$F{}` はその時点のレコードから読まれるので、全行に同じ値が入っていれば1つに見える |
| 明細が0件のとき | **ヘッダの値だけを持つ行を1つ置く**。0件だと `$F{}` が読めず、宛先も金額も空の帳票になる |
| キー名の衝突 | ヘッダと明細で同じ名前を使うと、行にマージした時点で明細側が勝つ(合計と明細金額の両方を `total` にすると合計が消える)。**明細側に `row` を冠して分ける**(`rowTotal`)。ヘッダ側は帳票の見出しと同じ名前にしておく |
| 文字の整形 | 金額・日付・選択肢の表示名は**すべてCommandで文字列にしてから渡す**。JRXMLに整形を書かない |

**JRXMLにiPLAssの型を書かない。** 選択肢型を判定するような式を書くと、帳票のコンパイル経路でクラスが解決できずに落ちる。整形をCommandへ寄せる理由はここにもある。

## 4. 手元で同じ版を動かして確かめる

帳票は実行時に落ちても、応答のContent-Typeが `application/pdf` のままなので、ブラウザには**「このファイルを開くことができません」しか出ない**。サーバのログが取れない環境では原因が読めないため、**同じ版のJasperReportsを手元に置いて同じ処理を走らせる**。

| 手順 | 内容 |
|---|---|
| 1 | サーバの版を確認用の分岐から読む(§7)。**そのためにCommandと失敗用テンプレートを先に投入する**(この2つはレイアウトが未確定でも投入できる。§8の順序がこうなっている理由) |
| 2 | 同じ版のjarを取得する。7系はJRXMLの読み込みにJacksonを使うので、jacksonとXMLの実装、PDF出力の別モジュールも要る。jarの取得先と一覧は [scripts/sf-to-iplass/report/README.md](../../../scripts/sf-to-iplass/report/README.md) |
| 3 | 読み込み・コンパイル・差し込み・PDF出力の4段を分けて出す。どの段で落ちたかが分かる形にする |
| 4 | 1ページ目をPNGにして見た目を確認する。お手本と並べて突き合わせる |

**明細の件数を変えて両方通す。** 0件と1件以上ではJasperの通る経路が違う(`whenNoDataType` の分岐・`detail`・`lastPageFooter`)ため、0件だけで確かめると本番で初めて落ちる。

**手元の道具には、本番と同じ形でデータを渡す。** ヘッダをデータソースに寄せた構成(§3)で明細の項目だけを渡すと、宛先や金額が空のPDFが出来上がるのに成功として見える。JRXMLのfield一覧から全項目を埋める形にしておく。

**読み込みの失敗は、読み込み側の実装を直接呼ぶと理由が出る。** 7系の読み込み口は理由を伏せて `Unable to load report` だけを投げるため、Jacksonを使う実装クラスを呼べば「未知の属性」「未知の要素」まで分かる。

## 5. ロゴ・画像

移行元にロゴの素材は無い。**お手本のPDFから取り出す。**

| 事項 | 決め |
|---|---|
| 取り出し | PDFの中の画像オブジェクトを取り出してPNGにする。道具は [scripts/sf-to-iplass/report/README.md](../../../scripts/sf-to-iplass/report/README.md) |
| JRXMLへの持たせ方 | **base64で式の中に埋める**(`ByteArrayInputStream` に `Base64` で復号したバイト列を渡す)。外部ファイルのパスにすると帳票サーバ側にファイルを置くことになり、定義だけで完結しなくなる |
| 置き場所 | 社名の文字を含むロゴなら、**社名の静的テキストごと画像に置き換える**。枠の位置と大きさは変えない |
| 何度でも作れるようにする | 埋め込みを外すと元の文字へ戻る形にする。外して入れ直したときに字下げだけが差分になるので、**挿入する要素の字下げは置き換える要素と同じにする** |

## 6. 生成したPDFをレコードへ保存する

SFのテンプレート呼び出しには「作成したドキュメントをオブジェクトに添付する」オプションがある。iPLAss側では**添付ファイル項目(多値のBinary)へ保存する**ことで同じ扱いになる。

```groovy
def ref = em.createBinaryReference(<ファイル名>, 'application/pdf',
        new java.io.ByteArrayInputStream(pdf))
def upd = new org.iplass.mtp.entity.GenericEntity(<Entity定義名>)
upd.setOid(<oid>); upd.setVersion(<version>)
upd.setValue(<項目名>, <BinaryReferenceの配列>)
def opt = new org.iplass.mtp.entity.UpdateOption(false)
opt.setUpdateProperties(<項目名>)
em.update(upd, opt)
```

| 事項 | 決め |
|---|---|
| 更新の範囲 | `UpdateOption` で**添付ファイル項目だけに絞る**。他の項目を巻き込まない |
| 履歴として残すか | 出力のたびに積むか、同名を置き換えるかを**先に決める**。積むなら**ファイル名に出力日時を入れる**(名前順がそのまま出力順になり、どれが最新かが名前で分かる) |
| 多重度の上限 | 添付ファイル項目は全Entity共通の定型プロパティで、多重度の上限がある(値は [converting-salesforce-to-iplass-entity/references/property-mapping.md](../converting-salesforce-to-iplass-entity/references/property-mapping.md) §18 が定義位置)。超えると更新が通らないので、**自分が出力したものだけを名前の接頭辞で判別して古い順に落とす**。残す件数は上限より小さく取り、人が付けた添付の枠を残す。人が付けた添付は触らない。落とした件数は呼び出し側へ返し、黙って履歴が消えないようにする |
| 接頭辞とファイル名 | `<帳票の名前>_<レコードの名前>_<出力日時>.pdf` の形にする。接頭辞(`<帳票の名前>_`)で自分の出力を判別し、出力日時(`yyyyMMdd-HHmmss`)で新旧を並べる |
| 失敗の扱い | 保存の失敗を握り潰さない。PDFだけ表示されて添付が無い状態は、気づけないまま運用に入る |

## 7. 症状から原因へ

帳票の失敗はブラウザ側の見え方が同じになるため、**まず「どこで落ちたか」を分ける**。Commandの本体をクロージャに入れて例外を捕まえ、`ActionMapping` の失敗用の分岐からテキストで出す経路を最初に作る。作っておかないと、以降のすべての調査が推測になる。

確認用の分岐は3つ置く。いずれもリクエストのパラメータで切り替え、失敗用の分岐からテキストを返す。

| パラメータ | 出すもの | 何が分かるか |
|---|---|---|
| `probe` | スクリプトに埋めた版の文字列(`<Command名> v3` のような形) | 投入した版が実行に反映されているか([iplass-definition-io](../iplass-definition-io/SKILL.md) §4) |
| `diag` | JasperReportsの版とjarの位置、JRXMLの長さと先頭 | 版の違い・JRXMLの取り出しの成否 |
| `attach` | 添付保存だけを行い、保存後に読み直した件数と名前 | 保存処理そのものの成否と、応答を流す側との切り分け |

**分岐はCommandの入口に置く**(データを組む前)。処理の途中に置くと、そこへ辿り着く前に落ちて何も出ない。

| 症状 | 原因 |
|---|---|
| ブラウザに「このファイルを開くことができません」だけが出る | 帳票の生成が失敗している。Content-Typeは先に確定するため、本文が壊れていてもPDFとして扱われる |
| `Unable to load report` で読み込めない | JRXMLが7系の書き方になっていない(§2)。まず**ルート要素の名前空間**を疑う |
| 差し込みで「フォントが無い」という例外になる | `fontName` がJVMの論理フォント名になっていない(§2) |
| 表題や備考の文字だけが出ない | 要素の文書順が崩れ、背景の矩形が文字の上に乗っている(§2) |
| 宛先・金額などヘッダの値だけが空になる | パラメータに値が渡っていない。データソースへ寄せる(§3)。**レコードに値が入っていない**と誤診しやすいので、先にレコードを読んで値の有無を確かめる |
| 合計だけが明細の金額に化ける | ヘッダと明細でキー名が衝突している(§3) |
| ブラウザにサーバのエラー画面(アプリのものではないもの)が出る | Commandを抜けたあとで落ちている。応答を流す処理か、レコード更新のコミットを疑う。部分実行の分岐で切り分ける |
| 定義は更新できているのに挙動が変わらない | [iplass-definition-io](../iplass-definition-io/SKILL.md) §4。**定義名を変えて作り直す**のが確実 |

## 8. 移行の順序

| 手順 | 内容 |
|---|---|
| 1 | お手本のPDFを1件もらう。項目の対応表(帳票のどの位置がどの項目か)を先に作る |
| 2 | 失敗を読める形にする(§7の3つの分岐と、失敗用のテキスト出力) |
| 3 | サーバの版を読み、手元に同じ版を用意する(§4) |
| 4 | JRXMLを組み、手元で明細0件と複数件を通す |
| 5 | Command・JRXML・Action・失敗用テンプレートを投入し、投入後に**取得して往復一致を照合する** |
| 6 | 対応表の項目すべてに値が入るサンプルデータを用意して、実画面で突き合わせる。値が空の項目は**レコードが空なのか渡っていないのか**を分けて確かめる |
| 7 | 添付保存(§6)を足す |

**対象Entityの項目が実在するかは、Entity定義を取得して照合する。** 帳票側で名前を間違えても空欄になるだけで、エラーにはならない。

帳票1本で足すものは次の5つ。置き場は [scripts/sf-to-iplass/report/README.md](../../../scripts/sf-to-iplass/report/README.md)。

| 足すもの | 内容 |
|---|---|
| JRXMLの正本 | 6系の書き方で書く |
| Commandの正本 | データの組み立てと整形。PDF化と添付保存は既にある帳票から写す |
| JRXMLの生成の入口 | 帳票ごとに1つ。ロゴの有無を引数で渡す |
| テスト | 変換とロゴ埋め込みの往復。既にある帳票のテストを正本の差し替えで写す |
| 定義4つ | §1 |
