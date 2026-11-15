---
name: converting-salesforce-layout-to-iplass-view
description: Salesforceのページレイアウト(layout)からiPLAssのmdc詳細View(detailView)・検索View(searchView)を作るとき、SFのセクション・behavior(Required/Readonly)・ハイライトパネル/dynamicHighlights・関連リスト(relatedLists)・添付ファイルをiPLAssのセクションと項目editorへ対応させるとき、SFの参照フィルタ(lookupFilter)を選択フィルター(SELECTFILTER)の検索条件へ移すとき、関連リスト用に親Entityへ被参照Reference(mappedBy)を足すとき、Viewとセットでサイドメニュー(EntityItemとSideMenuTree)を作るとき、Viewを投入したのに画面がエラーになる・定義が読めなくなったときに使う。
---

# Salesforceページレイアウト → iPLAss 詳細View 変換

mdc Viewの一般的なJSON形状・クラス名の一次情報は `iplass-dev:iplass-metadata` が担う。本スキルは、SFのレイアウトをmdc詳細Viewへ対応させる判断と、この環境で**画面が動く形**にするための要点を扱う。

定義の取得・投入・照合の作法は `iplass-definition-io` が定義位置。ツールのCLI仕様（オプション・出力ファイル）は `scripts/sf-to-iplass/README.md` が定義位置。環境固有の値は [CLAUDE.md](../../../CLAUDE.md) の固有値表を参照する。

## 1. 変換の流れ

到達点は **Entity（被参照Reference）とViewとサイドメニューのデプロイ・照合、および画面が開くことの確認まで**。画面の目視はユーザーが行う（§13）。

前提: 対象Entityがデプロイ済みであること。View変換器は現行Viewの取得結果と対象Entity定義を土台にするが、**View定義そのものが無いEntityにも使える**。取得が `definition` を返さない場合、Viewの器（`MdcEntityViewControlDefinition`）と詳細Viewのヘッダを既定値で組む（形は稼働中の手本に揃える。定義位置は `scripts/sf-to-iplass/view/lib/build-control.js`）。

liveから引けるものが減るほど手本が無くなるので、**Viewが無いEntityでは項目のeditorも型から生成する**ことになる（§3）。手本の無い型はそこで除外に落ちる。

**着手前に2点をユーザーに確認する**。どちらも推測すると出力が丸ごと変わる。

| 確認 | 理由 |
|---|---|
| どのレイアウトを参照するか | 1つのオブジェクトに複数のページレイアウトがある。セクション構成も項目も別物になる |
| Viewの名前 | 定義パスの末尾セグメント。**指定が無ければ `DEFAULT`**。変換器は取得したlive定義の `name` / `viewName` をそのまま持ち越すので、取得するパスがそのまま反映先になる |

1. **live取得** — 対象View・対象Entity・関連リストの参照先（子）Entity定義
2. **Entity側** — 関連リスト用の被参照Referenceを親Entityへ足して投入する（§5）
3. **View側** — レイアウトから詳細Viewのセクションを組み（§2〜§4・§6〜§7・§9）、続けて検索Viewを組む（§8）
4. **サイドメニュー側** — EntityItemを作り、SideMenuTreeへ配置する（§10）
5. **投入** — Entity → View → サイドメニュー の順（§11）
6. **照合と画面確認**（§11・§13）

想定外の型・セクション種別に出会ったら、その都度ユーザーに報告して個別に対処する。個々の判断を機械的なルールで先取りしない。

## 2. セクションの並びと種別

詳細Viewの並びは次の順に固定する。SFのレイアウトは関連リストと添付をセクションとして持たないため、この3種はレイアウトの記述順ではなく本表の位置に置く。

| 位置 | セクション | 由来 |
|---|---|---|
| 最上部 | 主要情報（1つ） | `dynamicHighlights` またはCompactLayout（§4） |
| 中間 | SFのセクション（記述順。システム項目のセクションを除く） | レイアウトの `layoutSections` |
| その下 | 関連リスト（1関連リスト＝1セクション） | レイアウトの `relatedLists`（§5・§6） |
| その下 | 添付ファイル（1つ） | 添付用の関連リスト（§7） |
| 最下部 | システム情報（1つ） | SFのシステム項目セクション |

**セクションの表示ラベル**はSFのラベルを使う。ただし `objectTranslations` には項目の翻訳しか無く**セクションの翻訳は存在しない**ため、SF標準セクション名（英語のまま来る）は固定の対応表で日本語化する。対応表に無い英語ラベルは**訳さずにレポートで報告する**（推測で訳さない）。対応表は `scripts/sf-to-iplass/view/lib/section-label.js` が定義位置。

セクションの `@class` は `org.iplass.mtp.mdc.view.entityview.detail.definition.element.section.<種別>`。

| 種別 | 用途 |
|---|---|
| `MdcDetailDefaultSection` | 通常のセクション（`type` は `DEFAULT_SECTION`） |
| `MdcDetailMassReferenceSection` | 大量データ参照セクション。関連リストに使う（`type` は `MASS_REFERENCE_SECTION`） |
| `MdcDetailScriptSection` / `MdcDetailTemplateSection` / `MdcDetailCustomSection` / `MdcDetailVersionSection` / `MdcDetailAuditLogSection` / `MdcDetailWorkflowHistorySection` | 本変換では作らない。**liveにあれば持ち越す**（下記） |

**作らない種別のセクションは、liveから位置ごと持ち越す。作らないことと消すことは別である。** 全置換なので、持ち越さないと画面に載っていたものが消える。カスタム画面をテンプレートセクションで埋め込んでいる場合（`converting-salesforce-screens-to-iplass`）がこれに当たり、埋め込みとそこへ値を渡すスクリプトセクションが対象になる。

位置は「生成分の何番目の後ろにいたか」で戻す。末尾・途中・先頭のいずれでも保たれ、生成分が減っても落ちない。持ち越した件数と種別はレポートに出す。規則の定義位置は `scripts/sf-to-iplass/view/lib/preserve-sections.js`。

**`@class` はセクション・要素・editorのすべてに必要**。ただし大量データ参照セクションの表示列（`properties` の各要素）だけは `@class` を持たない（§6）。

セクションの表示ラベルは `displayLabel` と `localizedDisplayLabelList`（`ja` / `en`）の両方に入れる。

**セクションの `collapsible` / `expandable` / `showLink` は `true` にする。** 稼働中のViewは全セクションが
`true` で、`false` にすると**定義の投入・取得は通るのに詳細画面が空になる**（セクションも項目も出ない）。
手本とキーの集合が一致していても露出しないので、値まで揃える（§12）。

## 3. 項目の対応（behavior・editor）

要素の `@class` は `...detail.definition.element.property.MdcDetailProperty`、`type` は `PROPERTY`、対象項目は `propertyName` で指す。

**項目名の読み替えと分解**: レイアウトはSFのAPI名で項目を指すが、Entity変換で**名前が変わる項目**と**複数プロパティへ分解される項目**がある。素の名前で引くと「プロパティが存在しない」として落ちるので、読み替え表を通す。対応表は `scripts/sf-to-iplass/view/lib/field-alias.js` が定義位置。

| SFの項目 | iPLAss |
|---|---|
| SFのシステム項目（作成者・最終更新者・作成日・最終更新日） | iPLAssの標準プロパティ（`createBy` / `updateBy` / `createDate` / `updateDate`）。Entity変換で再宣言しないためSFのAPI名では引けない。**作成者・最終更新者は者と日の2プロパティへ分解する**（後述） |
| 複合住所項目 `<接頭辞>Address` | 分解後の5プロパティ（`<接頭辞>Country` / `PostalCode` / `State` / `City` / `Street`）。**SFの住所入力と同じ並び**で置く。町名・番地はSF側がTextAreaなので `displayType` を `TEXTAREA` にするが、分解後のプロパティにはSFの項目定義が無く型から導けないので、この指定は読み替え表側に持つ |

