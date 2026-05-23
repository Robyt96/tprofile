#!/usr/bin/env zsh
#
# tprofile - per-client terminal profiles for Oh My Zsh.
#
# Manages isolated zsh "profiles", each with its own segregated history file,
# a sourced per-profile rc.zsh (env vars / aliases / PATH), and visual
# distinction (Terminal.app color profile, tab title and a prompt badge).
#
# All comments are in English by convention. User-facing messages go to stdout,
# errors to stderr. Internal helpers are prefixed with `_tprofile_`.

# Root directory holding all profiles. Override by exporting TPROFILE_DIR.
: ${TPROFILE_DIR:=$HOME/.config/term-profiles}

# Make sure the profiles directory exists. Creating it has no other side effect
# on the shell, so it is safe to do even when no profile is active.
[[ -d "$TPROFILE_DIR" ]] || mkdir -p "$TPROFILE_DIR"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Print an error message to stderr, prefixed with the command name.
_tprofile_err() {
  print -u2 -- "tprofile: $*"
}

# Validate a profile name. Only [A-Za-z0-9_-] is allowed.
# Returns 0 if valid, 1 (with an error on stderr) otherwise.
_tprofile_validate_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    _tprofile_err "missing profile name"
    return 1
  fi
  if [[ ! "$name" =~ '^[A-Za-z0-9_-]+$' ]]; then
    _tprofile_err "invalid profile name '$name' (allowed: letters, digits, '_' and '-')"
    return 1
  fi
  return 0
}

# Echo the directory of a given profile.
_tprofile_dir() {
  print -r -- "$TPROFILE_DIR/$1"
}

# Echo the rc.zsh path of a given profile.
_tprofile_rc() {
  print -r -- "$TPROFILE_DIR/$1/rc.zsh"
}

# Echo the segregated history file path of a given profile.
_tprofile_histfile() {
  print -r -- "$HOME/.zsh_history_$1"
}

# Ensure a profile exists. Returns 1 (with an error) if it does not.
_tprofile_require_exists() {
  local name="$1"
  if [[ ! -d "$(_tprofile_dir "$name")" ]]; then
    _tprofile_err "profile '$name' does not exist (create it with: tprofile new $name)"
    return 1
  fi
  return 0
}

# Detect the current terminal emulator backend.
# Echoes one of: apple_terminal, iterm2, unknown.
# LC_TERMINAL is checked too because it survives tmux/ssh, where TERM_PROGRAM
# gets overwritten with "tmux".
_tprofile_backend() {
  if [[ "$TERM_PROGRAM" == "Apple_Terminal" ]]; then
    print -r -- apple_terminal
  elif [[ "$TERM_PROGRAM" == "iTerm.app" || "$LC_TERMINAL" == "iTerm2" ]]; then
    print -r -- iterm2
  else
    print -r -- unknown
  fi
}

# Switch iTerm2's current session to the profile named "$name" via its
# proprietary OSC 1337 escape sequence. This uses no AppleScript, so it never
# triggers a macOS automation permission prompt. If the profile does not exist,
# iTerm2 ignores the sequence silently. Inside tmux the sequence is wrapped in
# the DCS passthrough so it still reaches iTerm2.
_tprofile_iterm_set_profile() {
  local name="$1"
  if [[ -n "$TMUX" ]]; then
    print -n -- "\ePtmux;\e\e]1337;SetProfile=${name}\a\e\\" > /dev/tty
  else
    print -n -- "\e]1337;SetProfile=${name}\a" > /dev/tty
  fi
}

# Apply terminal appearance for a profile to the *current* window/session.
#
# This is one of the two places that know how to talk to the terminal emulator
# (the other is _tprofile_open_window); new backends (WezTerm, ...) slot into
# the case below. Crucially, we only ever talk to the emulator we are actually
# running in, so iTerm2 never pokes Terminal.app (which is what caused the
# permission prompt). Anything that fails is swallowed so the rest keeps working.
_tprofile_apply_terminal_settings() {
  local name="$1"
  case "$(_tprofile_backend)" in
    apple_terminal)
      osascript 2>/dev/null <<EOF || true
