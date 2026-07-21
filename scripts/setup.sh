#!/bin/sh
# macOS developer setup script (Apple Silicon)
# Note: This script is macOS/Apple Silicon-only (uses pbcopy and Keychain integration)

set -e

# -------------------------------------------------------
# Helpers
# -------------------------------------------------------

section() {
  echo ""
  echo "======================================================"
  echo " $1"
  echo "======================================================"
  echo ""
}

# -------------------------------------------------------
# Check macOS
# -------------------------------------------------------

if [ "$(uname)" != "Darwin" ]; then
  echo "Error: This script is macOS-only and cannot run on $(uname)."
  exit 1
fi

echo ""
echo "Starting macOS developer setup..."
echo ""

# Ensure brew is on PATH if already installed
if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# -------------------------------------------------------
# 1. Homebrew
# -------------------------------------------------------

section "Homebrew"

if command -v brew >/dev/null 2>&1; then
  echo "Homebrew is already installed: $(brew --version | head -1)"
else
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo "Homebrew installed successfully."
fi

# -------------------------------------------------------
# 2. Rosetta 2
# -------------------------------------------------------

section "Rosetta 2"

if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  echo "Rosetta 2 is already installed, skipping."
else
  echo "Installing Rosetta 2..."
  softwareupdate --install-rosetta --agree-to-license
  echo "Rosetta 2 installed successfully."
fi

# -------------------------------------------------------
# 3. GitHub SSH Key
# -------------------------------------------------------

section "GitHub SSH Key"

KEY_PATH="$HOME/.ssh/id_ed25519"

echo "Checking for existing GitHub SSH key..."
SSH_OUTPUT=$(ssh -T git@github.com 2>&1 || true)

if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
  echo "Already authenticated with GitHub: $SSH_OUTPUT"
else
  printf "Enter your GitHub email: "
  read EMAIL

  if [ -f "$KEY_PATH" ]; then
    echo "SSH key file already exists at $KEY_PATH but is not registered with GitHub — continuing setup."
  else
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY_PATH" -N ""
  fi

  # Start ssh-agent and add key
  echo "Adding key to ssh-agent..."
  eval "$(ssh-agent -s)" >/dev/null

  # Add SSH config entry for macOS keychain persistence
  mkdir -p "$HOME/.ssh"
  CONF="$HOME/.ssh/config"
  if ! grep -q "Host github.com" "$CONF" 2>/dev/null; then
    cat >> "$CONF" <<EOF

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $KEY_PATH
EOF
  fi

  ssh-add --apple-use-keychain "$KEY_PATH" 2>/dev/null || ssh-add "$KEY_PATH"

  # Copy public key to clipboard
  pbcopy < "$KEY_PATH.pub"
  echo ""
  echo "Your public key has been copied to the clipboard:"
  echo ""
  cat "$KEY_PATH.pub"
  echo ""
  echo "-----------------------------------------------------"
  echo "Next: Add it to GitHub"
  echo "  1. Go to https://github.com/settings/keys"
  echo "  2. Click 'New SSH key'"
  echo "  3. Paste the key and save"
  echo "-----------------------------------------------------"
  echo ""
  printf "Press Enter once you've added the key to GitHub..."
  read _

  echo "Testing connection to GitHub..."
  ssh -T git@github.com 2>&1 || true
fi

# -------------------------------------------------------
# 4. Git Configuration
# -------------------------------------------------------

section "Git Configuration"

# Set default branch name
git config --global init.defaultBranch main
echo "Default branch set to 'main'."

# Set push default to current branch
git config --global push.default current
echo "Push default set to 'current'."

# -------------------------------------------------------
# 5. sqlite3 and other build dependencies
# -------------------------------------------------------

section "SQLite3 + build dependencies"

for pkg in sqlite xz openssl readline zlib tcl-tk libpq; do
  if brew list $pkg >/dev/null 2>&1; then
    echo "$pkg is already installed, skipping."
  else
    echo "Installing $pkg..."
    brew install $pkg
    echo "$pkg installed successfully."
  fi
done

# -------------------------------------------------------
# 6. Geospatial tools
# -------------------------------------------------------

section "Geospatial tools"

