#!/usr/bin/env bash
set -euo pipefail

rendered_conf="<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"
public_host="<FLOWCHAIN_RPC_PUBLIC_HOST>"
public_url="<FLOWCHAIN_RPC_PUBLIC_URL>"
allowed_origin="<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"

test "${rendered_conf}" != "<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"
test "${public_host}" != "<FLOWCHAIN_RPC_PUBLIC_HOST>"
test "${public_url}" != "<FLOWCHAIN_RPC_PUBLIC_URL>"
test "${allowed_origin}" != "<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"
test -f "${rendered_conf}"

case "${public_url}" in
  https://*) ;;
  *) echo "FLOWCHAIN_RPC_PUBLIC_URL must be https"; exit 1 ;;
esac

if grep -Eq '<FLOWCHAIN_|<PATH_TO_TLS_' "${rendered_conf}"; then
  echo "Rendered Nginx config still contains placeholders."
  exit 1
fi

grep -Fq "server_name ${public_host};" "${rendered_conf}"
grep -Fq "proxy_pass http://127.0.0.1:8787;" "${rendered_conf}"
grep -Fq "limit_req_zone" "${rendered_conf}"
grep -Fq "limit_req zone=flowchain_rpc_per_ip" "${rendered_conf}"
grep -Fq "ssl_certificate " "${rendered_conf}"
grep -Fq "ssl_certificate_key " "${rendered_conf}"
grep -Fq 'proxy_set_header Origin $http_origin;' "${rendered_conf}"
grep -Fq 'proxy_set_header X-Forwarded-Proto https;' "${rendered_conf}"
grep -Fq 'proxy_set_header X-Forwarded-For $remote_addr;' "${rendered_conf}"

nginx -t
curl -fsS --max-time 5 "http://127.0.0.1:8787/health" >/dev/null
curl -fsS --max-time 10 "${public_url%/}/health" >/dev/null
curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/rpc/readiness" >/dev/null
curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","id":1,"method":"rpc_readiness","params":{}}' "${public_url%/}/rpc" >/dev/null

echo "FlowChain public RPC Nginx preflight passed."