接頭辞は空文字の場合もある（オブジェクトによって `Address` そのものが複合項目名になる）。カスタム項目は `__c` で終わるのでこの判定には掛からない。

**作成者・最終更新者は日付とセットで置く**。SFはレイアウトに `CreatedById` / `LastModifiedById` の1セルしか持たないが、画面ではそのセルに**ユーザー名と日時の両方**を描く。iPLAssでは別プロパティなので、者→日の順に2枠使って対で置く。

| SFの項目 | iPLAssの並び |
|---|---|
| `CreatedById` | `createBy` → `createDate` |
| `LastModifiedById` | `updateBy` → `updateDate` |

**者はセクション内の奇数番目に置く**。者を積む時点で要素数が奇数なら（＝者が偶数番目に来るなら）直前に空白を1つ入れて奇数番目へ送る。**列数は見ない**。2列セクションでは者が左列・日が右列となり、SFが1セルで描くのと同じ行に収まる。ペアは常に2枠使うので前後で要素数の偶奇は変わらず、行末の詰め物とも衝突しない。

**この4項目の並びだけSFのレイアウトと一致しなくなる**。SFが1セルで描くものを2枠使うため原理的に一致させられないので、例外として扱う。1列セクションでも規則どおり空白が入り、3列以上では者が最終列に来て日が次の行の先頭へ回ることがある。

日（`createDate` / `updateDate`）は**`displayType` を `LABEL` 固定**にする。システムが持つ値で入力できないため、SFの `behavior` を見ない（`Edit` や未指定のレイアウトがあり、型の既定に任せると日時の入力欄が出る）。

`CreatedDate` / `LastModifiedDate` が**単独でレイアウトに置かれているオブジェクトもある**。読み替え自体は1対1のまま残し、**同じセクションに者もあるときはペア側を正として単独セルを空白へ置き換えて報告する**（者と日を離して2回出さない）。判定はセクションを組む前に全セルを走査して行い、レイアウト上の記述順に依存させない。セクションをまたぐ重複は主要情報セクションと同じく許容する。

**項目の並び**: SFのセクションは `layoutColumns`（列）ごとに項目を持ち、**列の同じ位置を同じ行に描く**。iPLAssの要素列は行方向に流れるので、**列を行単位に組み替える**（左列[0] → 右列[0] → 左列[1] → 右列[1] → …）。列を順に連結すると画面の並びがSFと一致しない。列数はSFのレイアウトに従う（1列のセクションはそのままの順）。

**空白**: SFの空白スペース（`emptySpace`）は `MdcDetailSpaceElement`（`type` は `SPACE_ELEMENT`、`@class` は `...detail.definition.element.custom.MdcDetailSpaceElement`）で表す。空白を置く箇所は3つある。

| 箇所 | 理由 |
|---|---|
| SFの `emptySpace` | 見た目をSFに合わせる |
| 列の長さが違うときの短い側 | 行の対応を保つ |
| 除外した項目の位置 | 入れないと以降の行が1つずつずれる |
| 作成者・最終更新者の直前 | 者を奇数番目へ送り、者と日を同じ行に収める（前述） |
| 者とセットで出す日が単独でも置かれていた位置 | ペア側を正とし、単独セルの位置を保つ（前述） |

末尾の空白は行の対応に関与しないので落とす。**要素数を照合するときは項目（`PROPERTY`）と空白（`SPACE_ELEMENT`）を分けて数える**（合算するとSF側の項目数と合わない）。

**SFの `behavior` の対応**:

| SFの `behavior` | iPLAss |
|---|---|
| `Required` | 要素の `requiredDisplayType` を `DISPLAY` にする |
| `Readonly` | editorの `displayType` を `LABEL` にする |
| `Edit` | 既定のまま |

`requiredDisplayType` は**画面上の必須表現**であり、Entity側の `NotNullValidation`（DB登録時の制約）とは別物。レイアウト由来の必須をEntity側の制約へ持ち込まない。逆に、Entity側が `NotNullValidation` を持つことを理由に `requiredDisplayType` を付けることもしない。

**editorの作り方**: 現行Viewに同じ項目の要素があれば、それを**そのまま複製して使う**（画面での見せ方の手当てが既に入っているため、作り直さない）。現行Viewに無い項目だけEntity定義の型からeditorを組む。editorの `@class` は `...definition.editor.detail.MdcDetail<型>PropertyEditor`。

**手本のeditorの型がEntityのプロパティの型と食い違えば、型から作り直す。** liveは前回の出力（または画面の自動生成）なので、Entity側で型を変えても古いeditorが残る。**定義の投入・取得は通るのに画面に値が出ない**という形でしか表に出ないため、複製する前に型を突き合わせる。プロパティ型とeditorの型の対応は下の表のとおりで、`DATETIME` だけ名前が一致しない（editorは `TIMESTAMP`）。

| プロパティの型 | editorの `type` |
|---|---|
| `DATETIME` | `TIMESTAMP` |
| ユーザーのoidを持つプロパティ（型は `STRING`） | `USER`（後述） |
| 上記以外 | 同名 |

数式（`EXPRESSION`）がこれで最も壊れる。文字列用のeditorが残ると戻り型の入れ子を持たないので値が描けない（後述）。型からeditorを作れない型（`AUTONUMBER` 等、手本しか無い型）は手本をそのまま残す。規則の定義位置は `scripts/sf-to-iplass/view/lib/resolve-element.js`。

**`displayType` の既定**: 型ごとに次の値へ揃える。**現行Viewから複製した要素も揃える**（画面の自動生成が付けた値をそのまま残さない）。表に無い型は現行Viewの値を尊重する。この表は**検索条件のeditorにも使う**（§8）。

| editorの `type` | `displayType` |
|---|---|
| `BOOLEAN` | `CHECKBOX` |
| `SELECT` | `SELECT`（多値でも同じ） |
| `REFERENCE` | `LINK` |
| `BINARY` | `BINARY` |
| `USER` | `LABEL` |

**SFの型で決まる入力欄の見せ方**: 上の表はeditorの型だけで決まる既定だが、**文字列系
（`STRING` / `LONGTEXT`）は型だけでは1行か複数行かが決まらない**。SFの項目の型から決める。

| SFの型 | `displayType` |
|---|---|
| `TextArea` / `LongTextArea` | `TEXTAREA` |
| `Html` | `RICHTEXT` |
| `Text` / `Email` / `Phone` / `Url` / `EncryptedText` | `TEXT` |

**単一行へ戻す側も表に持つ**。liveは前回の出力なので、戻す分岐が無いとSF側でTextAreaを
やめても `TEXTAREA` が残り続ける（ヒント・初期値・選択フィルターと同じ理由）。

適用は**editorの型が `STRING` / `LONGTEXT` のときだけ**。SFの型が `TextArea` 系なのに
editorが別の型なら、当てずにレポートで報告する（型の対応が食い違っているので黙って通さない）。
SFの型が表に無いもの（空Picklistや未移行の参照がStringになった項目）も、**editorの型が
`STRING` / `LONGTEXT` のときだけ**liveの値を維持して報告する。
**SFの型そのものが無い標準項目**（`Fax` / `Site` / `Description` 等。項目メタデータに `<type>` が無い）は
桁数の `<length>` と同じ事情で複数行かどうかを判断できないため、displayTypeは変えずliveの値を維持する。
ただし `Description` のような本来複数行の項目もあるため、**上のskipとは別枠で**件数と項目名をレポートに出す
（桁数の欠落と違い、人が見て複数行と判断できる余地があるため報告する価値がある）。

`Readonly` の `LABEL` はこの規則より優先する。分解した住所項目の `TEXTAREA`（`Street`）は
SF側に項目定義が無く型から導けないので読み替え表側の指定で決まり、この規則より先に効く。

