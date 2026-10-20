#!/usr/bin/env bash
# Upsert tick-path deploy exports into:
#   - repo .env and .bytecode/app/env
#   - ~/.config/tick-path/env  (user-global; sourced from ~/.bashrc.local)
#   - ~/.config/environment.d/90-tick-path.conf + systemd --user
# Does not clobber other .env keys.
set -euo pipefail

upsert_export() {
    local file="$1" key="$2" value="$3"
    [[ -n "$value" ]] || return 0
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -qE "^(export[[:space:]]+)?${key}=" "$file"; then
        sed -E "s|^(export[[:space:]]+)?${key}=.*|export ${key}=${value}|" "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    else
        echo "export ${key}=${value}" >> "$file"
    fi
}

upsert_plain() {
    local file="$1" key="$2" value="$3"
    [[ -n "$value" ]] || return 0
    mkdir -p "$(dirname "$file")"
    touch "$file"
    if grep -qE "^${key}=" "$file"; then
        sed -E "s|^${key}=.*|${key}=${value}|" "$file" > "$file.tmp"
        mv "$file.tmp" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

ensure_source() {
    local rc="$1" needle="$2" block="$3"
    [[ -f "$rc" ]] || return 0
    grep -qF "$needle" "$rc" && return 0
    printf '\n%s\n' "$block" >> "$rc"
}

drop_key() {
    local file="$1" key="$2"
    [[ -f "$file" ]] || return 0
    grep -qE "^(export[[:space:]]+)?${key}=" "$file" || return 0
    grep -vE "^(export[[:space:]]+)?${key}=" "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
}

root="${1:-.}"
out_dir="${2:-.bytecode/app}"
rpc="${ANVIL_RPC_URL:-http://127.0.0.1:8545}"

keys=(
    "ANVIL_RPC_URL=$rpc"
    "APP_ADDRESS=${APP_ADDRESS:-}"
    "APP_TX_HASH=${APP_TX_HASH:-}"
    "MULTICALLER_ADDRESS=${MULTICALLER_ADDRESS:-}"
    "MULTICALLER_TX_HASH=${MULTICALLER_TX_HASH:-}"
)
drop_keys=(TICK_ADDRESS TICK_TX_HASH)

mkdir -p "$root/$out_dir"
user_env="${HOME}/.config/tick-path/env"
systemd_env="${HOME}/.config/environment.d/90-tick-path.conf"

for f in "$root/.env" "$root/$out_dir/env" "$user_env"; do
    for kv in "${keys[@]}"; do
        upsert_export "$f" "${kv%%=*}" "${kv#*=}"
    done
done
for kv in "${keys[@]}"; do
    upsert_plain "$systemd_env" "${kv%%=*}" "${kv#*=}"
done
for f in "$root/.env" "$root/$out_dir/env" "$user_env" "$systemd_env"; do
    for key in "${drop_keys[@]}"; do
        drop_key "$f" "$key"
    done
done

hook_src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tick-path-hook.sh"
hook_dst="${HOME}/.config/tick-path/hook.sh"
mkdir -p "${HOME}/.config/tick-path"
cp "$hook_src" "$hook_dst"

# Drop the previous one-shot `source env` line; hook.sh loads env and reloads after just.
strip_old_source() {
    local rc="$1"
    [[ -f "$rc" ]] || return 0
    grep -qF 'tick-path/env' "$rc" || return 0
    grep -qF 'tick-path/hook.sh' "$rc" || return 0
    local tmp
    tmp="$(mktemp)"
    grep -vF -e 'tick-path/env' -e 'tick-path anvil deploy (user-global' "$rc" > "$tmp"
    mv "$tmp" "$rc"
}
strip_old_source "${HOME}/.bashrc.local"
strip_old_source "${HOME}/.profile"
strip_old_source "${HOME}/.zshrc"

src_block='# tick-path anvil deploy: load env and reload after just RunApp
[ -f "$HOME/.config/tick-path/hook.sh" ] && . "$HOME/.config/tick-path/hook.sh"'
ensure_source "${HOME}/.bashrc.local" 'tick-path/hook.sh' "$src_block"
ensure_source "${HOME}/.profile" 'tick-path/hook.sh' "$src_block"
ensure_source "${HOME}/.zshrc" 'tick-path/hook.sh' "$src_block"

if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    sysd_args=()
    for kv in "${keys[@]}"; do
        [[ -n "${kv#*=}" ]] && sysd_args+=("$kv")
    done
    systemctl --user set-environment "${sysd_args[@]}"
fi

echo "wrote user-global $user_env"
echo "wrote $hook_dst (just RunApp reloads it in this shell)"
echo "wrote $systemd_env"