for pkg in gdal spatialite-tools; do
  if brew list $pkg >/dev/null 2>&1; then
    echo "$pkg is already installed, skipping."
  else
    echo "Installing $pkg..."
    brew install $pkg
    echo "$pkg installed successfully."
  fi
done

# -------------------------------------------------------
# 7. Make
# -------------------------------------------------------

section "Make"

if brew list make >/dev/null 2>&1; then
  echo "make is already installed, skipping."
else
  echo "Installing make..."
  brew install make
  echo "make installed successfully."
fi

# -------------------------------------------------------
# 8. pyenv
# -------------------------------------------------------

section "pyenv"

if command -v pyenv >/dev/null 2>&1; then
  echo "pyenv is already installed, skipping."
else
  echo "Installing pyenv..."
  brew install pyenv
  echo "pyenv installed successfully."
fi

# Ensure sqlite3 flags are set before any pyenv install commands
# so Python builds correctly pick up the brew-managed sqlite3
export LDFLAGS="-L/opt/homebrew/opt/sqlite/lib -L/opt/homebrew/opt/xz/lib -L/opt/homebrew/opt/openssl/lib -L/opt/homebrew/opt/readline/lib -L/opt/homebrew/opt/zlib/lib"
export CPPFLAGS="-I/opt/homebrew/opt/sqlite/include -I/opt/homebrew/opt/xz/include -I/opt/homebrew/opt/openssl/include -I/opt/homebrew/opt/readline/include -I/opt/homebrew/opt/zlib/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/sqlite/lib/pkgconfig:/opt/homebrew/opt/xz/lib/pkgconfig:/opt/homebrew/opt/openssl/lib/pkgconfig:/opt/homebrew/opt/readline/lib/pkgconfig:/opt/homebrew/opt/zlib/lib/pkgconfig"
export PYTHON_CONFIGURE_OPTS="--enable-loadable-sqlite-extensions"

# Install default Python versions
# Note: Python 3.9 is EOL but included for legacy repo compatibility (digital-land.info)
# Consider upgrading digital-land.info from Python 3.9 when possible
install_python() {
  VERSION=$1
  if pyenv versions --bare | grep -q "^$VERSION$"; then
    echo "Python $VERSION is already installed, checking sqlite3 load_extension support..."
    if PYENV_VERSION=$VERSION python -c "import sqlite3; db = sqlite3.connect(':memory:'); db.enable_load_extension(True)" 2>/dev/null; then
      echo "Python $VERSION sqlite3 load_extension: OK, skipping reinstall."
      return
    else
      echo "Python $VERSION is missing sqlite3 load_extension support, reinstalling..."
      pyenv uninstall --force "$VERSION"
    fi
  else
    echo "Installing Python $VERSION (this may take a few minutes)..."
  fi

  pyenv install "$VERSION"

  # Verify sqlite3 load_extension support
  echo "Checking sqlite3 load_extension support for Python $VERSION..."
  if PYENV_VERSION=$VERSION python -c "import sqlite3; db = sqlite3.connect(':memory:'); db.enable_load_extension(True); print('sqlite3 load_extension: OK')" 2>/dev/null; then
    echo "Python $VERSION installed successfully."
  else
    echo "WARNING: Python $VERSION was installed without sqlite3 load_extension support."
    echo "Check that the sqlite3 LDFLAGS and CPPFLAGS are set correctly and try again."
  fi
}

install_python "3.9.19"
install_python "3.11.9"
install_python "3.13.3"

# Set 3.13.3 as the global default
pyenv global "3.13.3"
echo "Python 3.13.3 set as global default."
echo ""
echo "Useful pyenv resources:"
echo "  Official docs: https://github.com/pyenv/pyenv"
echo "  macOS guide:   https://mac.install.guide/python/install-pyenv"

# -------------------------------------------------------
# 9. Oh My Zsh
# -------------------------------------------------------

section "Oh My Zsh"

if [ -d "$HOME/.oh-my-zsh" ]; then
  echo "Oh My Zsh is already installed, skipping."
else
  echo "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  echo "Oh My Zsh installed successfully."
  echo "You can customise your theme by editing ~/.zshrc and changing the ZSH_THEME value."
  echo "A popular optional theme is Powerlevel10k: https://github.com/romkatv/powerlevel10k"
fi

# -------------------------------------------------------
# 10. fnm (Node version manager)
# -------------------------------------------------------

