# DefyxVPN CLI

`defyxvpn-cli` is a headless Linux client for DefyxVPN. It calls the same
DXcore shared library as the Flutter desktop application, but it does not link
Flutter, GTK, AppIndicator, Firebase, or any display-server libraries.

The client stays in the foreground, which makes it suitable for SSH sessions,
containers, and service managers such as systemd. `SIGINT` and `SIGTERM`
gracefully stop DXcore before the process exits.

## Current networking mode

The Linux DXcore integration exposes a SOCKS5 proxy at `127.0.0.1:5000`.
This matches the existing Linux desktop client and is the CLI default. The CLI
does not create a TUN interface or silently edit system-wide proxy settings.

Applications must use the proxy explicitly:

```bash
curl --proxy socks5h://127.0.0.1:5000 https://ifconfig.me
```

For a shell or service whose software honors proxy environment variables:

```bash
export ALL_PROXY=socks5h://127.0.0.1:5000
export all_proxy="$ALL_PROXY"
```

### Listening on another address or port

DXcore's own endpoint is fixed, so the CLI includes a TCP relay for exposing
it on a different local address or port:

```bash
./defyxvpn-cli connect --listen-address 0.0.0.0 --listen-port 1080
```

Clients on another machine then use the server's real address, for example
`socks5h://192.168.1.138:1080`, rather than the wildcard address
`0.0.0.0`.

The SOCKS5 endpoint does not provide user authentication. Binding to
`0.0.0.0`, `::`, or another non-loopback address can expose the proxy to the
network. Restrict the port to trusted source addresses with the host or
network firewall.

`0.0.0.0:5000` is not available because it overlaps DXcore's internal
`127.0.0.1:5000` listener. Use another port with a wildcard address. A
specific non-loopback IP, such as `192.168.1.138:5000`, does not overlap and
can use port `5000`.

## Build

Requirements:

- Linux and a C++17 compiler
- CMake 3.13 or newer
- `pkg-config`
- json-c development headers
- An x86_64 DXcore shared library named `libdxcore_amd64.so`

Prebuilt release archives only require the json-c runtime library
(`libjson-c5` on current Debian and Ubuntu releases); they do not require a
compiler, CMake, Flutter, or GTK. The optional `--health-check` mode also
requires the `curl` command.

On Debian or Ubuntu:

```bash
sudo apt-get install build-essential cmake ninja-build pkg-config libjson-c-dev
cmake -S linux/cli -B build/linux-cli -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DDEFYX_DXCORE_LIB=/path/to/libdxcore_amd64.so
cmake --build build/linux-cli
ctest --test-dir build/linux-cli --output-on-failure
```

The binary and DXcore library are written to `build/linux-cli/bin/`. The
production DefyxVPN release workflow supplies the private production DXcore
binary. Contributors can still build and run all CLI unit tests without it by
omitting `DEFYX_DXCORE_LIB`.

## Usage

Start a connection in the foreground:

```bash
./defyxvpn-cli connect
```

By default, the CLI requests the online flowline from DXcore and falls back to
its cached copy. When `--pattern` is omitted, it uses the enabled flowline
labels in their published order, matching the desktop client. It can also
consume a signed offline export, a complete flowline API response, or a raw
`flowLine` object:

```bash
./defyxvpn-cli connect \
  --flowline-file /etc/defyxvpn/flowline.json \
  --pattern "Warp,Psiphon" \
  --listen-address 127.0.0.1 \
  --listen-port 5000 \
  --health-check
```

Inspect or stop a process from another terminal:

```bash
./defyxvpn-cli status
./defyxvpn-cli disconnect
```

When using a non-default cache directory, pass the same `--cache-dir` to all
three commands. Only one connection process can use a cache directory at a
time.

Run `defyxvpn-cli --help` for every option and its environment-variable
equivalent.

### Connection health checks

DXcore can report a method as connected even when that route cannot complete
normal HTTPS transfers. With `--health-check`, the CLI starts the
comma-separated connection methods one at a time and validates each method
through DXcore's SOCKS5 endpoint. It reports the public proxy as connected
only after the validation transfer completes:

```bash
./defyxvpn-cli connect \
  --pattern "Hive,Xray,Outline,Masque" \
  --health-check
```

The default probe downloads exactly 64 KiB over HTTPS from
`https://speed.cloudflare.com/__down?bytes=65536`. A truncated response,
TLS failure, non-2xx status, timeout, or smaller download rejects that method
and advances to the next label. This is a startup validation; DXcore's own
runtime health monitor remains enabled after a method passes.

Networks that cannot reach the default endpoint can use another deterministic
HTTPS response:

```bash
./defyxvpn-cli connect \
  --health-check \
  --health-check-url https://example.net/health.bin \
  --health-check-min-bytes 65536 \
  --health-check-timeout 30
```

The probe runs `curl` directly without a shell, forces remote DNS through the
SOCKS5 proxy, follows HTTPS redirects only, and uses the operating system's
normal CA certificate store.

## systemd

The files `defyxvpn-cli.service` and `defyxvpn-cli.env.example` provide a
starting point for a system service. A minimal installation looks like:

```bash
sudo useradd --system --home /var/lib/defyxvpn --create-home defyxvpn
sudo install -d -m 0755 /opt/defyxvpn /etc/defyxvpn
sudo install -m 0755 defyxvpn-cli /opt/defyxvpn/
sudo install -m 0644 libdxcore_amd64.so /opt/defyxvpn/
sudo install -m 0600 defyxvpn-cli.env.example /etc/defyxvpn/defyxvpn.env
sudo install -m 0644 defyxvpn-cli.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now defyxvpn-cli
```

Follow connection progress with:

```bash
sudo journalctl -u defyxvpn-cli -f
```

Keep offline flowline files and `/etc/defyxvpn/defyxvpn.env` readable only by
the service administrator and service account.

## Exit codes

- `0`: command completed or the foreground connection shut down cleanly
- `1`: invalid command-line arguments
- `2`: configuration, file, lock, or DXcore startup error
- `3`: no running CLI instance
- `4`: connection failure or timeout
