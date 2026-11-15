#!/usr/bin/env bash
# iPLAss メタデータCRUD API (api/mtp/definition) の薄いラッパー。
#
# 目的:
#   - 接続の4点セット(社内プロキシ / 自己署名証明書 / X-Requested-With / Bearer)を隠蔽する
#   - トークンを argv に載せない(curl --config - で標準入力から渡す)
#
# 使い方:
#   mtp-def.sh get    <定義パス> [出力ファイル]   # 省略時は標準出力
#   mtp-def.sh list   <定義パス(末尾/)> [出力ファイル]  # recursive=true 付きで一覧
#   mtp-def.sh post   <定義パス> <payload.json>   # 新規作成
#   mtp-def.sh put    <定義パス> <payload.json>   # 更新(全置換)
#   mtp-def.sh delete <定義パス>                  # 削除
#
#   payload.json は「定義オブジェクトそのまま」。{"definition":{...}} でラップしない。
#
# 環境変数(いずれも .claude/settings.local.json の env で設定する。
#            settings.local.json は gitignore 済みで、社内固有の情報をコミットしないため):
#   MCP_AUTH_TOKEN    必須。iPLAss の Bearer トークン
#   IPLASS_HTTP_PROXY 必須。社内プロキシ (例 http://<プロキシホスト>:8080)
#   IPLASS_BASE_URL   任意。既定 https://52.197.236.243/iplass-ee-skeleton/kenkyudev
#
# 雛形は .claude/settings.local.sample.json を参照。
set -euo pipefail

: "${IPLASS_BASE_URL:=https://52.197.236.243/iplass-ee-skeleton/kenkyudev}"

for v in MCP_AUTH_TOKEN IPLASS_HTTP_PROXY; do
  eval "val=\${$v:-}"
  if [ -z "$val" ]; then
    echo "$v が未設定です (.claude/settings.local.json の env で設定してください。雛形: .claude/settings.local.sample.json)" >&2
    exit 2
  fi
done

usage() {
  # 先頭のコメントブロック(使い方)をそのまま表示する
  sed -n '/^# 使い方:/,/^# 雛形/p' "$0" >&2
  exit 2
}

# curl の共通オプションを標準入力から渡す。トークンが argv に出ないようにするため。
curl_config() {
  printf 'proxy = "%s"\n' "$IPLASS_HTTP_PROXY"
  printf 'insecure\n'
  printf 'silent\n'
  printf 'show-error\n'
  printf 'header = "X-Requested-With: XMLHttpRequest"\n'
  printf 'header = "Authorization: Bearer %s"\n' "$MCP_AUTH_TOKEN"
}

cmd="${1:-}"
def_path="${2:-}"
[ -n "$cmd" ] && [ -n "$def_path" ] || usage

# 先頭スラッシュの有無を吸収する
def_path="${def_path#/}"
url="${IPLASS_BASE_URL}/api/mtp/definition/${def_path}"

# 応答本体は一旦テンポラリに落とし、HTTPステータスで成否を判定する
body="$(mktemp)"
trap 'rm -f "$body"' EXIT

run_curl() {
  curl_config | curl --config - -o "$body" -w '%{http_code}' "$@"
}

case "$cmd" in
  get)
    code="$(run_curl "$url")"
    out="${3:-}"
    ;;
  list)
    case "$def_path" in
      */) ;;
      *) echo "list は末尾がスラッシュの定義パスを指定してください (例: entity/)" >&2; exit 2 ;;
    esac
    code="$(run_curl "${url}?recursive=true")"
    out="${3:-}"
    ;;
  post | put)
    payload="${3:-}"
    [ -n "$payload" ] || usage
    [ -f "$payload" ] || { echo "payload が見つかりません: $payload" >&2; exit 2; }
    method="$(echo "$cmd" | tr '[:lower:]' '[:upper:]')"
    code="$(run_curl -X "$method" -H 'Content-Type: application/json' --data-binary "@$payload" "$url")"
    out=""
    ;;
  delete)
    code="$(run_curl -X DELETE "$url")"
    out=""
    ;;
  *)
    usage
    ;;
esac

case "$code" in
  2??) ;;
  *)
    echo "HTTP $code : $cmd $def_path" >&2
    # エラー時は本体が空のことが多いが、あれば出す
    [ -s "$body" ] && head -c 2000 "$body" >&2
    exit 1
    ;;
esac

if [ -n "$out" ]; then
  cp "$body" "$out"
  echo "HTTP $code  ->  $out  ($(wc -c < "$body" | tr -d ' ') bytes)"
else
  cat "$body"
  echo
fi
