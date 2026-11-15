# スキルとリファレンスの索引

様々な md ファイルとツールがあるが、どれをいつ見るかをここにまとめる。固有の値（環境固有の名称・パス）は載せない。実体は [CLAUDE.md](../../CLAUDE.md) の固有値表を見る。

## いつ何を参照するか

| やりたいこと | 参照先 |
|---|---|
| iPLAssの定義を取得・作成・更新・削除する | [iplass-definition-io](iplass-definition-io) |
| 定義のパスが分からない（Entity・SelectValue・WebApi・Template・mdc View・**メール/SMS/プッシュ通知のテンプレート**・テナントの各種別と一覧の取り方） | [iplass-definition-io/SKILL.md](iplass-definition-io/SKILL.md) §7（この環境での実体は [CLAUDE.md](../../CLAUDE.md) の固有値表） |
| 一覧の接頭辞が当たらず500になる（接頭辞が浅いのか種別が無いのか区別できない） | [iplass-definition-io/SKILL.md](iplass-definition-io/SKILL.md) §7 |
| 全置換更新で既存の定義を壊さずにデプロイする | [iplass-definition-io](iplass-definition-io) |
| 投入した項目が保存されない・送信サイズが上限を超える | [iplass-definition-io](iplass-definition-io) |
| 定義のプロパティ（キー名・許容値・既定値・多態のサブクラス）が分からない／GUIの項目名に対応するJSONのキーを知りたい | [iplass-definition-io/SKILL.md](iplass-definition-io/SKILL.md) §12（[docs/iplass-official/](../../docs/iplass-official/) で機能を掴み、iPLAss本体のソースでキーを確定する。ソースの置き場と投入方法は [CLAUDE.md](../../CLAUDE.md) の固有値表） |
| ソースを引くディレクトリが手元に無い | `bash scripts/iplass/fetch-reference-sources.sh` で各自ローカルへ投入する（Git管理外。投入先は [CLAUDE.md](../../CLAUDE.md) の固有値表「ソース参照ディレクトリ」） |
| 投入も検査も通るのに実行時だけ壊れる（埋め込みや正規表現が潰れた） | [iplass-definition-io/SKILL.md](iplass-definition-io/SKILL.md) §4・§9 |
| Entityのレコードを検索・取得・登録・更新・削除する（Entity CRUD API） | [iplass-entity-crud-api](iplass-entity-crud-api) |
| EntityをEntity CRUD APIへ公開する（EntityWebApiの権限フラグ） | [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) §2 |
| レコード操作が意味の分からない500になる／SUCCESSなのに値が入っていない／日本語の検索条件で1件も一致しない | [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) §5・§6 |
| 参照先を辿るパス式で500になる／移行しただけのBooleanの条件で1件も一致しない | [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) §8 |
| 日付で絞り込む（リテラルの書き方）／本日日付を条件に入れたい | [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) §8 |
| 評価時点で値が変わる数式（本日日付等）をどう移すか | [converting-salesforce-to-iplass-entity/references/property-mapping.md](converting-salesforce-to-iplass-entity/references/property-mapping.md) §14 |
| 検証で開けた権限を元の状態へ戻す（全フラグfalseは「元の状態」ではない） | [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) §7 |
| 検証で作ったレコードを消す（参照を外す順・権限を閉じる前に消滅を確認する） | [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) §7 |
| SFオブジェクトからiPLAss Entityを作る／既存Entityへ後追いする | [converting-salesforce-to-iplass-entity](converting-salesforce-to-iplass-entity) |
| SF項目の型・必須・桁数・一意・選択肢・数式・項目履歴管理をiPLAssへ対応させる | [converting-salesforce-to-iplass-entity/references/property-mapping.md](converting-salesforce-to-iplass-entity/references/property-mapping.md) |
| 全Entity共通の定型プロパティ（独自Name・SalesforceId・添付ファイル）を足す | [converting-salesforce-to-iplass-entity/references/property-mapping.md](converting-salesforce-to-iplass-entity/references/property-mapping.md) §15・§16・§18 |
| プロパティの多重度を決める（JSONでの書き方・無制限を使える型） | [converting-salesforce-to-iplass-entity/SKILL.md](converting-salesforce-to-iplass-entity/SKILL.md) §11 |
| SFの主従関係・参照先削除時の挙動・親の付け替え可否をiPLAssで表す | [converting-salesforce-to-iplass-entity/references/property-mapping.md](converting-salesforce-to-iplass-entity/references/property-mapping.md) §19 |
| 選択肢の値にラベルを入れてしまい、同じ値セットを共有する他Entityと値集合が食い違う（値が黙って落ちる） | [converting-salesforce-to-iplass-entity/references/property-mapping.md](converting-salesforce-to-iplass-entity/references/property-mapping.md) §7 |
| SFの入力規則をiPLAssのValidatorへ移す | [converting-salesforce-to-iplass-entity/references/validation-rule-mapping.md](converting-salesforce-to-iplass-entity/references/validation-rule-mapping.md) |
| SFページレイアウトからiPLAssの詳細Viewを作る（セクション・behavior・ハイライト・添付） | [converting-salesforce-layout-to-iplass-view](converting-salesforce-layout-to-iplass-view) |
| SFの関連リストをiPLAssで表す（親Entityへの被参照Reference＋大量データ参照セクション） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §5・§6 |
| 同じEntityに別のView（別レイアウト）を追加する（View名の3箇所・複製・サイドメニュー） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §15 |
| 投入した画面をブラウザのURLで直接開く（View名の指定） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §13 |
| Viewは投入できたのに画面がエラーになる／Viewの定義が読めなくなった | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §12 |
| View定義が無いEntityへViewを横展開する（器とヘッダの既定生成・未存在なら post） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §1・§11 |
| 全置換でliveにあったセクション（組織図等の埋め込み）を消さない | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §2 |
| 定義は通るのに画面に値が出ない／画面が表示できない（editorの型・表示列0件） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §3・§6・§12 |
| 詳細画面が空になる（セクションも項目も出ない。定義の往復も手本との照合も通る） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §2・§12 |
| 投入したExpressionが評価できるかを確かめる | [converting-salesforce-to-iplass-entity/references/property-mapping.md](converting-salesforce-to-iplass-entity/references/property-mapping.md) §14.1 |
| SF標準項目の表示名を反映する（翻訳ファイルに無い分） | [converting-salesforce-to-iplass-entity/SKILL.md](converting-salesforce-to-iplass-entity/SKILL.md) §8 |
| 詳細Viewに文字数制限・日時の書式・ヒント・初期値を入れる（4つの出所とSFの数式の扱い） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §3 |
| 数式プロパティのeditorを作る（戻り型のeditorを入れ子で持たせる） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §3 |
| 検索Viewを作る（検索条件の範囲と並び順・SFの検索レイアウトからの表示列・条件editorの表示形式・検索用editorが持たないキー） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §8 |
| 参照項目の選択できるレコードを絞り込む（SFの参照フィルタ→選択フィルターの検索条件・条件の書き方・移せない絞り込み） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §9 |
| サイドメニューにEntityを載せる（EntityItemとSideMenuTreeの役割分担・itemの名前と配置の決め方・itemの改名手順） | [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) §10 |
| SFの独自画面が宣言的画面（GEM/MDC）で置き換えられるかを判定する | [converting-salesforce-screens-to-iplass](converting-salesforce-screens-to-iplass) |
| SFの独自画面をiPLAssのカスタム画面へ移植する（段階分け・構成・埋め込み・Vue SFC化） | [converting-salesforce-screens-to-iplass](converting-salesforce-screens-to-iplass) |
| SFの画面フロー（screen flow）を移植する（フローXMLの読み方・要素と移植先の対応・複数の画面をVueの段へ落とす） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10 |
| フローの入力欄の種別をVueの部品へ対応させる／レコード検索型の部品（検索して1件選ぶ）の状態の持たせ方 | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.2 |
| フローの分岐を読む（`conditionLogic` を読まずに1つ目の条件だけで判断しない・比較の右辺が無い条件の意味） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.1 |
| フローの画面を段にするか、段の中のメッセージにするか | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.3 |
| 画面の入力検証（正規表現）をどこで評価するか（Entity側のValidatorと二重に持たない） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.2 |
| 画面やViewの移行が先に来て、土台のEntityがまだ無いと分かった | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §2（保留の種類は [converting-salesforce-to-iplass-entity/SKILL.md](converting-salesforce-to-iplass-entity/SKILL.md) §7） |
| フローがレコードを丸ごと複製している処理を写す（除外するプロパティの決め方・全項目コピーの箇所の洗い出し） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.4 |
| 移行の確認が「通ったように見えて何も確かめられていない」状態になるのを避ける | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.5 |
| 実行しているユーザー自身に依存する判定を確かめる（認証系のデータを一時的に触るときの条件） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.5 |
| 管理者では通るのに一般の利用者で通らない（権限不足と設定漏れが同じメッセージになる） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.5 |
| **フローが通知（メール等）を送っている**（受け皿の探し方・送るタイミング・文面とリンク・確かめられる範囲） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.6 |
| 送る仕掛けをまだ載せず、送るはずだった内容をレコードとして残す（テンプレートの展開・状態・書く位置） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.6 |
| アプリ内通知の受け皿を自分で作る（通知の実体と「気づく手段」の2つが要る） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.6 |
| 実データが揃わないと通らない判定を一時的に緩めて先へ進める（印・戻す場所・解除の条件） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.5 |
| MDCの全画面（トップ・検索・詳細）で動くJSを載せる（レイアウトActionの入れ子） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §4.5 |
| 移した機能を起動するボタンにアイコンを付ける（スクロールでラベルが隠れる） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §4.1.3 |
| 同じ判定を複数のCommandに持たせる（起動時と実行時で結果が食い違うのを防ぐ） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §10.6 |
| SFの数式・ロールアップ・レコードID順のソートを画面側で再現する | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §5 |
| Commandを書いたら原因の見えない500になる（クラス名・メソッド名・パッケージが違う） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §3 |
| Commandのscriptを直したのに反映されない（WebApiがCommandを抱え込む） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §3 |
| 応答が空のHTTP 500になる（responseResultsのキーを1つもsetしていない） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §3 |
| ホーム（トップView）のパーツへ検索結果の一覧を埋め込む（列の出所・タブ押下時に読む・横展開の広げ方） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11 |
| 中身のないタブを先頭に置いて最初に開く（番号で覚えた設定のずれ・先頭固定で外す5か所） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11.4 |
| タブの状態で他のトップViewパーツを出し入れする（列ごと隠す・描き直しで戻る・掴む目印） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11.5 |
| 一覧の行から詳細をダイアログで開く（製品のMDetailDialogを呼ぶ順・close:dialogは親で受ける） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11.6 |
| 一覧に新規・フィルター・編集/削除・一括編集が要る（自前で育てる前に製品の検索Viewを載せる） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11.7 |
| 一括更新のボタンが出ない（buttonConfig と useBulkView） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11.7 |
| HTMLのパーツのDOMへVueの部品を描き込む（Teleportと器のidの受け渡し） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11.7 |
| パーツをVue SFCで書いて製品のコンポーネントを使う（非同期マウント・投入前の検査が効かない） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §11.6 |
| 重ねたパネル（モーダル）のボタンが上下の固定バーに隠れる／パネルの高さの決め方 | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §4.1.1 |
| 埋め込んだ画面の入力欄が背景と同化する／プルダウンに枠も矢印も出ない／未選択の選択肢の出し方 | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §4.1.2 |
| SFのフローをiPLAssへ移植する（型ごとの移行先の判定・対になるフローの探し方） | [converting-salesforce-flows-to-iplass](converting-salesforce-flows-to-iplass) |
| スケジュール実行を組む（ScheduledTask定義の形・Cron・実行ユーザー・予定日時の受け取り） | [converting-salesforce-flows-to-iplass/SKILL.md](converting-salesforce-flows-to-iplass/SKILL.md) §3・§4 |
| 定義を投入したのにスケジュールが実行されない（有効化が別操作・キューの設定） | [converting-salesforce-flows-to-iplass/SKILL.md](converting-salesforce-flows-to-iplass/SKILL.md) §3 |
| SFのレコードトリガフローをEventListenerで表す（IsChangedの判定・重複チェック） | [converting-salesforce-flows-to-iplass/SKILL.md](converting-salesforce-flows-to-iplass/SKILL.md) §5 |
| SFのフィルタ条件をEQLへ移す（積み上げ集計項目・BOOLEANのnull・選択リスト） | [converting-salesforce-flows-to-iplass/SKILL.md](converting-salesforce-flows-to-iplass/SKILL.md) §6 |
| バッチを手で流して検証する（対象0件で終えない・触ったデータの戻し方・CRUD APIの制約） | [converting-salesforce-flows-to-iplass/SKILL.md](converting-salesforce-flows-to-iplass/SKILL.md) §7 |
| SFのPDF帳票をiPLAssへ移植する（帳票Templateを使わない構成・投入する定義の組） | [converting-salesforce-reports-to-iplass](converting-salesforce-reports-to-iplass) |
| JRXMLを書く（JasperReports 7系の書き方・6系との違い・要素の重なり順） | [converting-salesforce-reports-to-iplass/SKILL.md](converting-salesforce-reports-to-iplass/SKILL.md) §2 |
| 帳票へ値を渡す（パラメータが自動で渡らないこと・データソースへの寄せ方） | [converting-salesforce-reports-to-iplass/SKILL.md](converting-salesforce-reports-to-iplass/SKILL.md) §3 |
| 帳票が「このファイルを開くことができません」だけで失敗する／原因が読めない | [converting-salesforce-reports-to-iplass/SKILL.md](converting-salesforce-reports-to-iplass/SKILL.md) §4・§7 |
| お手本のPDFからロゴを取り出してJRXMLへ埋め込む | [converting-salesforce-reports-to-iplass/SKILL.md](converting-salesforce-reports-to-iplass/SKILL.md) §5 |
| 生成したPDFをレコードの添付ファイル項目へ保存する（履歴・多重度の上限） | [converting-salesforce-reports-to-iplass/SKILL.md](converting-salesforce-reports-to-iplass/SKILL.md) §6 |
| 前方一致で検索する（ワイルドカードが素通りする書き方を避ける） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §3 |
| 画面が `undefined` を踏む（応答にキーが無い） | [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) §3 |
| 保留（今はできないこと）の置き場と扱いを決める／複数人で並行して移行する | [coordinating-migration-work](coordinating-migration-work) |
| 解除できる状態になったEntityの保留を洗い出す | [scripts/sf-to-iplass/detect-holds.js](../../scripts/sf-to-iplass/detect-holds.js)（種類は [converting-salesforce-to-iplass-entity/SKILL.md](converting-salesforce-to-iplass-entity/SKILL.md) §7） |
| スキルやリファレンスを新しく作る／追記する／分割・再編する | [writing-project-skills](writing-project-skills) |
| スキル配下の md が記述規約を守っているか調べる | [scripts/docs-lint.mjs](../../scripts/docs-lint.mjs) |
| EQLの関数・文法が分からない（日付・文字列・集約の関数の可否） | `iplass-dev:iplass-query`。この環境で通らないと分かっている書き方は [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) §8 |
| iPLAssの仕様・JSON形状・EQL文法の一次情報が必要 | `iplass-dev` プラグインの各スキル（下表） |
| プラグインのスキルに書かれていない公式仕様が必要 | [docs/iplass-official/](../../docs/iplass-official/)（Webより先にここを見る。「公式ドキュメント」節） |
| 公式ドキュメントに書かれていない事実に作業中に気づいた | [writing-project-skills/SKILL.md](writing-project-skills/SKILL.md) §11 |

