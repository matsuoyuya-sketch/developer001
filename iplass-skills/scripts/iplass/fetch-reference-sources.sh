#!/usr/bin/env bash
# iPLAss本体のソースを参照用にローカルへ投入する。
#
# 目的:
#   - メタデータ定義のプロパティ仕様(JSONのキー・許容値・既定値)を、公式ドキュメントや
#     javadocに載っていない分までソースから引けるようにする
#   - 有償版のソースはGit管理できないため、各自の環境で同じ構成を再現できるようにする
#
# 使い方:
#   fetch-reference-sources.sh [バージョン]      # 既定は下記 DEFAULT_VERSION
#
# 投入先(いずれもGit管理外。実体パスは CLAUDE.md の固有値表が定義位置):
#   <ソース参照ディレクトリ>/iplass-ee-src-<版>/     Java側(Mavenのsources jarを展開)
#   <ソース参照ディレクトリ>/iplass-mdc-<版>-vue/    フロント側(npmパッケージのソースマップから復元)
#
# 環境変数(いずれも .claude/settings.local.json の env で設定する。
#            settings.local.json は gitignore 済みで、社内固有の情報をコミットしないため):
#   IPLASS_HTTP_PROXY     必須。社内プロキシ (例 http://<プロキシホスト>:8080)
#   IPLASS_NEXUS_USER     Nexus(有償版の配布サーバ)のユーザ名
#   IPLASS_NEXUS_PASSWORD Nexusのパスワード
#
# 雛形は .claude/settings.local.sample.json を参照。
# 資格情報は有償版の契約時に配布されるもの。
set -euo pipefail

DEFAULT_VERSION=4.1.1
VERSION="${1:-$DEFAULT_VERSION}"

MAVEN_REPO=https://iplass.org/nexus/repository/jars
NPM_REPO=https://iplass.org/nexus/repository/npm
# Java側。sources jar が空のもの(admin-mdc)は含めない
MAVEN_MODULES="iplass-ee-mdc iplass-ee-core iplass-ee-gem iplass-ee-web iplass-ee-admin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEST_ROOT="$REPO_ROOT/reference"

for v in IPLASS_HTTP_PROXY IPLASS_NEXUS_USER IPLASS_NEXUS_PASSWORD; do
  eval "val=\${$v:-}"
  if [ -z "$val" ]; then
    echo "$v が未設定です (.claude/settings.local.json の env で設定してください。雛形: .claude/settings.local.sample.json)" >&2
    echo "設定した直後は起動中のセッションに反映されません。セッションを開き直してください。" >&2
    exit 2
  fi
done
USER_NAME="$IPLASS_NEXUS_USER"
PASSWORD="$IPLASS_NEXUS_PASSWORD"

fetch() {
  # fetch <URL> <出力ファイル>
  curl -sfS --max-time 600 -x "$IPLASS_HTTP_PROXY" -u "$USER_NAME:$PASSWORD" -o "$2" "$1"
}

# ---- Java側: Mavenのsources jarを展開 ----
JAVA_DEST="$DEST_ROOT/iplass-ee-src-$VERSION"
mkdir -p "$JAVA_DEST/_jars"
for m in $MAVEN_MODULES; do
  jar="$JAVA_DEST/_jars/$m-$VERSION-sources.jar"
  fetch "$MAVEN_REPO/org/iplass/ee/$m/$VERSION/$m-$VERSION-sources.jar" "$jar"
  out="$JAVA_DEST/${m#iplass-ee-}"
  mkdir -p "$out"
  unzip -q -o "$jar" -d "$out"
  echo "$m: $(find "$out" -name '*.java' | wc -l) java files"
done

# ---- フロント側: npmパッケージのソースマップから復元 ----
VUE_DEST="$DEST_ROOT/iplass-mdc-$VERSION-vue"
mkdir -p "$VUE_DEST/_tgz"
tgz="$VUE_DEST/_tgz/iplass-mdc-$VERSION.tgz"
fetch "$NPM_REPO/@iplass/iplass-mdc/-/iplass-mdc-$VERSION.tgz" "$tgz"
work="$VUE_DEST/_tgz/unpacked"
rm -rf "$work"
mkdir -p "$work"
tar -xzf "$tgz" -C "$work"
node "$SCRIPT_DIR/extract-sourcemap.mjs" "$work/package/dist/lib/iplass-mdc.js.map" "$VUE_DEST"
mkdir -p "$VUE_DEST/dist"
cp "$work/package/dist/lib/iplass-mdc.d.ts" "$work/package/dist/lib/iplass-mdc.css" \
   "$work/package/package.json" "$work/package/README.md" "$VUE_DEST/dist/"
rm -rf "$work"
echo "vue: $(find "$VUE_DEST/src" -name '*.vue' | wc -l) vue / $(find "$VUE_DEST/src" -name '*.ts' | wc -l) ts"