section "fnm"

if command -v fnm >/dev/null 2>&1; then
  echo "fnm is already installed, skipping."
else
  echo "Installing fnm..."
  brew install fnm
  echo "fnm installed successfully."
fi

# Install latest LTS Node version as default
eval "$(fnm env)"
FNM_LTS=$(fnm list-remote --lts | tail -1 | tr -d '[:space:]')
if fnm list | grep -q "$FNM_LTS"; then
  echo "Node LTS $FNM_LTS is already installed, skipping."
else
  echo "Installing latest Node LTS ($FNM_LTS)..."
  fnm install --lts
  fnm default "$FNM_LTS"
  echo "Node LTS $FNM_LTS installed and set as default."
fi

# -------------------------------------------------------
# 11. Apps
# -------------------------------------------------------

section "Apps"

install_cask() {
  APP=$1
  if brew list --cask "$APP" >/dev/null 2>&1; then
    echo "$APP is already installed, skipping."
  else
    echo "Installing $APP..."
    brew install --cask "$APP"
    echo "$APP installed successfully."
  fi
}

PREFS_FILE="$HOME/.config/digital-land/setup-prefs"
SAVED_APPS=$(grep "^APPS=" "$PREFS_FILE" 2>/dev/null | cut -d= -f2-) || true

if [ -n "$SAVED_APPS" ]; then
  echo "Using saved app preferences: $SAVED_APPS"
  SELECTED="$SAVED_APPS"
else
  sel_chrome=1 sel_slack=1 sel_ghostty=1 sel_vscode=1 sel_docker=1

  print_app_menu() {
    echo ""
    echo "Select apps to install (enter a number to toggle, Enter to confirm):"
    echo ""
    [ "$sel_chrome"  = 1 ] && echo "  [x] 1) Google Chrome"      || echo "  [ ] 1) Google Chrome"
    [ "$sel_slack"   = 1 ] && echo "  [x] 2) Slack"              || echo "  [ ] 2) Slack"
    [ "$sel_ghostty" = 1 ] && echo "  [x] 3) Ghostty"            || echo "  [ ] 3) Ghostty"
    [ "$sel_vscode"  = 1 ] && echo "  [x] 4) Visual Studio Code" || echo "  [ ] 4) Visual Studio Code"
    [ "$sel_docker"  = 1 ] && echo "  [x] 5) Docker"             || echo "  [ ] 5) Docker"
    echo ""
  }

  print_app_menu

  while true; do
    printf "Toggle (1-5) or press Enter to confirm: "
    read CHOICE
    case "$CHOICE" in
      1) [ "$sel_chrome"  = 1 ] && sel_chrome=0  || sel_chrome=1  ;;
      2) [ "$sel_slack"   = 1 ] && sel_slack=0   || sel_slack=1   ;;
      3) [ "$sel_ghostty" = 1 ] && sel_ghostty=0 || sel_ghostty=1 ;;
      4) [ "$sel_vscode"  = 1 ] && sel_vscode=0  || sel_vscode=1  ;;
      5) [ "$sel_docker"  = 1 ] && sel_docker=0  || sel_docker=1  ;;
      "") break ;;
      *)  echo "  Please enter a number between 1 and 5." ;;
    esac
    print_app_menu
  done

  SELECTED=""
  [ "$sel_chrome"  = 1 ] && SELECTED="$SELECTED google-chrome"
  [ "$sel_slack"   = 1 ] && SELECTED="$SELECTED slack"
  [ "$sel_ghostty" = 1 ] && SELECTED="$SELECTED ghostty"
  [ "$sel_vscode"  = 1 ] && SELECTED="$SELECTED visual-studio-code"
  [ "$sel_docker"  = 1 ] && SELECTED="$SELECTED docker"
  SELECTED="${SELECTED# }"

  mkdir -p "$(dirname "$PREFS_FILE")"
  TMP=$(mktemp)
  grep -v "^APPS=" "$PREFS_FILE" 2>/dev/null > "$TMP" || true
  echo "APPS=$SELECTED" >> "$TMP"
  mv "$TMP" "$PREFS_FILE"
fi

for APP in $SELECTED; do
  install_cask "$APP"
done

# -------------------------------------------------------
# 12. VS Code Extensions (optional)
# -------------------------------------------------------

