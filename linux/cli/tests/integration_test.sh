#!/usr/bin/env bash
set -euo pipefail

cli="$1"
core="$2"
runtime_dir="$(mktemp -d "${TMPDIR:-/tmp}/defyxvpn-cli-integration.XXXXXX")"
log_file="$runtime_dir/connect.log"
managed_cli="$runtime_dir/server-vpn"
connect_pid=""

cleanup() {
  if [[ -n "$connect_pid" ]] && kill -0 "$connect_pid" 2>/dev/null; then
    kill -TERM "$connect_pid" 2>/dev/null || true
    wait "$connect_pid" 2>/dev/null || true
  fi
  rm -rf "$runtime_dir"
}
trap cleanup EXIT

cp "$cli" "$managed_cli"

if "$managed_cli" connect \
    --core-lib "$core" \
    --cache-dir "$runtime_dir" \
    --listen-address 0.0.0.0 \
    --listen-port 5000 >"$runtime_dir/conflict.log" 2>&1; then
  echo "wildcard port 5000 should have been rejected" >&2
  exit 1
fi
grep -q "conflicts with DXcore's internal" "$runtime_dir/conflict.log"

"$managed_cli" connect \
  --core-lib "$core" \
  --cache-dir "$runtime_dir" \
  --listen-address 127.0.0.1 \
  --listen-port 18080 \
  --timeout 5 >"$log_file" 2>&1 &
connect_pid="$!"

connected=false
for _ in $(seq 1 50); do
  if "$managed_cli" status --cache-dir "$runtime_dir" 2>/dev/null |
      grep -q "State:    connected"; then
    connected=true
    break
  fi
  if ! kill -0 "$connect_pid" 2>/dev/null; then
    cat "$log_file"
    echo "connect process exited before reaching connected state" >&2
    exit 1
  fi
  sleep 0.1
done

if [[ "$connected" != true ]]; then
  cat "$log_file"
  echo "connection did not become ready" >&2
  exit 1
fi

"$managed_cli" status --cache-dir "$runtime_dir" |
  grep -q "Endpoint: socks5h://127.0.0.1:18080"
"$managed_cli" disconnect --cache-dir "$runtime_dir"
wait "$connect_pid"
connect_pid=""

grep -q "Connected. SOCKS5 proxy:" "$log_file"
grep -q "Using enabled connection methods: Mock" "$log_file"
if [[ -e "$runtime_dir/defyxvpn-cli.status.json" ]]; then
  echo "runtime status was not cleaned up" >&2
  exit 1
fi

fake_bin="$runtime_dir/bin"
method_file="$runtime_dir/current-method"
health_log="$runtime_dir/health-connect.log"
mkdir -p "$fake_bin"
cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
if [[ "$(cat "$MOCK_DXCORE_METHOD_FILE")" == "Bad" ]]; then
  printf '200 1024\n'
  exit 18
fi
printf '200 65536\n'
EOF
chmod +x "$fake_bin/curl"

PATH="$fake_bin:$PATH" MOCK_DXCORE_METHOD_FILE="$method_file" \
  "$managed_cli" connect \
    --core-lib "$core" \
    --cache-dir "$runtime_dir" \
    --pattern "Bad,Mock" \
    --listen-address 127.0.0.1 \
    --listen-port 18080 \
    --health-check \
    --health-check-url https://example.com/check \
    --timeout 5 >"$health_log" 2>&1 &
connect_pid="$!"

connected=false
for _ in $(seq 1 50); do
  if "$managed_cli" status --cache-dir "$runtime_dir" 2>/dev/null |
      grep -q "State:    connected"; then
    connected=true
    break
  fi
  if ! kill -0 "$connect_pid" 2>/dev/null; then
    cat "$health_log"
    echo "health-check process exited before failover connected" >&2
    exit 1
  fi
  sleep 0.1
done

if [[ "$connected" != true ]]; then
  cat "$health_log"
  echo "health-check failover did not become ready" >&2
  exit 1
fi

"$managed_cli" disconnect --cache-dir "$runtime_dir"
wait "$connect_pid"
connect_pid=""

grep -q "health check failed for Bad" "$health_log"
grep -q "Health check passed for Mock" "$health_log"
grep -q "Trying the next connection method" "$health_log"
