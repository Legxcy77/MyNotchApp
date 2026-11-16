# Source this from ~/.zshrc:
#   source ~/MyNotchApp/scripts/notch.zsh

zmodload zsh/datetime
autoload -Uz add-zsh-hook

: "${MYNOTCH_CMD_THRESHOLD:=10}"
: "${MYNOTCH_CLI:=${0:A:h}/notch}"

typeset -g _mynotch_cmd=""
typeset -g _mynotch_t0=""

_mynotch_bundle_id() {
  if [[ -n "${__CFBundleIdentifier:-}" ]]; then
    print -r -- "$__CFBundleIdentifier"
    return
  fi
  case "${TERM_PROGRAM:-}" in
    Apple_Terminal) print -r -- "com.apple.Terminal" ;;
    iTerm.app)      print -r -- "com.googlecode.iterm2" ;;
    WezTerm)        print -r -- "com.github.wez.wezterm" ;;
    Alacritty)      print -r -- "org.alacritty" ;;
    kitty)          print -r -- "net.kovidgoyal.kitty" ;;
    ghostty)        print -r -- "com.mitchellh.ghostty" ;;
    WarpTerminal)   print -r -- "dev.warp.Warp-Stable" ;;
    vscode)         print -r -- "com.microsoft.VSCode" ;;
    *)              print -r -- "" ;;
  esac
}

_mynotch_frontmost_bundle_id() {
  local raw
  raw="$(lsappinfo info -only bundleid "$(lsappinfo front 2>/dev/null)" 2>/dev/null || true)"
  if [[ "$raw" =~ '"CFBundleIdentifier"="([^"]+)"' ]]; then
    print -r -- "${match[1]}"
  fi
}

_mynotch_format_duration() {
  local s=$1
  if (( s < 60 )); then
    print -r -- "${s}s"
  elif (( s < 3600 )); then
    print -r -- "$(( s / 60 ))m $(( s % 60 ))s"
  else
    print -r -- "$(( s / 3600 ))h $(( (s % 3600) / 60 ))m"
  fi
}

_mynotch_preexec() {
  _mynotch_cmd="$1"
  _mynotch_t0="$EPOCHSECONDS"
  local first_word="${1%% *}"
  case "$first_word" in
    pnpm|npm|yarn|bun|swift|dotnet|turbo|vitest|jest|tsc|vite|cargo)
      case "$1" in
        *dev*|*serve*|*start*|*preview*) return 0 ;;
      esac
      if [[ -x "$MYNOTCH_CLI" && -r "${HOME}/.mynotch/token" ]]; then
        local repo="${PWD:t}"
        local tok="$(<"${HOME}/.mynotch/token")"
        tok="${tok//$'\n'/}"
        local cmd_escaped="${1//\"/\\\"}"
        (
          /usr/bin/curl -fsS -m 1 -X POST "http://127.0.0.1:${MYNOTCH_PORT:-7777}/build" \
            -H "Authorization: Bearer ${tok}" \
            -H "Content-Type: application/json" \
            -d "{\"runId\":\"term-live\",\"project\":\"${repo}\",\"toolchain\":\"generic\",\"kind\":\"build\",\"phase\":\"started\",\"output\":\"${cmd_escaped}\"}" >/dev/null 2>&1 || true
        ) &!
      fi
      ;;
  esac
}

_mynotch_precmd() {
  local exit_code=$?
  [[ -n "$_mynotch_t0" ]] || return 0

  local t0=$_mynotch_t0
  local cmd="$_mynotch_cmd"
  _mynotch_t0=""
  _mynotch_cmd=""

  local elapsed=$(( EPOCHSECONDS - t0 ))
  (( elapsed >= MYNOTCH_CMD_THRESHOLD )) || return 0
  [[ -x "$MYNOTCH_CLI" ]] || return 0

  local origin_id front_id
  origin_id="$(_mynotch_bundle_id)"
  front_id="$(_mynotch_frontmost_bundle_id)"
  if [[ -n "$origin_id" && -n "$front_id" && "$origin_id" == "$front_id" ]]; then
    return 0
  fi

  local dur title tint symbol priority ttl
  dur="$(_mynotch_format_duration "$elapsed")"
  if (( ${#cmd} > 48 )); then
    cmd="${cmd[1,45]}..."
  fi

  if (( exit_code == 0 )); then
    title="Command finished"
    tint="ok"
    symbol="checkmark"
    priority="normal"
    ttl="4"
  else
    title="Command failed (exit $exit_code)"
    tint="fail"
    symbol="xmark"
    priority="high"
    ttl="6"
  fi

  local -a args
  args=(toast "$title" --subtitle "${cmd} · ${dur}" --tint "$tint" --symbol "$symbol" --priority "$priority" --ttl "$ttl")
  [[ -n "$origin_id" ]] && args+=(--bundle-id "$origin_id")

  "$MYNOTCH_CLI" "${args[@]}" >/dev/null 2>&1 &!
}

add-zsh-hook preexec _mynotch_preexec
add-zsh-hook precmd _mynotch_precmd

# Error Lens wrapper: `n <cmd>` tees stderr and sends the last 30 lines on failure.
n() {
  (( $# > 0 )) || { echo "usage: n <command...>" >&2; return 2; }
  local errfile
  errfile="$(mktemp -t mynotch_err.XXXXXX)"
  local t0=$EPOCHSECONDS

  "$@" 2> >(tee "$errfile" >&2)
  local exit_code=$?
  local elapsed=$(( EPOCHSECONDS - t0 ))
  local dur
  dur="$(_mynotch_format_duration "$elapsed")"

  local cmd="$*"
  (( ${#cmd} > 48 )) && cmd="${cmd[1,45]}..."

  if (( exit_code != 0 )) && [[ -x "$MYNOTCH_CLI" ]]; then
    local origin_id
    origin_id="$(_mynotch_bundle_id)"
    local -a args
    args=(toast "Command failed (exit $exit_code)" --subtitle "${cmd} · ${dur}" --tint fail --symbol xmark --priority high --ttl 8)
    [[ -s "$errfile" ]] && args+=(--error-file "$errfile")
    [[ -n "$origin_id" ]] && args+=(--bundle-id "$origin_id")
    "$MYNOTCH_CLI" "${args[@]}" >/dev/null 2>&1 || true
  elif (( elapsed >= MYNOTCH_CMD_THRESHOLD )) && [[ -x "$MYNOTCH_CLI" ]]; then
    "$MYNOTCH_CLI" toast "Command finished" --subtitle "${cmd} · ${dur}" --tint ok --symbol checkmark --ttl 4 >/dev/null 2>&1 &!
  fi

  rm -f "$errfile"
  return $exit_code
}

