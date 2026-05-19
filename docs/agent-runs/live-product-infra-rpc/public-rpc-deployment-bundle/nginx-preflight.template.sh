#!/usr/bin/env bash
set -euo pipefail

rendered_conf="<FLOWCHAIN_RPC_NGINX_RENDERED_CONF>"
public_host="<FLOWCHAIN_RPC_PUBLIC_HOST>"
public_url="<FLOWCHAIN_RPC_PUBLIC_URL>"
allowed_origin="<FLOWCHAIN_RPC_ALLOWED_ORIGIN>"
disallowed_origin="<FLOWCHAIN_RPC_DISALLOWED_ORIGIN>"

test -n "${rendered_conf}"
test -n "${public_host}"
test -n "${public_url}"
test -n "${allowed_origin}"
test -n "${disallowed_origin}"
test -f "${rendered_conf}"

case "${public_url}" in
  https://*) ;;
  *) echo "FLOWCHAIN_RPC_PUBLIC_URL must be https"; exit 1 ;;
esac

if grep -Eq '<(FLOWCHAIN_|PATH_TO_TLS_)' "${rendered_conf}"; then
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
disallowed_body="$(mktemp)"
broad_state_body="$(mktemp)"
tester_unauth_body="$(mktemp)"
private_wallet_body="$(mktemp)"
trap 'rm -f "${disallowed_body}" "${broad_state_body}" "${tester_unauth_body}" "${private_wallet_body}"' EXIT
disallowed_status="$(curl -sS -o "${disallowed_body}" -w "%{http_code}" --max-time 10 -H "Origin: ${disallowed_origin}" "${public_url%/}/rpc/readiness")"
test "${disallowed_status}" = "403"
broad_state_status="$(curl -sS -o "${broad_state_body}" -w "%{http_code}" --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/devnet/local/state.json")"
test "${broad_state_status}" = "404"
private_wallet_status="$(curl -sS -o "${private_wallet_body}" -w "%{http_code}" --max-time 10 -H "Origin: ${allowed_origin}" -H "Content-Type: application/json" --data '{}' "${public_url%/}/wallets/create")"
test "${private_wallet_status}" = "404"
curl -fsS --max-time 10 -H "Origin: ${allowed_origin}" "${public_url%/}/tester/status" >/dev/null
tester_unauth_status="$(curl -sS -o "${tester_unauth_body}" -w "%{http_code}" --max-time 10 -H "Origin: ${allowed_origin}" -H "Content-Type: application/json" --data '{}' "${public_url%/}/tester/wallets/create")"
test "${tester_unauth_status}" = "401"
grep -Fq "flowmemory.control_plane.tester_write_auth_required.v0" "${tester_unauth_body}"

echo "FlowChain public RPC Nginx preflight passed."