**mdcのeditorが取れる `displayType` は系統ごとに違う。** GEM系（`org.iplass.mtp.view.generic.editor`）の
カタログに載っている値をmdc系へ流用してはいけない。無効な列挙値を送ると投入が500で落ちるか、
サーバが既定値へ丸めて黙って消える。手本の無い値を使う前に、別View名で1件作って取得し直して
受理を確かめる（§13）。

**ユーザーのoidを持つプロパティ**（`createBy` / `updateBy` / `lockedBy`）は `MdcDetailUserPropertyEditor`（`type` は `USER`）を使う。型は `STRING` なので**型ではなくプロパティ名で判定する**。文字列用のeditorだとoidの文字列がそのまま画面に出る。**現行Viewの手本が文字列用editorになっていても差し替える**（画面の自動生成は型で判断するため文字列用が入っている）。

参照先が認証ユーザーEntityの `REFERENCE` プロパティは、これに該当せず通常のReference editorで扱う（SFの所有者項目はこちらになる）。

`Readonly` の `LABEL` はこの既定より優先する。逆に、SF側で `Readonly` が外れた項目は既定へ戻す（現行Viewが前回の出力である以上、`LABEL` を消す分岐が無いと残り続ける）。既定が対応表に無い型では戻せないので、その事実をレポートで報告する。対応表は `scripts/sf-to-iplass/view/lib/build-editor.js` が定義位置。

editorを組めない型に当たったら、**推測でeditorを作らず、その項目を除外してレポートに理由を残す**。除外はレポートで報告する（黙って落とさない）。

**数式（`EXPRESSION`）のeditorは戻り型のeditorを `editor` キーに入れ子で持つ**。数式のeditor自体は値の見せ方を持たないので、入れ子が無いと画面が値を描けない。戻り型はEntity定義の `resultType`（`converting-salesforce-to-iplass-entity/references/property-mapping.md` §14 が定義位置）。

| 項目 | 値 |
|---|---|
| 外側 | `Mdc<系統>ExpressionPropertyEditor`（`type` は `EXPRESSION`、`displayType` は `LABEL`） |
| 入れ子 | `resultType` に対応する同じ系統のeditor |
| 入れ子の `displayType` | 詳細Viewでは `LABEL`（数式は読み取り専用）。検索条件ではその型の既定 |
| 入れ子が日時のとき | **入れ子側に書式を入れる**（外側は `type` が `EXPRESSION` なので書式のキーが効かない） |

この構造は詳細・検索条件・検索結果の3系統で同じで、入れ子を作る関数だけが変わる。`resultType` が無い、または対応するeditorの手本が無いときは、**入れ子なしで送らず、その項目・列・条件を落としてレポートに理由を残す**（詳細Viewの項目だけは行がずれるので残し、理由を報告する）。

**文字数制限・日時の書式・ヒント・初期値**: この4つは定義上の位置も出所も別で、まとめて「項目の設定」として扱うと出所を取り違える。

| 設定 | 定義上の位置 | 出所 |
|---|---|---|
| 文字数制限 | editorの `maxLength` | 対象Entity定義の `LengthValidation` の `max`、数値は `RangeValidation` の境界値 |
| 日時の書式 | editorの `dateTimeFormat`（`{ "format": "…" }` の入れ子） | editorの `type` ごとの固定表（SFの書式は見ない） |
| ヒント | **要素直下**の `hint`（editorの中ではない） | SF項目の `inlineHelpText` |
| 初期値 | editorの `defaultValueTemplate` | SF項目の `defaultValue`、無ければ選択肢側の既定値 |

`maxLength` を持つeditorは `STRING` / `LONGTEXT` / `INTEGER` / `DECIMAL` だけで、他の型のeditorにこのキーは無い。**現行の要素がそのキーを持つかどうかで判定する**（型名で分岐すると、まだ採取していない型で誤る）。`hint` は要素側のキーなのでeditorの型に関わらず載る。

文字数制限にSFの `<length>` を使わない。複合項目を分解したプロパティのように**SF側に項目定義が存在しないもの**があり、そこはEntity定義にしか制限が無い。出所をEntity定義に寄せれば、画面で入れられる長さと保存時に弾かれる長さも1つの値から決まる。

**数値の桁数制限はEntity側では `RangeValidation` の境界値で表される**（`converting-salesforce-to-iplass-entity/references/property-mapping.md` §5）ので、文字列とは別のValidationから引く。editorの `maxLength` は**最大文字数**なので、桁数そのものではなく**符号と小数点を含めた文字数**に直す（境界値の文字列の長さがそのまま使える）。`min` と `max` で長さが違うときは**広い側に合わせる**。狭い側に合わせると、範囲内の有効な値が画面から打てなくなる。境界値が素の十進表記でない場合（指数表記など）は文字数が桁数にならないので使わない。

`LengthValidation` も `RangeValidation` も無い項目は `0` のまま残し、**editorは持てるのにEntity側に制限が無い項目をレポートで報告する**（Entity側に足すかどうかの判断がそこで見える）。数式・集計の読み取り専用項目はEntity変換の時点で桁数を持たないため、ここに並ぶ。

**日時の書式は全件に指定する**。指定が無いとテナントの既定書式で出るため、Date型とDateTime型のプロパティは表示専用（`LABEL`）のものも含めて漏れなく入れる。書式の対応表のキーは**editorの `type`**であり、Entityの型名ではない（DateTime型プロパティのeditorは `type` が `TIMESTAMP`）。

| editorの `type` | `format` |
|---|---|
| `DATE` | `yyyy/MM/dd` |
| `TIMESTAMP` | `yyyy/MM/dd HH:mm` |

SFの項目にも書式の指定があるが**参照しない**。SFの表示書式はロケール設定に紐づき項目メタデータに書式文字列として現れないので、移せる情報が無い。書式は移行先の表記として固定する。

このキーは**参照セクションの表示列の検索結果editorにも同じ名前で存在する**（§6）ので、詳細セクションの要素と表示列の両方に入れる。片方だけだと同じ項目が画面の場所によって違う書式で出る。日時系なのに対応表に無いeditorの型（`TIME` 等）は、書式を入れずレポートで報告する（推測で書式を決めない）。

SFのXMLは改行をCRLFで持つので、ヒントは**定義にCRを残さない**。

**SFの `defaultValue` は数式言語**であり、そのまま `defaultValueTemplate` へ移すと画面に数式の文字列が出る。リテラルだけを取り出す。

| SFの値 | 変換 |
|---|---|
| 二重引用符で囲まれた文字列 | 引用符を外した中身 |
| 数値リテラル | そのまま |
| `true` / `false` | そのまま |
| 関数・項目参照・`$` 変数 | 移さずレポートで報告 |

初期値には出所がもう1つある。**選択肢側の既定値**（項目が自前で持つ選択肢定義、またはグローバル選択肢の `default`）で、こちらは数式ではなく値そのものが入っている。項目の `defaultValue` が無いときの出所として使う。SFの画面では項目側の指定と同じく新規作成時の初期値になるが、レイアウトからも項目の `defaultValue` からも見えないので、選択肢定義まで辿らないと落ちる。

Booleanの `false` は書かない。未設定はオフと同じであり、`defaultValueTemplate` は文字列テンプレートなので、`false` という文字列の解釈のされ方によっては逆の結果になり得る。同じ理由で `$` や `<%` を含む値も移さず報告する。

SELECTは変換後の値が**Entityの選択肢に存在するか照合する**。SFの選択肢値とEntityの `selectValueList` がずれていると、初期値だけが選択肢に無い値になる。

ヒントと初期値は**SF側の指定が消えたら定義からも消す**。現行Viewが前回の出力である以上、消す分岐が無いと残り続ける（`Readonly` の `LABEL` と同じ理由）。

