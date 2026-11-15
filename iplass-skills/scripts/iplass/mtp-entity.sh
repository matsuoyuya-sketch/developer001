#!/usr/bin/env bash
# iPLAss Entity CRUD API (api/mtp/entity) の薄いラッパー。
#
# 目的:
#   - 接続の4点セット(社内プロキシ / 自己署名証明書 / X-Requested-With / Bearer)を隠蔽する
#   - トークンを argv に載せない(curl --config - で標準入力から渡す)
#   - メソッドと Content-Type の組み合わせ(GET/DELETE は REST_FORM、POST/PUT は REST_JSON)を固定する
#
# 使い方:
#   mtp-entity.sh load   <Entity定義名> <oid> [version] [追加クエリ]   # oid指定でロード
#   mtp-entity.sh search <Entity定義名> <filter(where句)> [追加クエリ] # filter指定で検索
#   mtp-entity.sh query  <EQL> [追加クエリ]                            # EQL指定で検索
#   mtp-entity.sh insert <Entity定義名> <entity.json> [追加クエリ]     # Insert
#   mtp-entity.sh update <Entity定義名> <oid> <entity.json> [追加クエリ] # Update
#   mtp-entity.sh delete <Entity定義名> <oid> [追加クエリ]             # Delete
#
#   <entity.json> は Entity オブジェクトそのまま(例 {"name":"foo","prop1":"bar"})。
#   {"entity":{...}} でラップしない(WebApi定義の restJsonParameterName=entity が本文全体を受ける)。
#   「追加クエリ」は URL に付けるクエリ文字列(例 'withValidation=false&countTotal=true')。
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

base="${IPLASS_BASE_URL}/api/mtp/entity"

# URL へクエリ文字列を足す(既に ? があれば & で連結する)
with_query() {
  local u="$1" q="${2:-}"
  [ -n "$q" ] || { printf '%s' "$u"; return; }
  case "$u" in
    *\?*) printf '%s&%s' "$u" "$q" ;;
    *)    printf '%s?%s' "$u" "$q" ;;
  esac
}

# 文字列をパーセント符号化する。
# curl の --data-urlencode は使わない: Windows版 curl はこのオプションの値を ANSI コードページ
# (日本語環境では CP932) へ変換するため、UTF-8 の非ASCII文字が別のバイト列で送られ、
# 検索条件が1件も一致しなくなる。LC_ALL=C でバイト単位に回して自前で符号化する。
percent_encode() {
  local s="$1" out='' i c
  local LC_ALL=C
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [A-Za-z0-9._~-]) out="${out}${c}" ;;
      *) out="${out}$(printf '%%%02X' "'$c")" ;;
    esac
  done
  printf '%s' "$out"
}

body="$(mktemp)"
trap 'rm -f "$body"' EXIT

run_curl() {
  curl_config | curl --config - -o "$body" -w '%{http_code}' "$@"
}

cmd="${1:-}"
[ -n "$cmd" ] || usage

case "$cmd" in
  load)
    ent="${2:-}"; oid="${3:-}"; [ -n "$ent" ] && [ -n "$oid" ] || usage
    ver="${4:-}"
    url="${base}/${ent}/${oid}"
    [ -n "$ver" ] && url="${url}/${ver}"
    code="$(run_curl "$(with_query "$url" "${5:-}")")"
    ;;
  search)
    ent="${2:-}"; filter="${3:-}"; [ -n "$ent" ] && [ -n "$filter" ] || usage
    url="$(with_query "${base}/${ent}" "filter=$(percent_encode "$filter")")"
    code="$(run_curl "$(with_query "$url" "${4:-}")")"
    ;;
  query)
    eql="${2:-}"; [ -n "$eql" ] || usage
    url="$(with_query "$base" "query=$(percent_encode "$eql")")"
    code="$(run_curl "$(with_query "$url" "${3:-}")")"
    ;;
  insert)
    ent="${2:-}"; payload="${3:-}"; [ -n "$ent" ] && [ -n "$payload" ] || usage
    [ -f "$payload" ] || { echo "payload が見つかりません: $payload" >&2; exit 2; }
    code="$(run_curl -X POST -H 'Content-Type: application/json' --data-binary "@$payload" \
      "$(with_query "${base}/${ent}" "${4:-}")")"
    ;;
  update)
    ent="${2:-}"; oid="${3:-}"; payload="${4:-}"
    [ -n "$ent" ] && [ -n "$oid" ] && [ -n "$payload" ] || usage
    [ -f "$payload" ] || { echo "payload が見つかりません: $payload" >&2; exit 2; }
    code="$(run_curl -X PUT -H 'Content-Type: application/json' --data-binary "@$payload" \
      "$(with_query "${base}/${ent}/${oid}" "${5:-}")")"
    ;;
  delete)
    ent="${2:-}"; oid="${3:-}"; [ -n "$ent" ] && [ -n "$oid" ] || usage
    code="$(run_curl -X DELETE "$(with_query "${base}/${ent}/${oid}" "${4:-}")")"
    ;;
  *)
    usage
    ;;
esac

case "$code" in
  2??) ;;
  *)
    echo "HTTP $code : $cmd" >&2
    [ -s "$body" ] && head -c 2000 "$body" >&2
    exit 1
    ;;
esac

cat "$body"
echo