## スキル

| ファイル | 行数 | 責務 |
|---|---|---|
| [iplass-definition-io/SKILL.md](iplass-definition-io/SKILL.md) | 332 | iPLAss定義の取得・編集・照合。経路の選択、書き込み規則、メタデータ種別ごとの定義パス（mdc View・通知系のテンプレート・テナントを含む）、接頭辞が複数セグメントになる種別、全置換の作法、サイズ上限、型変更の可否、View全置換の`propertyName`欠落対策、理由の返らない400（入れ子の`@class`欠落）、未知のキーが黙って落ちること、定義のプロパティ仕様をソースから調べる手順 |
| [iplass-entity-crud-api/SKILL.md](iplass-entity-crud-api/SKILL.md) | 164 | Entity CRUD API（`api/mtp/entity`）でのレコード操作。権限定義（EntityWebApi）、メソッドごとの送信形式、型ごとの値の書き方、操作オプション、成否の読み方、検索条件の文字コード、検証手順 |
| [coordinating-migration-work/SKILL.md](coordinating-migration-work/SKILL.md) | 60 | 移行作業の運用。保留の置き場と申し送りの書式、検出と更新の境界、並行作業（メタデータ種別に依らない） |
| [converting-salesforce-to-iplass-entity/SKILL.md](converting-salesforce-to-iplass-entity/SKILL.md) | 240 | SF→Entity 変換ワークフロー。新規作成と既存更新の2系統、Entity固有の保留の種類、多重度の決め方 |
| [converting-salesforce-to-iplass-entity/references/property-mapping.md](converting-salesforce-to-iplass-entity/references/property-mapping.md) | 725 | SF項目の型・属性 → iPLAssプロパティ／バリデーションの対応表、全Entity共通の定型プロパティ、参照関係の付随属性 |
| [converting-salesforce-to-iplass-entity/references/validation-rule-mapping.md](converting-salesforce-to-iplass-entity/references/validation-rule-mapping.md) | 109 | SFの入力規則 → iPLAssのValidator／EventListenerへの振り分け（手書きのリスナ・Validatorの置き場も） |
| [converting-salesforce-screens-to-iplass/SKILL.md](converting-salesforce-screens-to-iplass/SKILL.md) | 755 | SF独自画面（LWCと画面フローの両方）→iPLAss画面の移植。画面フローの読み方と写し方（§10）、レコードの全項目コピーの除外規則、確認の作り方、通知（メール）の受け皿と送るタイミング、送る仕掛けを載せずに内容をレコードとして残す形、アプリ内通知の受け皿の作り方、実データが揃わない判定の緩和、MDC全画面で動くJSの載せ方（レイアウトActionの入れ子）、宣言的画面で足りるかの判定、段階分け、移植先の構成（テンプレートセクション＋Vue SFCが既定）、MDC詳細画面への埋め込み、重ねるパネルの高さの決め方、入力部品の見た目（埋め込み先のCSSに乗らない）、応答からnullのキーが落ちること、原因の見えない500になるクラス名・メソッド名、SFロジックの写し方、別タブで開く単独ページ（§4.4）、SFの見た目の写し方と測り方、タブで構成された画面の再現 |
| [converting-salesforce-layout-to-iplass-view/SKILL.md](converting-salesforce-layout-to-iplass-view/SKILL.md) | 693 | SFページレイアウト → mdc View 変換ワークフロー。セクションの並びと種別・ラベル、`collapsible`等を`false`にすると画面が空になること、behaviorと`displayType`の既定、文字数制限・日時の書式・ヒント・初期値の出所、数式の入れ子editor、関連リスト（被参照Reference＋大量データ参照セクションの表示列）、添付、検索View（検索条件の範囲と並び順・検索レイアウトからの表示列）、参照項目の絞り込み（SFの参照フィルタ→選択フィルターの検索条件）、サイドメニュー（EntityItemとSideMenuTreeの役割分担・名前と配置）、投入後の照合と画面確認（画面のURL）、同じEntityへの別Viewの追加（バックアップ起点での追加） |
| [converting-salesforce-flows-to-iplass/SKILL.md](converting-salesforce-flows-to-iplass/SKILL.md) | 222 | SFのフロー→iPLAssの移植。型ごとの移行先の判定（ScheduledTask / EventListener / 画面）、移す前に確かめる3点（`status`・対になるフロー・未参照の数式）、ScheduledTask定義の形とCron・実行ユーザー・有効化が別操作であること・キューの設定、処理本体のCommand（フロー要素との対応・1件ずつのトランザクション・予定日時からの基準日）、EventListener（`IsChanged`の判定順・被参照を読まない設定・SFに無い重複チェック・独自Nameプロパティ）、フィルタ条件の移し方（積み上げ集計項目・BOOLEANのnull・選択リスト）、検証（対象0件で終えない・触ったデータの戻し方・Entity CRUD APIの制約） |
| [writing-project-skills/SKILL.md](writing-project-skills/SKILL.md) | 127 | このリポジトリのスキルの書き方。責務の切り分け、定義位置、抽象度、確かめ方、再編の手順、公式ドキュメントに無い事実の追記（GUIの設定項目 → 定義APIのJSONの読み替えを含む） |
| [converting-salesforce-reports-to-iplass/SKILL.md](converting-salesforce-reports-to-iplass/SKILL.md) | 247 | SFのPDF帳票→iPLAssの移植。帳票Templateを使わない構成（JRXMLをテンプレート定義に持ち、CommandでPDFを作りStreamで流す）、JasperReports 7系のJRXMLの書き方と6系との違い、値の渡し方（パラメータが自動で渡らないためデータソースへ寄せる）、手元で同じ版を動かす検証、ロゴの取り出しと埋め込み、生成物の添付ファイルへの保存、症状から原因への表 |