主要情報セクションは表示専用（§4）なので、入力の設定であるヒントと初期値は載せず、文字数制限と日時の書式だけ入れる。ここで**現行Viewから複製した値をそのまま残してはいけない**。同じプロパティの要素が他のセクションにもあり、複製元の値を引き継ぐと**再変換のたびに差分が出続ける**（§11の冪等性が崩れる）。

この4つのうち検索Viewに入れるのは日時の書式だけ。検索用のeditorは文字数制限と初期値のキーを持たず、ヒントは入れない方針にしている（§8）。

規則の定義位置は `scripts/sf-to-iplass/view/lib/field-decoration.js`。

参照項目にはもう1つSF側の設定がある。**選択できるレコードの絞り込み**で、editorの `displayType` そのものが変わるので§9で扱う。

## 4. 主要情報セクション

SFのハイライト表示に対応するセクション。対象項目の決め方は次の順。

| レイアウト側 | 対象項目の在処 |
|---|---|
| Lightningページに `dynamicHighlights` がある | そのFacetが参照する `primaryField` と `secondaryFields` |
| `showHighlightsPanel` のみ | 対象オブジェクトのCompactLayoutの `fields`（記述順） |
| どちらも無い | 主要情報セクションを作らない |

- SFの見た目に合わせ、**下のセクションと項目が重複することを許す**（重複を避けて下から取り除かない）。
- editorの `displayType` は `LABEL` にする（表示専用）。
- セクションの `displayCreate` / `displayUpdate` は `false`（新規・編集画面には出さない）。

CompactLayoutは対象オブジェクトのファイルが取得されていないことがある。無ければ主要情報を作らずに、**その事実を報告する**（推測で項目を選ばない）。

## 5. 関連リストとEntity側の被参照Reference

SFの関連リストは「子が親を参照している」関係の親側からの見え方である。iPLAssでこれを表すには、**親Entityに被参照Reference（`mappedBy`）を足す**必要がある。Viewだけでは表せない。

**Entity側の作業**（Viewより先に投入する）:

| キー | 値 |
|---|---|
| `@class` | `org.iplass.mtp.entity.definition.properties.ReferenceProperty` |
| `name` | 被参照プロパティ名（§5の命名） |
| `objectDefinitionName` | 子Entity名 |
| `mappedBy` | 子Entity側の親参照プロパティ名 |
| `multiplicity` | `-1`（件数を制限しない） |
| `referenceType` | **子側の親参照プロパティの値をそのまま踏襲する** |

`referenceType` はSFの主従関係/Lookupの区別からは決められない。子Entityのlive定義から実際の値を読んで合わせる（`ASSOCIATION` / `COMPOSITION`）。多重度の規則は `converting-salesforce-to-iplass-entity/SKILL.md` §11、参照関係の付随属性は同 `references/property-mapping.md` §19 が定義位置。

親Entityの全置換では `propertyList` と `declaredPropertyList` の両方に入れる（`iplass-definition-io` §4）。自己参照は1回の投入で順方向と被参照を同時に入れられないため2段階に分ける。

**被参照プロパティ名**: SFの `relationshipName` を土台に、Entity内で衝突しない名前を機械的に導く。**同じ名前が2つ導かれたときは黙って上書きせず、衝突として保留に回す**。命名の接頭辞規則はオブジェクトごとに異なるので、対象オブジェクトごとにユーザーへ確認する。

**Viewの大量データ参照セクション**は、この被参照プロパティを `propertyName` で指す。

| キー | 値 |
|---|---|
| `propertyName` | 親Entityの被参照Reference名 |
| `type` | `MASS_REFERENCE_SECTION` |
| `displayCreate` | `false`（親が未登録の時点では子を持てない） |
| `displayUpdate` | `true` |
| `editType` | `VIEW`（編集タイプ。親の編集画面から子を直接編集させない） |
| `properties` | 表示列（§6） |

参照先（子）Entityの定義が手元に無い関連リストは、セクションを作らず保留に回す（`coordinating-migration-work`）。SF標準の関連リスト名は子オブジェクトと参照項目に機械的には解決できないものが多く、その分は保留として残る。

**被参照プロパティが親Entityに実在しないセクションを投入すると、全置換がHTTP 500になる**（原因はエラー本文から読み取れない）。被参照ReferenceをEntityへ足す前にView側だけ作らせないため、変換器は親Entity定義を受け取って実在を確かめ、無ければセクションを作らず保留に回す。Entityを先に投入する順序（§11）を守れば当たらない。

## 6. 大量データ参照セクションの表示列

**表示列（`properties` の各要素）は `editor` を必須とする。** editorが無い列があると、定義の投入も取得も成功するのに、**詳細画面のレコード取得でサーバがNPEを投げる**（§12）。

列は `@class` を持たない。持たせるキーは次のとおり。

| キー | 値 |
|---|---|
| `type` | `MASS_REFERENCE_PROPERTY` |
| `propertyName` | 子Entityのプロパティ名 |
| `dispFlag` / `virtual` / `sortable` | `true` / `false` / `true` |
| `editor` | 検索結果系editor（下表） |

editorは**検索結果系**（`...definition.editor.search.result.MdcSearchResult<型>PropertyEditor`）で、詳細系（`...editor.detail.MdcDetail<型>...`）ではない。`displayType` は `LABEL`。

| Entity側のプロパティ型 | editorのクラス名の型部分 | editorの `type` |
|---|---|---|
| `STRING` | `String` | `STRING` |
| `LONGTEXT` | `LongText` | `LONGTEXT` |
| `INTEGER` | `Integer` | `INTEGER` |
| `DECIMAL` | `Decimal` | `DECIMAL` |
| `BOOLEAN` | `Boolean` | `BOOLEAN` |
| `SELECT` | `Select` | `SELECT` |
| `DATE` | `Date` | `DATE` |
| `DATETIME` | `Timestamp` | **`TIMESTAMP`** |
| `REFERENCE` | `Reference` | `REFERENCE` |
| `EXPRESSION` | `Expression` | `EXPRESSION`（戻り型のeditorを入れ子で持つ。§3） |

`DATETIME` だけEntity側の型名とeditor側の `type` が一致しない。上表に無い型は**editorを推測せず、その列を落としてレポートに理由を残す**。推測したeditorを送ると画面が落ちるため、落とすほうが安全。editorは列ごとに独立したコピーを入れる（テンプレートのオブジェクトを共有しない）。

**表示列が全滅したら、セクション自体を作らず保留に回す。** 列の無いグリッドは描画できず、**詳細画面が表示できなくなる**。列を落とすのと同じ理由で、セクションを出さないほうが安全である。子Entityの独自Nameが `AUTONUMBER` で、SFの関連リストの列が `NAME` だけのときにこれが起きる（唯一の列がeditorの手本不足で落ちる）。落とした列の理由とセクションを作らなかったことの両方をレポートに出す。

日時の列には**詳細セクションの要素と同じ `dateTimeFormat` を入れる**（§3）。検索結果系editorも同じキーを持つ。ここを飛ばすと、同じ項目が詳細セクションと参照セクションで違う書式で出る。書式を入れられなかった列は、列自体は残したままレポートで報告する（書式が無いだけで画面は動くため、列を落とすと情報が減って損になる）。

**列の解決**:

- SFの関連リストの列は標準トークン（レコード名・更新日時等を指す予約語）で来る。子Entityのプロパティ名へ解決し、解決できないトークンは列から落としてレポートに残す。
- 列の存在確認は子Entityの **`propertyList` と `declaredPropertyList` の両方**で行う。更新日時のような継承プロパティは `declaredPropertyList` に無いため、片方だけで確認すると解決できたはずの列を落とす。
- 定義APIはプロパティのidを公開しない。列は `propertyName` だけで持つ（id相当のキーを埋める手立ては無い）。

## 7. 添付ファイルセクション