section "VS Code Extensions"

vscode_selected=0
for a in $SELECTED; do
  [ "$a" = "visual-studio-code" ] && vscode_selected=1
done

if [ "$vscode_selected" = 1 ]; then
  CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

  if [ ! -f "$CODE_BIN" ]; then
    echo "VS Code binary not found at expected path, skipping extensions."
    echo "Open VS Code once and re-run the script to install extensions."
  else
    install_vscode_extension() {
      EXT=$1
      DESC=$2
      if "$CODE_BIN" --list-extensions 2>/dev/null | grep -qi "^$EXT$"; then
        echo "$DESC is already installed, skipping."
      else
        echo "Installing $DESC ($EXT)..."
        "$CODE_BIN" --install-extension "$EXT"
      fi
    }

    SAVED_EXTS=$(grep "^EXTENSIONS=" "$PREFS_FILE" 2>/dev/null | cut -d= -f2-) || true

    if [ -n "$SAVED_EXTS" ]; then
      echo "Using saved extension preferences."
      for EXT in $SAVED_EXTS; do
        install_vscode_extension "$EXT" "$EXT"
      done
    else
      sel_python=1 sel_pylance=1 sel_black=1
      sel_eslint=1 sel_prettier=1 sel_npm=1
      sel_gitlens=1 sel_spell=1 sel_docker_ext=1

      print_ext_menu() {
        echo ""
        echo "Select VS Code extensions to install (enter a number to toggle, Enter to confirm):"
        echo ""
        echo "  Python"
        [ "$sel_python"  = 1 ] && echo "    [x] 1) Python"             || echo "    [ ] 1) Python"
        [ "$sel_pylance" = 1 ] && echo "    [x] 2) Pylance"            || echo "    [ ] 2) Pylance"
        [ "$sel_black"   = 1 ] && echo "    [x] 3) Black Formatter"    || echo "    [ ] 3) Black Formatter"
        echo "  JavaScript / Node.js"
        [ "$sel_eslint"   = 1 ] && echo "    [x] 4) ESLint"            || echo "    [ ] 4) ESLint"
        [ "$sel_prettier" = 1 ] && echo "    [x] 5) Prettier"          || echo "    [ ] 5) Prettier"
        [ "$sel_npm"      = 1 ] && echo "    [x] 6) npm IntelliSense"  || echo "    [ ] 6) npm IntelliSense"
        echo "  General"
        [ "$sel_gitlens"    = 1 ] && echo "    [x] 7) GitLens"              || echo "    [ ] 7) GitLens"
        [ "$sel_spell"      = 1 ] && echo "    [x] 8) Code Spell Checker"   || echo "    [ ] 8) Code Spell Checker"
        echo "  Docker"
        [ "$sel_docker_ext" = 1 ] && echo "    [x] 9) Docker"          || echo "    [ ] 9) Docker"
        echo ""
      }

      print_ext_menu

      while true; do
        printf "Toggle (1-9) or press Enter to confirm: "
        read CHOICE
        case "$CHOICE" in
          1) [ "$sel_python"     = 1 ] && sel_python=0     || sel_python=1     ;;
          2) [ "$sel_pylance"    = 1 ] && sel_pylance=0    || sel_pylance=1    ;;
          3) [ "$sel_black"      = 1 ] && sel_black=0      || sel_black=1      ;;
          4) [ "$sel_eslint"     = 1 ] && sel_eslint=0     || sel_eslint=1     ;;
          5) [ "$sel_prettier"   = 1 ] && sel_prettier=0   || sel_prettier=1   ;;
          6) [ "$sel_npm"        = 1 ] && sel_npm=0        || sel_npm=1        ;;
          7) [ "$sel_gitlens"    = 1 ] && sel_gitlens=0    || sel_gitlens=1    ;;
          8) [ "$sel_spell"      = 1 ] && sel_spell=0      || sel_spell=1      ;;
          9) [ "$sel_docker_ext" = 1 ] && sel_docker_ext=0 || sel_docker_ext=1 ;;
          "") break ;;
          *)  echo "  Please enter a number between 1 and 9." ;;
        esac
        print_ext_menu
      done

      SELECTED_EXTS=""
      [ "$sel_python"     = 1 ] && SELECTED_EXTS="$SELECTED_EXTS ms-python.python"
      [ "$sel_pylance"    = 1 ] && SELECTED_EXTS="$SELECTED_EXTS ms-python.vscode-pylance"
      [ "$sel_black"      = 1 ] && SELECTED_EXTS="$SELECTED_EXTS ms-python.black-formatter"
      [ "$sel_eslint"     = 1 ] && SELECTED_EXTS="$SELECTED_EXTS dbaeumer.vscode-eslint"
      [ "$sel_prettier"   = 1 ] && SELECTED_EXTS="$SELECTED_EXTS esbenp.prettier-vscode"
      [ "$sel_npm"        = 1 ] && SELECTED_EXTS="$SELECTED_EXTS christian-kohler.npm-intellisense"
      [ "$sel_gitlens"    = 1 ] && SELECTED_EXTS="$SELECTED_EXTS eamodio.gitlens"
      [ "$sel_spell"      = 1 ] && SELECTED_EXTS="$SELECTED_EXTS streetsidesoftware.code-spell-checker"
      [ "$sel_docker_ext" = 1 ] && SELECTED_EXTS="$SELECTED_EXTS ms-azuretools.vscode-docker"
      SELECTED_EXTS="${SELECTED_EXTS# }"

      TMP=$(mktemp)
      grep -v "^EXTENSIONS=" "$PREFS_FILE" 2>/dev/null > "$TMP" || true
      echo "EXTENSIONS=$SELECTED_EXTS" >> "$TMP"
      mv "$TMP" "$PREFS_FILE"

      for EXT in $SELECTED_EXTS; do
        install_vscode_extension "$EXT" "$EXT"
      done
    fi

    echo "VS Code extensions installed successfully."
  fi
