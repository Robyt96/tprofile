#!/usr/bin/env bash
#
# Optional installer for the tprofile Oh My Zsh plugin.
#
# It links (or copies) this plugin directory into $ZSH_CUSTOM/plugins/tprofile.
# It never edits your ~/.zshrc; it only prints the line you need to add.

set -euo pipefail

# Directory of this script (the plugin source).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Oh My Zsh custom directory.
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"

# 1./2. Verify Oh My Zsh is installed.
if [[ ! -d "$OMZ_DIR" ]]; then
  echo "error: Oh My Zsh not found at '$OMZ_DIR'." >&2
  echo "       Install it from https://ohmyz.sh/ and run this script again." >&2
  exit 1
fi

PLUGINS_DIR="$ZSH_CUSTOM/plugins"
DEST="$PLUGINS_DIR/tprofile"
mkdir -p "$PLUGINS_DIR"

# Bail out if something is already there, so we never clobber an existing install.
if [[ -e "$DEST" || -L "$DEST" ]]; then
  echo "A plugin already exists at '$DEST'."
  echo "Remove it first if you want to reinstall:"
  echo "    rm -rf \"$DEST\""
  exit 1
fi

# 3. Prefer a symlink when running from a git clone; copy otherwise.
if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ln -s "$SCRIPT_DIR" "$DEST"
  echo "Linked $SCRIPT_DIR -> $DEST"
else
  cp -R "$SCRIPT_DIR" "$DEST"
  echo "Copied $SCRIPT_DIR -> $DEST"
fi

# 4. Tell the user how to enable it (do not touch ~/.zshrc automatically).
cat <<'EOF'

Almost done! Add tprofile to the plugins list in your ~/.zshrc, for example:

    plugins=(... tprofile)

Then reload your shell:

    exec zsh

EOF