添付用の関連リストがレイアウトにあれば、**最下部に専用のセクションを1つ**作り、Entity共通の添付ファイルプロパティを指す要素を1件だけ置く（`DEFAULT_SECTION`、editorはBINARY用の詳細系）。`displayCreate` / `displayUpdate` は `true`。

共通の添付ファイルプロパティ自体はEntity側の定型プロパティで、`converting-salesforce-to-iplass-entity/references/property-mapping.md` §18 が定義位置。Entity側にそのプロパティが無ければセクションを作らず報告する。

## 8. 検索View

同じ定義の中の `searchView` も組む。**SF側に「検索条件の一覧」に相当するメタデータが無い**ため、検索条件と検索結果は出所が別になる。

| 部分 | 出所 |
|---|---|
| 検索条件のプロパティ | 対象Entity定義（SFに対応する指定が無い） |
| 検索条件の並び順 | 詳細Viewの出現順 |
| 検索結果の表示列 | オブジェクトXML（object-meta）の `searchLayouts` の `searchResultsAdditionalFields` |
| editorの設定 | 詳細Viewに準ずる（載せられるものだけ。後述） |

`@class` は詳細Viewとは別系統になる。

| 部分 | `@class` | `type` |
|---|---|---|
| 検索View | `...search.definition.MdcSearchViewDefinition` | — |
| 条件セクション | `...search.definition.element.section.MdcSearchConditionSection` | `CONDITION_SECTION` |
| 結果セクション | `...search.definition.element.section.MdcSearchResultSection` | `RESULT_SECTION` |
| 条件の要素 | `...search.definition.element.property.MdcSearchConditionProperty` | `CONDITION_PROPERTY` |
| 結果の要素 | `...search.definition.element.property.MdcSearchResultProperty` | `RESULT_PROPERTY` |

条件のeditorは `...definition.editor.search.condition.MdcSearchCondition<型>PropertyEditor`、結果のeditorは§6と同じ検索結果系。型との対応も§6の表と同じで、`DATETIME` だけeditorの `type` が `TIMESTAMP` になる点も同じ。条件側と結果側のどちらにも数式（`EXPRESSION`）用のeditorがある（入力できないので `displayType` は `LABEL`）。

**条件のeditorの `displayType` は詳細Viewの既定へ揃える**（§3の表をそのまま使う。`SELECT` は `SELECT`、`REFERENCE` は `LINK`）。同じ項目が詳細画面と検索画面で違う見せ方になるのを避ける。**表を2箇所に持たない**（片方だけ直すとずれる）。検索結果は表示専用なのでこの揃えの対象外で `LABEL` 固定。

例外は `BOOLEAN` で、**検索条件だけ `RADIO` にする**。詳細Viewの既定は `CHECKBOX` だが、チェックボックスは「チェック済み＝true」の2値しか送れず、**オフのレコードを絞り込む条件が出せない**。`RADIO` なら有効/無効/未指定の3択になる。この上書きは検索条件用の小さな対応表に持つ。

もう1つの例外は逆向きで、**SFの型で決まる複数行表示（§3）は検索条件に持ち込まない**。
検索画面は絞り込みの場なので、`TextArea` の項目でも条件の入力欄は単一行（`TEXT`）にする。
検索結果の表示列は `LABEL` 固定なので元から関係しない。

`RADIO` の有効/無効のラベル（`trueLabel` / `falseLabel` とその多言語リスト）は**画面に出る文言でテナントの多言語設定**なので、ツールで文言を作らず現行Viewの値を借りる。**サーバは省略しても埋め戻さない**ので、借りられなかったときはレポートで報告する（黙って通すとラジオの選択肢が無名になる）。

数式（`EXPRESSION`）の条件・表示列は**戻り型のeditorを入れ子で持たせる**（§3）。入れ子を作る関数が条件用・検索結果用に変わるだけで構造は同じ。

**どのEntityでも同じにする設定**:

| 場所 | キー | 値 |
|---|---|---|
| 条件セクション | `sortSetting` | `[{ "sortKey": "updateDate", "sortType": "DESC", "nullOrderType": "LAST" }]` |
| 結果セクション | `searchResultType` | `SWITCH` |
| 結果セクション | `detailViewTypeInSearchResult` | `DIALOG` |
| 結果セクション | `pagingPosition` | `BOTH` |

セクションのその他の設定（1件だけ常時表示する条件の件数など）は現行Viewの値をそのまま引き継ぐ。ツールが決めるのは要素と上表だけにする。

**検索条件のプロパティ**は宣言プロパティ（`declaredPropertyList`）を網羅し、次を除いて `createDate` / `updateDate` を足す。

| 除くもの | 理由 |
|---|---|
| 添付ファイル（`BINARY`） | 検索条件のeditorが存在しない |
| 被参照Reference（多重度 `-1`） | 関連リスト用のプロパティで、検索条件として意味を持たない |
| `createDate` / `updateDate` 以外の継承プロパティ | iPLAssの内部管理項目で、SFの項目に対応しない |

標準の `name` は出さず、**Entityの `namePropertyName` が指す独自プロパティを使う**。SFの標準Name項目を独自プロパティへ移す規約は `converting-salesforce-to-iplass-entity/references/property-mapping.md` §15 が定義位置で、詳細Viewもそちらを表示している。両方出すと同じ値の条件が2つ並ぶ（保存時に独自Nameの値が標準 `name` へコピーされるため）。

**並び順**は詳細Viewの出現順を先に置き、詳細Viewに無いプロパティをEntity定義の宣言順で後ろへ続ける。大量データ参照セクションの表示列は子Entityの項目なので並びの基準に入れない（表示列は `properties` にあり `elements` には無いため、セクションの要素だけを辿れば自然に外れる）。

**検索結果の表示列**は名称プロパティを先頭に置き、続けて `searchResultsAdditionalFields` のトークンを読み替える。要素には `sortable` と `outputFile` を `true`、`multiplicity` にEntityの多重度を入れる。

トークンの書式はオブジェクトによって違う（標準オブジェクトは `<オブジェクトのトークン>.<項目のトークン>`、カスタムオブジェクトは素の項目名と大文字の標準項目トークン）。次の順で読み替える。

| 順 | 規則 |
|---|---|
| 1 | Entityに同名のプロパティがあればそれ |
| 2 | ドットの接頭辞が**自オブジェクトを指すときだけ**外して再試行。他オブジェクトを指すもの（所有者の別名など）は別Entityの項目なので載せられない |
| 3 | 標準項目トークンの対応表（レコード名 → 名称プロパティ、作成日 → `createDate`、最終更新日 → `updateDate` 等） |
| 4 | 解決できなければ列を落としてレポートで報告 |

`searchLayouts` を持たないオブジェクトもある。そのときは名称プロパティ1列だけにする（推測で列を選ばない）。

**詳細Viewの設定のうち検索Viewに載せられるもの**: 検索用のeditorは詳細用と別クラスなので、持つキーも違う。**持っていないキーは投入しても取得時に落ちる**ので、載るものだけ入れる。

| 設定 | 検索条件 | 検索結果 |
|---|---|---|
| 日時の書式（editorの `dateTimeFormat`） | 入れる | 入れる |
| ヒント（要素直下の `hint`） | 載るが**入れない** | **載らない** |
| 文字数制限（editorの `maxLength`） | **キーが無い** | 表示専用なので対象外 |
| 初期値（editorの `defaultValueTemplate`） | **キーが無い** | 同上 |

日時の書式は§3の対応表をそのまま使い、条件と結果の両方に入れる。文字数制限と初期値は詳細Viewだけの設定になるので、その事実をレポートに残す（検索画面で長さ制限が効かないことは定義の照合では見えない）。

ヒントは検索条件の要素に載せられるが**入れない**。検索画面は入力の手引きではなく絞り込みの場なので、項目ごとの入力ヒントは詳細View（入力画面）だけに置く。

**自動生成のフラグ**（`autoGenerateSearchView` / `autoGenerateDetailView`）は両方 `false` にする。立っているとこちらが組んだ定義が使われない。