else
  echo "Skipping VS Code extensions (VS Code not selected)."
fi

# -------------------------------------------------------
# 13. Shell Configuration (.zprofile and .zshrc)
# -------------------------------------------------------

section "Shell Configuration (.zprofile + .zshrc)"

ZSHRC="$HOME/.zshrc"
ZPROFILE="$HOME/.zprofile"
MARKER_START="# BEGIN digital_land_settings"
MARKER_END="# END digital_land_settings"
BREW_PREFIX="/opt/homebrew"

write_block() {
  FILE="$1"
  BLOCK="$2"
  touch "$FILE"
  if grep -q "$MARKER_START" "$FILE"; then
    echo "Updating existing digital_land_settings block in $FILE..."
    awk "/$MARKER_START/{found=1} !found{print} /$MARKER_END/{found=0}" "$FILE" > "$FILE.tmp"
    mv "$FILE.tmp" "$FILE"
  fi
  printf "\n%s\n" "$BLOCK" >> "$FILE"
  echo "Written to $FILE."
}

# .zprofile — login-time environment (brew PATH)
ZPROFILE_BLOCK="$MARKER_START
# Managed by setup.sh — do not edit manually between these markers
# This block is written to .zprofile because these are login-time environment
# variables that only need to be set once per terminal session.

# Homebrew
# Adds brew to PATH and sets up the brew environment
eval \"\$($BREW_PREFIX/bin/brew shellenv)\"

# SQLite3
# Uses the brew-managed sqlite3 instead of the outdated macOS system version.
# The PATH entry ensures 'sqlite3' resolves to the brew version.
export PATH=\"$BREW_PREFIX/opt/sqlite/bin:\$PATH\"

# Python build flags
# These compiler flags are required so that pyenv builds Python correctly,
# picking up brew-managed versions of sqlite3, xz (lzma), openssl, readline,
# and zlib instead of the macOS system versions.
# PYTHON_CONFIGURE_OPTS enables sqlite3 loadable extensions in Python builds,
# which is required by packages such as SpatiaLite and Django GIS.
# These flags are active in every terminal session so that running
# 'pyenv install' manually will always produce a correct Python build.
export LDFLAGS=\"-L$BREW_PREFIX/opt/sqlite/lib -L$BREW_PREFIX/opt/xz/lib -L$BREW_PREFIX/opt/openssl/lib -L$BREW_PREFIX/opt/readline/lib -L$BREW_PREFIX/opt/zlib/lib\"
export CPPFLAGS=\"-I$BREW_PREFIX/opt/sqlite/include -I$BREW_PREFIX/opt/xz/include -I$BREW_PREFIX/opt/openssl/include -I$BREW_PREFIX/opt/readline/include -I$BREW_PREFIX/opt/zlib/include\"
export PKG_CONFIG_PATH=\"$BREW_PREFIX/opt/sqlite/lib/pkgconfig:$BREW_PREFIX/opt/xz/lib/pkgconfig:$BREW_PREFIX/opt/openssl/lib/pkgconfig:$BREW_PREFIX/opt/readline/lib/pkgconfig:$BREW_PREFIX/opt/zlib/lib/pkgconfig\"
export PYTHON_CONFIGURE_OPTS=\"--enable-loadable-sqlite-extensions\"