`iplass-dev` プラグインのスキルは iPLAss 側の一次情報を担う。役割の切り分けは次のとおり。

| 参照先 | 担当 |
|---|---|
| `iplass-dev:iplass-metadata` | Entity定義・SelectValue・View 等のJSON形状、型セグメント、CRUDの規約 |
| `iplass-dev:iplass-entity` | プロパティ型ごとの扱い（型・多重度・索引の可否） |
| `iplass-dev:iplass-query` | EQL（Entity Query Language / Value Expression）の文法 |
| `iplass-dev:iplass-docs` | 上記で不明な公式仕様（開発ガイド / service-config / Javadoc） |
| [iplass-definition-io](iplass-definition-io)（本リポジトリ） | この環境で定義を安全に読み書きする作法 |

## 公式ドキュメント

iPLAss の公式ドキュメントを [docs/iplass-official/](../../docs/iplass-official/) に置いている。**上表のスキルで足りないときは、Webを取得する前にここを検索する**（`Grep` で全文を引ける。ローカルに無い版の記述が必要なときだけ `iplass-dev:iplass-docs` からWebを取得する）。

| 探すもの | 場所 |
|---|---|
| mdc View（詳細View・検索View・サイドメニュー）の仕様 | [docs/iplass-official/developerguide/materialdesigncomponents/](../../docs/iplass-official/developerguide/materialdesigncomponents/) |
| Entity・GEM・WebApi・Workflow・集計・データ管理の開発ガイド | [docs/iplass-official/developerguide/](../../docs/iplass-official/developerguide/) |
| service-config の設定項目 | [docs/iplass-official/serviceconfig/](../../docs/iplass-official/serviceconfig/) |
| EQL の文法 | [docs/iplass-official/eqlreference/](../../docs/iplass-official/eqlreference/) |
| Java API のクラス・メソッド（Groovyのリスナやスクリプトを書くとき） | [docs/iplass-official/javadoc/org/](../../docs/iplass-official/javadoc/org/) |
| フロントエンド JS/TS SDK の型 | [docs/iplass-official/typedoc/](../../docs/iplass-official/typedoc/) |
| 構築手順・チュートリアル・サンプルアプリ | [docs/iplass-official/gettingstarted/](../../docs/iplass-official/gettingstarted/) と [sample/](../../docs/iplass-official/sample/) |
| 動作環境・対応バージョン | [docs/iplass-official/environment/](../../docs/iplass-official/environment/) |