規則の定義位置は `scripts/sf-to-iplass/view/lib/build-searchview.js`（検索レイアウトの読み取りは `parse-search-layout.js`、editorのテンプレートは `build-search-editor.js`）。

## 9. 参照項目の絞り込み（選択フィルター）

SFの参照項目は**選択できるレコードの絞り込み**（参照フィルタ）を持てる。iPLAssでは参照プロパティのeditorを**選択フィルター**にして、`SelectFilterConfig` の検索条件で同じ絞り込みを表す。

| キー | 値 |
|---|---|
| editorの `displayType` | `SELECTFILTER` |
| editorの `displayLabelPropertyName` | `Name`（選択肢に出す表示） |
| editorの `selectFilterConfig` | 下表の設定 |

`displayTypeViewMode`（表示モードでの見せ方）と `linkConfig` は変えない。絞り込みは入力するときの話で、表示は参照リンクのままでよい。

### SelectFilterConfigの設定

| キー | 値 | 理由 |
|---|---|---|
| `propertyName` | `Name` | 打った文字で絞り込むプロパティ。どのEntityも独自Nameを持つのでこれで揃う |
| `executeMode` | `REMOTE` | 参照先の件数が読めないのでサーバ側で絞り込む |
| `condition` | SFの参照フィルタと同等の条件 | EQLのwhere句（PreparedQuery形式） |
| `searchPattern` | `PARTIAL` | 打った文字の部分一致で探す |
| `researchSelectedPattern` | `KEEP` | 再検索しても選んだものを外さない |
| `placeholder` | `入力して検索...` | 入力領域の案内 |
| `searchPageSize` | `0` | 既定値。省略して投入しても取得し直すと `0` が返るので、明示して持たせて再変換の差分にしない |

`sortType`（ソートアイテム）は指定しない。省略して投入すればキー自体が返らないので、これも再変換の差分にならない。

### 検索条件の書き方

条件は**参照先Entityを対象に**評価される。SFは絞り込みの左辺・右辺を `<参照先オブジェクト>.<項目>` で書くので、先頭のオブジェクト名を落として参照先のプロパティ名にする。

| SFの書き方 | EQL |
|---|---|
| `<参照先>.<項目>` | `<項目>` |
| 関連を辿る `<関連>__r.<項目>` | `<関連>__c.<項目>`（関連参照の接尾辞を参照プロパティの接尾辞に読み替える） |
| 末尾の `Id` | `oid` |

| SFの演算子 | EQL |
|---|---|
| `equals` / `notEqual` | `=` / `!=` |
| `lessThan` / `greaterThan` / `lessOrEqual` / `greaterOrEqual` | `<` / `>` / `<=` / `>=` |
| `startsWith` / `contains` | `like '<値>%'` / `like '%<値>%'` |
| `includes` / `excludes` | 移せない（保留） |

**SFは空値との `equals` / `notEqual` で「未入力かどうか」を表す**ので、`is null` / `is not null` に読み替える。

値の書き方は**参照先の項目のSFの型**で決まる。型が引けるのは参照先オブジェクトの直下の項目だけで、関連を辿った先や標準項目は引けない。

| 参照先の項目の型 | 値 |
|---|---|
| Checkbox | `true` / `false`（SFは `True` / `False` の文字列で持つ） |
| Number / Currency / Percent | 引用符なし |
| それ以外・型が引けないもの | シングルクォートで囲む（EQLの文字列リテラル。含まれるクォートは重ねる） |

型が引けない項目で値が `True` / `False` のときは、真偽値か文字列か決められないので保留する。

### 移せない絞り込み

**選択フィルターの検索条件は編集中レコードの値を参照できない。** 使えるバインド変数はユーザー・日時・リクエスト・セッションで、いま開いているレコードの項目を指す変数が無い。SFの `$Source.<項目>`（編集中レコードの値）や `$Profile.<項目>`（実行者のプロファイル）を含む条件はそのまま移せないので、**保留にして報告する**。

次のものも条件に落とさない。部分的に反映すると絞り込みそのものが変わるので、保留のほうが安全。

| 対象 | 理由 |
|---|---|
| OR / NOT を含む条件の組み合わせ式（SFの `booleanFilter`） | 組み方を取り違えると絞り込みが変わる。ANDだけで全条件をつないだ式は指定が無いのと同じなのでそのまま扱う |
| SFのレコードIDとのリテラル比較 | SFのIDはiPLAssのoidと対応しない |
| 日時の項目のリテラル比較 | EQLでの日時リテラルの書き方の手本が無い |
| SFで読み取り専用（`Readonly`）の項目 | 選択の場が無い |

保留した項目は参照リンク（`LINK`）のままにする。**絞り込みが効かない状態で画面に出る**ので、レポートで必ず報告する。

### SFとの差異

SFの**任意フィルタ**（`isOptional`）は利用者が絞り込みを外して全件から選べる。iPLAssの検索条件は常に効くので、**任意フィルタも強制フィルタと同じになる**。レポートでどちらだったかを出し、絞り込みを外せなくなることをユーザーに伝える。

### 反映しないときは残さない

SF側で参照フィルタが消えた場合や条件を移せなかった場合は、**`displayType` を `LINK` に戻して `selectFilterConfig` を削除する**。現行Viewが前回の出力である以上、消す分岐が無いと絞り込みが残り続ける（`Readonly` の `LABEL` と同じ理由）。

規則の定義位置は `scripts/sf-to-iplass/view/lib/build-select-filter.js`。

## 10. サイドメニュー

Viewを作ったら、そのEntityをサイドメニューから開けるようにする。定義は2つに分かれ、役割が違う。

| 定義 | パス | 役割 |
|---|---|---|
| EntityItem | `view/mdc/sidemenu/item/<名前>` | 見た目と挙動の正本（表示名・対象Entity・押した時の挙動） |
| SideMenuTree | `view/mdc/navigation/<名前>` の `sideMenu` | 配置の正本（並び順と階層） |

**ツリーが持つのはitemの名前だけ。** 取得するとEntityItemの内容が展開されて返るが、ツリー側に表示名などを書いても保存されず、取得のたびにEntityItemから解決される。だから表示名や挙動を直すときはEntityItem側を投入する。逆に階層（NODE）のitemは子を持たないので、**どのitemをどこに置くかはツリー側だけが持つ**。

**階層の下のitemは `childs` に入る**（`menuItems` はツリーの最上位だけ）。配置済みかどうかを調べるときは両方を辿る。片方だけ見ると階層の下に置かれているitemを見落とし、**同じitemを最上位へ重複して足す**。

| 種別 | `@class`（`org.iplass.mtp.mdc.view.navigation.sidemenu.definition.items.` 配下） | `type` |
|---|---|---|
| Entityを開くitem | `MdcEntityMenuItem` | `ENTITY` |
| 階層のitem | `MdcNodeMenuItem` | `NODE` |

### EntityItemに当てる設定

| 設定 | 値 |
|---|---|
| `entityName` | 対象Entityの名前（パッケージを含む完全名） |
| `name` | Entity名の末尾セグメント。**SFのAPI名に付く接尾辞は落とす**（itemの名前はEntity名に合わせる） |
| `displayName` / `localizedDisplayNameList` | Entityの表示名をそのまま写す。Entityに表示名が無ければキー自体を持たせない |
| `showWithExecuteSearch` | `true`。押した時点で検索を実行する（空の一覧を先に見せない） |

`viewName` のような既にあるキーはそのまま残す。無いものを足す必要はない（省略すると `DEFAULT` が使われる）。

### 配置

| 状態 | すること |
|---|---|
| 既にツリーに置かれている | **位置を動かさない**（配置は先に決めたものを正とする） |
| 名前を変えるEntityが旧名で置かれている | その場で名前だけ差し替える（位置は動かさない） |
| どこにも無い | `menuItems` の一番下に足す |