tell application "Terminal"
  set current settings of front window to (first settings set whose name is "$name")
end tell
EOF
      ;;
    iterm2)
      _tprofile_iterm_set_profile "$name"
      ;;
    *)
      # Unknown terminal: colors are emulator-specific, so there is nothing to
      # do here. History, title and prompt badge still work.
      ;;
  esac
}

# Open a brand new terminal window already inside the given profile.
#
# Backend-specific, like _tprofile_apply_terminal_settings. Both Terminal.app
# and iTerm2 need AppleScript to spawn a window (there is no escape sequence for
# that), so the first `window` may prompt once for automation permission on the
# corresponding app. The profile name is validated to [A-Za-z0-9_-]+ before we
# get here, so it is safe to interpolate. Failures are swallowed.
_tprofile_open_window() {
  local name="$1"
  case "$(_tprofile_backend)" in
    apple_terminal)
      osascript 2>/dev/null <<EOF || true
tell application "Terminal"
  set newTab to do script "export TERM_PROFILE=$name; exec zsh"
  try
    set current settings of newTab to (first settings set whose name is "$name")
  end try
  activate
end tell
EOF
      ;;
    iterm2)
      osascript 2>/dev/null <<EOF || true
tell application "iTerm"
  try
    set newWindow to (create window with profile "$name")
  on error
    set newWindow to (create window with default profile)
  end try
  tell current session of newWindow
    write text "export TERM_PROFILE=$name; exec zsh"
  end tell
  activate
end tell
EOF
      ;;
    *)
      _tprofile_err "window: unsupported terminal (TERM_PROGRAM='$TERM_PROGRAM')"
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# precmd hook (active only inside a profile, registered during init below)
# ---------------------------------------------------------------------------

