# tick-path hook — sourced from ~/.bashrc.local / .zshrc / .profile
# Reloads ~/.config/tick-path/env into THIS shell after just updates the file.
# A just recipe cannot export into its parent; this hook is that parent-side half.

_tick_path_reload() {
    local f="${HOME}/.config/tick-path/env"
    [[ -f "$f" ]] || return 0
    # shellcheck disable=SC1090
    . "$f"
}

_tick_path_reload

if [[ -z "${_TICK_PATH_JUST_WRAPPED:-}" ]]; then
    _TICK_PATH_JUST_WRAPPED=1
    just() {
        command just "$@"
        local st=$?
        case "${1-}" in
            RunApp|deploy-multicaller|run-app)
                _tick_path_reload
                ;;
        esac
        return "$st"
    }
fi

_tick_path_maybe_reload() {
    local f="${HOME}/.config/tick-path/env" m
    [[ -f "$f" ]] || return 0
    m=$(stat -c %Y "$f" 2>/dev/null) || return 0
    if [[ "${_TICK_PATH_MTIME:-}" != "$m" ]]; then
        _TICK_PATH_MTIME=$m
        _tick_path_reload
    fi
}

if [[ -n "${BASH_VERSION:-}" && -z "${_TICK_PATH_PROMPT_INSTALLED:-}" ]]; then
    _TICK_PATH_PROMPT_INSTALLED=1
    PROMPT_COMMAND="_tick_path_maybe_reload${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

if [[ -n "${ZSH_VERSION:-}" && -z "${_TICK_PATH_PROMPT_INSTALLED:-}" ]]; then
    _TICK_PATH_PROMPT_INSTALLED=1
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _tick_path_maybe_reload
fi