# Make
# Uses the brew-managed GNU make instead of the outdated macOS system make
# (macOS ships with make 3.81 from 2006 due to licensing reasons).
export PATH=\"$BREW_PREFIX/opt/make/libexec/gnubin:\$PATH\"

# libpq
# Required for compiling psycopg2 on Apple Silicon. libpq is not linked into
# the system PATH by default because it conflicts with macOS system libraries.
export PATH=\"$BREW_PREFIX/opt/libpq/bin:\$PATH\"

$MARKER_END"

# .zshrc — per-shell session hooks
ZSHRC_BLOCK="$MARKER_START
# Managed by setup.sh — do not edit manually between these markers
# This block is written to .zshrc because these hooks need to run in
# every shell session, not just at login.

# pyenv
# Sets up pyenv so it can manage Python versions.
# PYENV_ROOT points to where pyenv stores Python versions (~/.pyenv).
# The PATH entry makes the pyenv command available.
# 'pyenv init -' installs the shell hook that automatically switches Python
# versions when you cd into a directory containing a .python-version file.
export PYENV_ROOT=\"\$HOME/.pyenv\"
export PATH=\"\$PYENV_ROOT/bin:\$PATH\"
eval \"\$(pyenv init -)\"

# fnm (Node version manager)
# Sets up fnm and installs the shell hook that automatically switches Node
# versions when you cd into a directory containing a .nvmrc file.
# --use-on-cd: switches version automatically on cd
# --version-file-strategy=recursive: looks up parent directories for .nvmrc
# --resolve-engines: respects the engines.node field in package.json
# --install-if-missing: automatically installs the version if not yet installed
eval \"\$(fnm env --use-on-cd --version-file-strategy=recursive --resolve-engines)\"


# Virtual environments
# mkvenv: creates a .venv in the current directory using the active pyenv Python
# version, then activates it. Run this once per project after cloning.
# workon: activates the .venv in the current directory. Run this at the start
# of each terminal session when working on a project.
alias mkvenv='python -m venv .venv && source .venv/bin/activate'
alias workon='source .venv/bin/activate'

$MARKER_END"

write_block "$ZPROFILE" "$ZPROFILE_BLOCK"
write_block "$ZSHRC" "$ZSHRC_BLOCK"

# -------------------------------------------------------

echo ""
echo "======================================================"
echo " Setup complete!"
echo "======================================================"
echo ""
echo "Installed:"
echo "  - Homebrew"
echo "  - Git (default branch: main, push default: current)"
echo "  - SQLite3, xz, openssl, readline, zlib, tcl-tk (build dependencies)"
echo "  - make (brew-managed GNU version)"
echo "  - pyenv with Python 3.9.19, 3.11.9, 3.13.3 (global default: 3.13.3)"
echo "  - Oh My Zsh"
echo "  - fnm with Node LTS"
echo "  - Google Chrome, Slack, Ghostty, VS Code, Docker Desktop"
echo ""
echo "Shell aliases added to ~/.zshrc:"
echo "  - mkvenv  — create a .venv in the current directory and activate it"
echo "  - workon  — activate the .venv in the current directory"
echo ""
echo "Next steps:"
echo "  1. Run 'source ~/.zprofile && source ~/.zshrc' or open a new terminal"
echo "  2. Open Docker Desktop from Applications and complete initial setup"
echo "  3. Optionally customise your Oh My Zsh theme in ~/.zshrc (ZSH_THEME)"
echo "     A popular theme is Powerlevel10k: https://github.com/romkatv/powerlevel10k"
echo ""