本文のHTMLだけを残しており、画面キャプチャと装飾用のJS・CSSは含まない。手順の図で説明されていた箇所は本文から読み取れないことがあるので、その場合は画面を実機で確認する。

読むときの前提が1つある。**公式ドキュメントの設定手順は管理コンソール(GUI)での操作で書かれており、同じ設定を定義APIで投入するときのJSONの形は書かれていない。**このプロジェクトは定義APIとMCPで投入するので、GUIの手順を読んだらJSONへの読み替えが必要になる。読み替えの手がかりは `iplass-dev:iplass-metadata`（JSON形状）と [iplass-definition-io](iplass-definition-io)（この環境での書き込み作法）にある。

**公式ドキュメントに書かれていない事実（GUIの設定項目に対応するJSONのキーを含む）に作業中に気づいたら、スキルへ追記する。** 追記先の決め方と書き方は [writing-project-skills/SKILL.md](writing-project-skills/SKILL.md) §11 が定義位置。

## ツール

| パス | 用途 |
|---|---|
| [scripts/iplass/mtp-def.sh](../../scripts/iplass/mtp-def.sh) | メタデータ定義APIのラッパー。`get` / `list` / `post` / `put` / `delete` |
| [scripts/iplass/mtp-entity.sh](../../scripts/iplass/mtp-entity.sh) | Entity CRUD APIのラッパー。`load` / `search` / `query` / `insert` / `update` / `delete` |
| [scripts/sf-to-iplass/index.js](../../scripts/sf-to-iplass/index.js) | SFメタデータから EntityDefinition を新規生成する |
| [scripts/sf-to-iplass/apply-validation-rules.js](../../scripts/sf-to-iplass/apply-validation-rules.js) | live 定義を土台に入力規則と手書きValidatorのデルタを当てる |
| [scripts/sf-to-iplass/detect-holds.js](../../scripts/sf-to-iplass/detect-holds.js) | live 定義とSF原本を突き合わせて保留の状態を検出する（解除可能／待ち） |
| [scripts/sf-to-iplass/related-lists.js](../../scripts/sf-to-iplass/related-lists.js) | SFの関連リストを子Entityと参照プロパティへ解決する（View側とEntity側で共有） |
| [scripts/sf-to-iplass/apply-reverse-references.js](../../scripts/sf-to-iplass/apply-reverse-references.js) | 関連リスト用の被参照Reference（mappedBy）を親Entityへ足す |
| [scripts/sf-to-iplass/view/convert.js](../../scripts/sf-to-iplass/view/convert.js) | SFページレイアウトから詳細View・検索View・サイドメニュー（EntityItemとSideMenuTree）を組む（主要情報・関連リスト・添付・参照項目の絞り込みを含む。live の取得結果が必須） |
| [scripts/sf-to-iplass/view/build-copyjob-dialog.js](../../scripts/sf-to-iplass/view/build-copyjob-dialog.js) | 詳細画面のボタンから開く入力ダイアログ（テンプレートセクション＋Vue SFC）と、その起動情報Command・WebApiの定義を組む（liveのView定義が必須） |
| [scripts/sf-to-iplass/batch/build-daily-report-bulk.js](../../scripts/sf-to-iplass/batch/build-daily-report-bulk.js) | バッチのCommand・ScheduledTask・検証用WebApiのペイロードを組む（Groovyは `batch/assets/` の正本を読む） |
| [scripts/sf-to-iplass/batch/apply-daily-report-listener.js](../../scripts/sf-to-iplass/batch/apply-daily-report-listener.js) | liveのEntity定義を土台に `eventListenerList` のデルタだけを当てる |
| [scripts/iplass/mtp-api.sh](../../scripts/iplass/mtp-api.sh) | 自作WebApi（`api/<WebApi名>`）を叩く。`get` のみ |
| [scripts/sf-to-iplass/report/build-quotation-jrxml.js](../../scripts/sf-to-iplass/report/build-quotation-jrxml.js) | 帳票のJRXMLを作る（ロゴの埋め込みと、6系の書き方から7系への変換を通す） |
| [scripts/sf-to-iplass/report/tools/RenderJrxml.java](../../scripts/sf-to-iplass/report/tools/RenderJrxml.java) | JRXMLを手元で読み込み・コンパイル・差し込み・PDF化する（1ページ目のPNGも出せる） |
| [scripts/sf-to-iplass/report/tools/extract-pdf-image.js](../../scripts/sf-to-iplass/report/tools/extract-pdf-image.js) | PDFの中の画像を取り出してPNGにする（お手本からのロゴの切り出し） |
| [scripts/docs-lint.mjs](../../scripts/docs-lint.mjs) | スキル配下の md の記述規約（禁止表現・固有名詞・リンク切れ）を検査する |

各ツールの使い方は [scripts/iplass/README.md](../../scripts/iplass/README.md)、[scripts/sf-to-iplass/README.md](../../scripts/sf-to-iplass/README.md)、[scripts/sf-to-iplass/report/README.md](../../scripts/sf-to-iplass/report/README.md) にまとめる。

## 生成物

[work/](../../work/)（Git管理外）に集約する。ツールの出力、live定義の取得結果、保留台帳、手書きValidatorの宣言とGroovy本文が入る。**正式な資産は環境のメタデータそのもの**なので、生成物はリポジトリで管理しない。消しても live 取得と変換をやり直せば揃う。

## 履歴

[docs/superpowers/specs/](../../docs/superpowers/specs/) に設計、[docs/superpowers/plans/](../../docs/superpowers/plans/) に実装計画がある。過去の判断の経緯を辿るとき以外は参照しない。スキルからは参照しない（経緯はスキルの責務外）。