足す要素は `@class` / `name` / `type` だけでよい。中身はEntityItem側が持つ。

**複数Entityをまとめて横展開するときは、ツリーの投入を1回にまとめる。** 変換器はEntityごとに「元のツリー＋自分の1件」を出すので、出力を順に投入すると**最後の1件しか残らない**（それぞれが同じ元ツリーを土台にしているため）。Entityごとの出力から自分のitemだけを取り出し、1つのツリーへ積んでから投入する。EntityItemは定義が別なのでEntityごとに投入してよい。

### itemの名前を変えるとき

ツリーはitemを名前で参照するので、**新しい名前で作成 → ツリーの参照を差し替え → 旧itemを削除**の順に流す。順序を変えるとツリーが参照先を失う瞬間ができる。旧itemを消す前に取得して退避しておく（戻すときの元になる）。ツリーから参照されていない旧itemを消しても画面には影響しない。

item一覧の取り方は `iplass-definition-io` §7。雛型として配られているitem（`mdc/template/` 配下）は移行の対象外。

規則の定義位置は `scripts/sf-to-iplass/view/lib/build-sidemenu.js`。

## 11. 投入と照合

**投入順は Entity → View → サイドメニュー**。Viewの大量データ参照セクションはEntity側の被参照プロパティの存在を前提にし、サイドメニューのitemは開く先のViewを前提にする。

**定義パス**: 詳細View・検索View・サイドメニューの3種はそれぞれ別のパスに置かれる（種別ごとのパスと一覧の取り方は `iplass-definition-io` §7 が定義位置。この環境での実体は [CLAUDE.md](../../../CLAUDE.md) の固有値表）。詳細Viewと検索Viewは1つのEntityView定義の中の要素なので、投入は1回で済む。

Viewの定義は数百KB規模になり得るため、取得・投入は定義APIを使う（経路の判断は `iplass-definition-io` §1）。**全置換の前に、`propertyName` を持たない要素を詳細View・検索Viewの両方から除去する**（同 §11 が定義位置。除去しないとHTTP 500になる）。除去件数は報告する。

**未存在の定義には `post`、既存には `put` を使う**（同 §5）。View定義が無いEntityへ横展開するときは `post` になる。`put` で投入すると原因の読み取れないHTTP 500になり、`propertyName` 欠落（§12）と区別がつかない。**存在判定は一覧で行う**（`get` は未存在でも200 SUCCESSを返すため判定に使えない）。サイドメニューのEntityItemも同じ判定が要る。

全置換では、変換対象外のトップレベル要素を取得結果からそのまま持ち越す。詳細Viewと検索Viewは両方こちらで組むので、持ち越すのはそれ以外（表示名・多言語名など）だけになる。

**照合の基準は2つ持つ。** 送信内容との比較だけでは、送信側で落ちているものを検出できない（送った定義と実機が一致しても、liveにあったものが消えていれば気づけない）。

| 基準 | 何を見るか | 何を捕まえるか |
|---|---|---|
| 投入前のlive | セクションの**種別ごとの件数**・項目名の集合 | 持ち越しの漏れ（§2）・意図しない欠落 |
| 送信した定義 | 下の表の内容 | 投入の失敗・サーバ側の丸め |

**取得できないViewは照合の対象から黙って外れる。** 一括で照合するときは、取得に失敗したViewを「異常」として数える（0件成功を正常と見なさない）。GETが500になる状態そのものが不具合である（§12）。

**投入後の照合**: 取得し直して次を確認する。

| 対象 | 照合する内容 |
|---|---|
| 詳細View | セクション数・項目数・空白数・`requiredDisplayType` の件数 |
| editorの型 | 全要素で editor の `type` がEntityのプロパティの型と対応していること（§3の表）。数式が文字列用editorのまま残っていないこと |
| 参照セクション | 表示列が0件のセクションが無いこと（§6）・`propertyName` が親Entityに実在すること（§5） |
| 作成者・最終更新者 | 者→日の対で並んでいること・者が奇数番目にあること・日が `LABEL` であること（§3） |
| 参照セクション | 表示列数・`editor` を持たない列が0件であること |
| 項目の設定 | `hint` / `defaultValueTemplate` / `maxLength` の件数 |
| 入力欄の見せ方 | 詳細Viewの `STRING` / `LONGTEXT` の `displayType` の内訳（SFが `TextArea` 系の項目が `TEXTAREA` になっていること・`Readonly` でない項目に `LABEL` が残っていないこと）。検索条件が単一行のままであること |
| 選択フィルター | `displayType` が `SELECTFILTER` の参照項目の件数・`selectFilterConfig` の設定（§9の表）・条件の本文がSFの参照フィルタと同じ絞り込みになっていること |
| 日時 | 詳細セクションの要素・参照セクションの表示列・検索条件・検索結果の表示列で `dateTimeFormat` が欠けたものが0件であること |
| 数式 | 入れ子editorが欠けたものが0件であること・入れ子の `type` がEntity定義の `resultType` と一致すること |
| 検索View | 検索条件の件数・条件のeditorの型と `displayType` の内訳・表示列の並び・ソート指定・表示タイプ4種（§8の表）・標準 `name` が出ていないこと |
| サイドメニュー | EntityItemの4設定（§10の表）・ツリーでの位置が変わっていないこと・ツリーから旧名を参照している要素が残っていないこと |

**「入力欄の見せ方」の照合はセクションを区別して数える**。同じプロパティが主要情報セクション（§4）と入力欄のセクションの両方に要素として現れる。主要情報セクションは表示専用なので、そちら側のeditorの `displayType` は常に `LABEL` になる（§4）。プロパティ名ごとに最初に見つかった要素だけを見る書き方をすると、セクションの並び順（主要情報が先頭）により常に主要情報側の `LABEL` を拾ってしまい、入力欄側の実際の値を確認できない。

**再生成の冪等性**: 投入後のliveを土台にもう一度変換すると、上表の正規化2項目（`elementRuntimeId` / `label`）を除いて送ったペイロードと一致する。それ以外の差分が出たら、liveから写した値を毎回書き換えている箇所がある（2回目以降の実行で差分が出続ける）。

サーバは投入内容を次のように正規化する。**これらは差分として現れるが異常ではない**ので、照合時に送信内容とのバイト一致を期待しない。

| 正規化 | 内容 |
|---|---|
| `elementRuntimeId` | サーバが付け直す（送った値は残らない） |
| キーの順序 | 並び替わる |
| `label` | `displayType` が `LABEL` の要素に `true` が補完される |

**投入したペイロードは復旧元として残す**（`work/`）。定義が読めなくなったときの戻し先はこれになる（§12）。

## 12. 症状と原因