# Set the tab/window title to "[<profile>] <cwd>" before each prompt.
_tprofile_precmd() {
  print -Pn -- "\e]0;[${TERM_PROFILE}] %~\a"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

# List existing profiles, one per line, or a hint when there are none.
_tprofile_list() {
  local -a profiles
  profiles=("$TPROFILE_DIR"/*(/N:t))
  if (( ${#profiles} == 0 )); then
    print -- "No profiles yet. Create one with: tprofile new <name>"
    return 0
  fi
  local p
  for p in "${profiles[@]}"; do
    print -r -- "$p"
  done
}

# Create a new profile directory and a default, fully commented rc.zsh.
# Idempotent: if the profile already exists it warns and exits 0 without
# overwriting rc.zsh.
_tprofile_new() {
  local name="$1"
  _tprofile_validate_name "$name" || return 1

  local dir="$(_tprofile_dir "$name")"
  if [[ -d "$dir" ]]; then
    print -- "Profile '$name' already exists; leaving it untouched."
    return 0
  fi

  mkdir -p "$dir"
  local rc="$(_tprofile_rc "$name")"
  cat > "$rc" <<EOF
# rc.zsh for profile: $name
#
# This file is sourced automatically when the profile is active (after you run
# 'tprofile use $name'). Put profile-specific configuration here. Everything
# below is just an example and is commented out.

# Environment variables
# export AWS_PROFILE="$name"
# export KUBECONFIG="\$HOME/.kube/$name.config"

# Aliases
# alias deploy="./scripts/deploy.sh"

# Extend PATH (zsh array form, keeps entries unique)
# typeset -U path
# path+=("\$HOME/clients/$name/bin")
EOF

  print -- "Created profile '$name' at $dir"
}

# Activate a profile in the *current* shell: set TERM_PROFILE, switch the
# Terminal.app appearance and re-exec zsh so init runs with the profile loaded.
_tprofile_use() {
  local name="$1"
  _tprofile_validate_name "$name" || return 1
  _tprofile_require_exists "$name" || return 1

  export TERM_PROFILE="$name"
  _tprofile_apply_terminal_settings "$name"
  exec zsh
}

# Open a brand new terminal window already inside the given profile.
_tprofile_window() {
  local name="$1"
  _tprofile_validate_name "$name" || return 1
  _tprofile_require_exists "$name" || return 1
  _tprofile_open_window "$name"
}

# Open a profile's rc.zsh in the user's editor (falling back to vi).
_tprofile_edit() {
  local name="$1"
  _tprofile_validate_name "$name" || return 1
  _tprofile_require_exists "$name" || return 1

  "${EDITOR:-vi}" "$(_tprofile_rc "$name")"
}

# Remove a profile directory and its history file, after interactive confirm.
_tprofile_remove() {
  local name="$1"
  _tprofile_validate_name "$name" || return 1
  _tprofile_require_exists "$name" || return 1

  local reply
  if ! read -q "reply?Remove profile '$name' and its history file? [y/N] "; then
    print -- ""
    print -- "Aborted; nothing was removed."
    return 0
  fi
  print -- ""

  rm -rf -- "$(_tprofile_dir "$name")"
  rm -f -- "$(_tprofile_histfile "$name")"
  print -- "Removed profile '$name'."
}

# Print the active profile name, or "(none)".
_tprofile_current() {
  if [[ -n "$TERM_PROFILE" ]]; then
    print -r -- "$TERM_PROFILE"
  else
    print -- "(none)"
  fi
}

# Print usage.
_tprofile_help() {
  cat <<'EOF'
tprofile - per-client terminal profiles for Oh My Zsh

Usage: tprofile <subcommand> [name]

Subcommands:
  list, ls          List existing profiles
  new <name>        Create a new profile with a default rc.zsh
  use <name>        Activate a profile in the current shell (re-execs zsh)
  window <name>     Open a new terminal window in the given profile
  edit <name>       Edit a profile's rc.zsh ($EDITOR, fallback vi)
  remove, rm <name> Remove a profile and its history file (asks for confirmation)
  current           Show the active profile name, or "(none)"
  help, -h, --help  Show this help

Environment variables:
  TPROFILE_DIR      Profiles directory (default: ~/.config/term-profiles)
  TPROFILE_NO_PROMPT  Set to 1 to disable the [profile] prompt badge
EOF
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

tprofile() {
  local cmd="${1:-help}"
  (( $# )) && shift

  case "$cmd" in
    list|ls)        _tprofile_list "$@" ;;
    new)            _tprofile_new "$@" ;;
    use)            _tprofile_use "$@" ;;
    window)         _tprofile_window "$@" ;;
    edit)           _tprofile_edit "$@" ;;
    remove|rm)      _tprofile_remove "$@" ;;
    current)        _tprofile_current "$@" ;;
    help|-h|--help) _tprofile_help ;;
    *)
      _tprofile_err "unknown subcommand: $cmd"
      _tprofile_help >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Automatic initialization (only when a profile is active)
#
# Done at top level (not inside a function) so that setopt, HISTFILE, the prompt
# and any rc.zsh content take effect at global shell scope. When TERM_PROFILE is
# unset this whole block is skipped and the plugin has no side effect on the
# shell beyond ensuring TPROFILE_DIR exists.
# ---------------------------------------------------------------------------

if [[ -n "$TERM_PROFILE" ]]; then
  # 1. Segregated history file.
  export HISTFILE="$HOME/.zsh_history_${TERM_PROFILE}"

  # 2. History behaviour options.
  setopt INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

  # 3. Source the profile's rc.zsh if present.
  if [[ -f "$TPROFILE_DIR/$TERM_PROFILE/rc.zsh" ]]; then
    source "$TPROFILE_DIR/$TERM_PROFILE/rc.zsh"
  fi

  # 4. Register a precmd hook (without clobbering an existing precmd) that keeps
  #    the tab title in sync.
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _tprofile_precmd

  # 5. Add a yellow [profile] badge to the prompt, unless explicitly disabled.
  if [[ "$TPROFILE_NO_PROMPT" != "1" ]]; then
    PROMPT="%F{yellow}[${TERM_PROFILE}]%f $PROMPT"
  fi
fi
