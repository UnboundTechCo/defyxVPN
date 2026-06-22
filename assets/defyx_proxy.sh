#!/usr/bin/env bash

set -u

MODE="${1:-}"
PROXY_IP="${2:-127.0.0.1}"
PROXY_PORT="${3:-5000}"
IGNORE_HOSTS="${4:-localhost,127.0.0.0/8,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12}"

log() { printf '[defyx-proxy] %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

if [[ "$MODE" != "manual" && "$MODE" != "none" ]]; then
    echo "Usage: $0 manual <ip> <port> [ignore_hosts] | none" >&2
    exit 1
fi

build_gsettings_array() {
    local input="$1" host joined hosts=()
    [[ -z "$input" ]] && { echo "[]"; return; }
    IFS=',' read -ra parts <<< "$input"
    for host in "${parts[@]}"; do
        host="${host#"${host%%[![:space:]]*}"}"
        host="${host%"${host##*[![:space:]]}"}"
        [[ -n "$host" ]] && hosts+=("$host")
    done
    [[ ${#hosts[@]} -eq 0 ]] && { echo "[]"; return; }
    printf -v joined "'%s'," "${hosts[@]}"
    echo "[${joined%,}]"
}

apply_gsettings() {
    have gsettings || return 1
    gsettings get org.gnome.system.proxy mode >/dev/null 2>&1 || return 1

    if [[ "$MODE" == "manual" ]]; then
        gsettings set org.gnome.system.proxy.socks host "$PROXY_IP"
        gsettings set org.gnome.system.proxy.socks port "$PROXY_PORT"
        for p in http https ftp; do
            gsettings set "org.gnome.system.proxy.$p" host "" 2>/dev/null
            gsettings set "org.gnome.system.proxy.$p" port 0 2>/dev/null
        done
        gsettings set org.gnome.system.proxy ignore-hosts "$(build_gsettings_array "$IGNORE_HOSTS")"
        gsettings set org.gnome.system.proxy mode 'manual'
        log "gsettings: manual SOCKS5 $PROXY_IP:$PROXY_PORT"
    else
        gsettings set org.gnome.system.proxy mode 'none'
        log "gsettings: proxy disabled"
    fi
    return 0
}

apply_kde() {
    local kw=""
    if have kwriteconfig6; then kw=kwriteconfig6
    elif have kwriteconfig5; then kw=kwriteconfig5
    else return 1; fi

    if [[ "$MODE" == "manual" ]]; then
        "$kw" --file kioslaverc --group "Proxy Settings" --key ProxyType 1
        "$kw" --file kioslaverc --group "Proxy Settings" --key socksProxy "socks://$PROXY_IP $PROXY_PORT"
        "$kw" --file kioslaverc --group "Proxy Settings" --key httpProxy  "socks://$PROXY_IP $PROXY_PORT"
        "$kw" --file kioslaverc --group "Proxy Settings" --key httpsProxy "socks://$PROXY_IP $PROXY_PORT"
        "$kw" --file kioslaverc --group "Proxy Settings" --key NoProxyFor "$IGNORE_HOSTS"
        log "KDE: manual proxy applied"
    else
        "$kw" --file kioslaverc --group "Proxy Settings" --key ProxyType 0
        log "KDE: proxy disabled"
    fi
    if have dbus-send; then
        dbus-send --type=signal /KIO/Scheduler org.kde.KIO.Scheduler.reparseSlaveConfiguration string:"" 2>/dev/null
    fi
    return 0
}

apply_xfce() {
    have xfconf-query || return 1
    xfconf-query -c xfce4-session -l >/dev/null 2>&1 || return 1

    if [[ "$MODE" == "manual" ]]; then
        for proto in Http Https Ftp; do
            xfconf-query -c xfce4-session -p "/general/Proxy${proto}Host" -n -t string -s "$PROXY_IP" 2>/dev/null \
                || xfconf-query -c xfce4-session -p "/general/Proxy${proto}Host" -s "$PROXY_IP" 2>/dev/null
            xfconf-query -c xfce4-session -p "/general/Proxy${proto}Port" -n -t int -s "$PROXY_PORT" 2>/dev/null \
                || xfconf-query -c xfce4-session -p "/general/Proxy${proto}Port" -s "$PROXY_PORT" 2>/dev/null
        done
        log "XFCE: xfconf proxy set"
    else
        for proto in Http Https Ftp; do
            xfconf-query -c xfce4-session -p "/general/Proxy${proto}Host" -r 2>/dev/null
            xfconf-query -c xfce4-session -p "/general/Proxy${proto}Port" -r 2>/dev/null
        done
        log "XFCE: xfconf proxy cleared"
    fi
    return 0
}

apply_firefox_profile() {
    local profile_dir="$1"
    [[ -d "$profile_dir" ]] || return 0
    local user_js="$profile_dir/user.js"
    local tmp="$user_js.defyx.tmp"

    if [[ -f "$user_js" ]]; then
        grep -v 'network.proxy' "$user_js" 2>/dev/null > "$tmp" 2>/dev/null || : > "$tmp"
    else
        : > "$tmp"
    fi

    if [[ "$MODE" == "manual" ]]; then
        {
            echo 'user_pref("network.proxy.type", 1);'
            echo "user_pref(\"network.proxy.socks\", \"$PROXY_IP\");"
            echo "user_pref(\"network.proxy.socks_port\", $PROXY_PORT);"
            echo 'user_pref("network.proxy.socks_version", 5);'
            echo 'user_pref("network.proxy.socks_remote_dns", true);'
        } >> "$tmp"
    else
        echo 'user_pref("network.proxy.type", 0);' >> "$tmp"
    fi
    mv "$tmp" "$user_js"
}

apply_firefox() {
    local roots=(
        "$HOME/.mozilla/firefox"
        "$HOME/snap/firefox/common/.mozilla/firefox"
        "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    )
    local found=1
    local root prof
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        for prof in "$root"/*/; do
            [[ -f "$prof/prefs.js" || -f "$prof/times.json" ]] || continue
            apply_firefox_profile "$prof"
            found=0
        done
    done
    [[ $found -eq 0 ]] && log "Firefox: proxy prefs written (restart Firefox to apply)"
    return 0
}

apply_env_proxy() {
    local socks="socks5://$PROXY_IP:$PROXY_PORT"
    if [[ "$MODE" == "manual" ]]; then
        if have dbus-update-activation-environment; then
            dbus-update-activation-environment --systemd \
                all_proxy="$socks" ALL_PROXY="$socks" \
                no_proxy="$IGNORE_HOSTS" NO_PROXY="$IGNORE_HOSTS" >/dev/null 2>&1
        fi
        if have systemctl; then
            systemctl --user set-environment \
                all_proxy="$socks" ALL_PROXY="$socks" \
                no_proxy="$IGNORE_HOSTS" NO_PROXY="$IGNORE_HOSTS" >/dev/null 2>&1
        fi
        log "env: all_proxy=$socks"
    else
        if have dbus-update-activation-environment; then
            dbus-update-activation-environment --systemd \
                all_proxy= ALL_PROXY= no_proxy= NO_PROXY= >/dev/null 2>&1
        fi
        if have systemctl; then
            systemctl --user unset-environment all_proxy ALL_PROXY no_proxy NO_PROXY >/dev/null 2>&1
        fi
        log "env: proxy variables cleared"
    fi
    return 0
}

applied=1
apply_gsettings && applied=0
apply_kde       && applied=0
apply_xfce      && applied=0
apply_env_proxy
apply_firefox

if [[ $applied -ne 0 ]]; then
    log "warning: no system proxy backend (gsettings/kde) was available"
    exit 2
fi

exit 0