| 症状 | 原因と対処 |
|---|---|
| Viewの全置換がHTTP 500 | 次の3つを順に疑う。①未存在の定義に `put` を使った（§11。存在判定は一覧）②`propertyName` を持たない要素が含まれている（`iplass-definition-io` §11）③被参照プロパティが親Entityに無いセクションを含む（§5） |
| `live` を無改変で送り返しても全置換がHTTP 500 | liveそのものが保存できない状態にある。`detailView` と `searchView` を別々に送って切り分ける。片方だけ通るなら、通らない側に上表のいずれかが混ざっている |
| 詳細画面が表示できない（定義は投入・取得とも通る） | 表示列が0件の参照セクションを含む（§6）。列の無いグリッドは描画できない |
| 詳細画面が**空**になる（セクションも項目も出ない。定義は投入・取得とも通り、手本とキーの集合も一致する） | セクションの `collapsible` / `expandable` / `showLink` を `false` にしている。**この3つは `true` にする**（§2）。稼働中のViewは全セクションが `true` で、`false` でも定義の往復は通るため照合では露出しない |
| 詳細画面が開かない。定義は正しく、レコードの取得が失敗する | Entity側に**評価できないExpression**がある。定義の照合では露出しない。切り分けは `converting-salesforce-to-iplass-entity/references/property-mapping.md` §14 |
| 定義の投入・取得は通るのに、詳細画面の関連リストのレコード取得で `MdcSearchResultPropertyEditorHandler` の `this.editor is null` によるNPE | 表示列に `editor` が無い（§6）。列を `propertyName` だけで投入するとサーバは他のキーを既定値で埋め戻すが、**`editor` は補完しない**ため、定義の往復では露出しない |
| 定義APIのGETがHTTP 500になり、サーバログが `MetaMdcDetailMassReferenceProperty.currentConfig` → `resolvePropertyHandlerByName` で `propertyName is required` | サーバ内部形式の側で表示列の `propertyName` が失われている。**この状態はGETできないため、復旧の前にAdminConsoleからメタデータをXMLエクスポートして保全する**（保全せずに上書きすると原因を特定できなくなる）。復旧は§11で残したペイロードの再投入 |
| 上記が、Viewを触っていないのに起きた | 引き金はEntity側の変更である。**プロパティの除去→再追加**（`iplass-definition-io` §10 の2段階）を行うと、参照セクションを持つViewが読めなくなることがある。Entity側でこの手順を使うときは、対象Entityの**Viewを投入し直す前提で計画する**（先にペイロードを手元に用意しておく） |
| 詳細画面を開くと下方へ自動スクロールする | View定義にスクロール・初期フォーカスを指示するキーは無い。定義側の設定ではない |

## 13. 画面での確認とユーザーへの報告

**定義の往復が通ったことは、画面が動くことの証拠にならない。** 新しいセクション種別を投入したときは、定義の照合で満足せず**必ず画面を開いて確認する**。§6のeditorのように、定義APIの照合では絶対に露出しない不足がある。

画面を開く操作はユーザーに依頼する（**サイドメニューからの遷移・検索画面・詳細画面・編集画面**）。サイドメニューは押した時点で検索が実行されること（§10）、選択フィルターにした参照項目が絞り込まれること（§9）まで見てもらう。関連リストに関わるWebApiはBearerトークンを受け付けないため、こちら側から画面と同じ経路を叩いて代替することはできない。

**画面のURL**: 検索画面・詳細画面のActionMapping定義は、サブパスの先頭セグメントをView名として受ける。View名を省いたパスは既定のViewを開く。公式ドキュメントはサイドメニューのitemへ渡すパラメータ（`viewName=XXX`）だけを説明しており、URLで直接開く形は書かれていない。

| 画面 | URL（テナントのURLに続けて書く） |
|---|---|
| 検索画面 | `mdc/entityview/search/index/<Entity定義名>` |
| 検索画面（View名指定） | `mdc/entityview/search/index/<View名>/<Entity定義名>` |
| 詳細画面 | `mdc/entityview/detail/index/<Entity定義名>/<oid>/<version>` |
| 詳細画面（View名指定） | `mdc/entityview/detail/index/<View名>/<Entity定義名>/<oid>/<version>` |

Entity定義名はドット区切りのまま書く（パスへ展開しない）。存在しないactionは404、実在するactionは未ログインでも200（ログイン画面）が返るので、**パスが解決されるかどうかはログインせずに確かめられる**。

**実機の形を確かめる方法**: 最小構成のJSONを投入して取得し直し、サーバが埋め戻した内容を「そのクラスの形」とみなしてはいけない。サーバは既定値を持つキーだけを埋め戻し、**既定値を持たない必須のキーは補完しない**ので、往復で得た形は必要なキーの部分集合にすぎない。形を確定させるには、実機の既存定義から同種の要素を採取するか、AdminConsoleのUIで1件作らせてその結果を取得して突き合わせる。

## 14. 保留

保留の置き場・申し送りの書式・検出と更新の境界は `coordinating-migration-work` が定義位置。View変換で出る保留は次の種類。

| 保留 | 解除 |
|---|---|
| 関連リストの参照先（子）Entityが未移行 | 子Entityの移行後に被参照Reference（§5）とセクションを足す |
| 関連リスト名から子オブジェクト・参照項目を解決できない | 対応をユーザーに確認して手当てする |
| 被参照プロパティ名が他と衝突する | 命名規則をユーザーに確認して付け替える |
| editorを組めない型の項目・列・検索条件を除外した | 型に対応するeditorを実機の既存定義から採取して足す |
| CompactLayoutが未取得で主要情報を作れない | SFメタデータを取得してから作る |
| 検索結果の表示列トークンを読み替えられない（他オブジェクトの項目を指すもの等） | 対応をユーザーに確認して手当てする |
| SFの参照フィルタを検索条件に移せない（§9） | 絞り込みの代わりの手段をユーザーに確認する。編集中レコードの値で絞る条件は検索条件では表せない |

## 15. 同じEntityに別のViewを追加する

EntityView定義のパスの末尾がView名なので、別のView名で1本足せば既存のViewを触らずに別レイアウトを並立できる（既定は `DEFAULT`）。1つの定義に `detailView` と `searchView` が同居するため、**View名を分けると詳細画面と検索画面はセットで別物になる**。

既存Viewの複製で作るときは、取得した定義の**3箇所**のView名を書き換える。定義の直下だけ直すと内側のViewの名前が複製元を指したままになる。

| 位置 | `name` | `viewName` |
|---|---|---|
| 定義の直下 | `<Entity名をスラッシュ展開>/<View名>` | `<View名>` |
| `detailView` | `<Entity名をスラッシュ展開>/detail/<View名>` | `<View名>` |
| `searchView` | `<Entity名をスラッシュ展開>/search/<View名>` | `<View名>` |

未存在のパスなので投入は `post`（§11）。自動生成のフラグは複製元のまま `false` にしておく（立っていると複製した定義が使われない。§8）。

サイドメニューから開けるようにするには、**別のEntityItemを作って `viewName` にView名を入れる**（§10）。itemの名前は既存itemと衝突しない形（`<Entity名の末尾セグメント><View名>`）にし、ツリーでは複製元のitemの隣へ置く。`viewName` を持たないitemは既定のViewを開くので、複製元のitemは触らない。

照合は§11のほかに、**複製元のViewが無変更であること**（取得し直してView名以外が一致すること）を確認する。URLで直接開く形は§13。

**複製したViewへセクションを足すときは、バックアップを起点にする。** 更新は全置換なので、liveを起点にすると実行のたびに足した分が積み増される。生成側で「前回足した分」を目印（スクリプトセクションの本文に埋めた目印のid・プレースホルダ用のラベル）で判別して落としてから組み直せば、何回実行しても件数が変わらない。照合では**既存セクションの中身がバックアップと一致すること**を見る（並びを意図して変えたときは、件数と中身の集合で照合する）。

画面をタブで構成する場合の作りは `converting-salesforce-screens-to-iplass` §9 が定義位置（詳細Viewにタブのセクション種別は無いため、スクリプトセクションかテンプレートセクションで作る）。

## リファレンス

| 参照先 | 用途 |
|---|---|
| `iplass-definition-io` | 定義の取得・投入・照合の作法（経路選択・全置換の作法・`propertyName`欠落要素の除去） |
| `converting-salesforce-to-iplass-entity` | 対象Entity側の変換。多重度（§11）・参照関係の付随属性・共通の添付ファイルプロパティ |
| `coordinating-migration-work` | 保留の置き場と申し送りの書式 |
| [../../../scripts/sf-to-iplass/README.md](../../../scripts/sf-to-iplass/README.md) | View変換器・被参照Reference追加ツールのCLI仕様と出力ファイル |
| `iplass-dev` プラグインの各スキル | mdc View・Entity定義のJSON形状、プロパティ型、公式仕様のiPLAss側一次情報 |

iPLAssの仕様・JSON形状が不明なときは記憶で補わず、上のスキルを参照する。
