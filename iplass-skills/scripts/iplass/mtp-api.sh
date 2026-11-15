#!/usr/bin/env bash
# iPLAss のカスタムWebApi (api/<WebApi名>) の薄いラッパー。
#
# 目的:
#   - 接続の4点セット(社内プロキシ / 自己署名証明書 / X-Requested-With / Bearer)を隠蔽する
#   - トークンを argv に載せない(curl --config - で標準入力から渡す)
#
# 使い方:
#   mtp-api.sh get <WebApi名> [クエリ文字列] [出力ファイル]  # 省略時は標準出力
#
#   <WebApi名> は WebApi定義の name(スラッシュ区切り。例 mdc/batch/runDailyReportCreateBulk)。
#   クエリ文字列は URL へ付ける形(例 'op=start')。非ASCIIを含む値は呼び出し側で符号化する。
#
# 環境変数(いずれも .claude/settings.local.json の env で設定する):
#   MCP_AUTH_TOKEN    必須。iPLAss の Bearer トークン
#   IPLASS_HTTP_PROXY 必須。社内プロキシ
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
  printf 'header = "Accept: application/json"\n'
  printf 'header = "Authorization: Bearer %s"\n' "$MCP_AUTH_TOKEN"
}

cmd="${1:-}"
api_name="${2:-}"
[ "$cmd" = "get" ] && [ -n "$api_name" ] || usage

api_name="${api_name#/}"
url="${IPLASS_BASE_URL}/api/${api_name}"
query="${3:-}"
[ -n "$query" ] && url="${url}?${query}"

body="$(mktemp)"
trap 'rm -f "$body"' EXIT

code="$(curl_config | curl --config - -o "$body" -w '%{http_code}' "$url")"

case "$code" in
  2??) ;;
  *)
    echo "HTTP $code : $cmd $api_name" >&2
    [ -s "$body" ] && head -c 2000 "$body" >&2
    exit 1
    ;;
esac

out="${4:-}"
if [ -n "$out" ]; then
  cp "$body" "$out"
  echo "HTTP $code  ->  $out  ($(wc -c < "$body" | tr -d ' ') bytes)"
else
  cat "$body"
fi
