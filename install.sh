#!/bin/bash

echo -n "Fetching dependencies..."
wget -q -O concurrent.sh wget https://raw.githubusercontent.com/themattrix/bash-concurrent/master/concurrent.lib.sh
echo " Done."

source ./concurrent.sh

rm -rf /tmp/concurrent_logs
export CONCURRENT_LOG_DIR=/tmp/concurrent_logs

function install_volta() {
  echo "Installing volta" >&3
  curl https://get.volta.sh | bash

  echo "Creating symlink" >&3
  mkdir -p $HOME/.local/bin
  ln -sf $HOME/.volta/bin/volta $HOME/.local/bin/volta
}

function install_tool() {
  echo "Installing $1" >&3
  # install @$2, defaulting to @latest
  if [ -z "$2" ]; then
    $HOME/.volta/bin/volta install $1@latest
  else
    $HOME/.volta/bin/volta install $1@$2
  fi
}

function install_rust() {
  echo "Installing rust" >&3
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  source $HOME/.cargo/env
}

function install_homebrew() {
  # if brew doesn't already exist, install it
  if [ ! -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
    echo "Installing homebrew" >&3
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # if .profile doesn't already have homebrew installed, add it
  if ! grep -q "homebrew" /home/codespace/.profile; then
    echo "Adding homebrew to .profile" >&3
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>/home/codespace/.profile
  fi

  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}

function install_brew_cmd() {
  echo "Installing $1" >&3
  /home/linuxbrew/.linuxbrew/bin/brew install $1
}

function install_nushell() {
  install_brew_cmd 'nushell'

  local nu_path="/home/linuxbrew/.linuxbrew/bin/nu"

  local shell=$(getent passwd "$USER" | awk -F: '{print $NF}')

  if [[ "$shell" =~ "/nu" ]]; then
    echo "Nushell is already the login shell" >&3
    return
  fi

  # if /etc/shells doesn't already have nushell in it, add it
  if ! grep -q "$nu_path" /etc/shells; then
    echo "Adding nushell to /etc/shells" >&3
    sudo bash -c "echo \"$nu_path\" >>/etc/shells"
  fi

  # install nushell as the login shell
  echo "Installing nushell as the login shell" >&3
  sudo chsh -s "$nu_path" "$(whoami)"
}

function install_node() {
  concurrent \
    - 'volta' install_volta \
    --and-then \
    - 'node' install_tool node lts \
    --and-then \
    - 'pnpm' install_tool pnpm \
    - 'vite' install_tool vite \
    - 'vitest' install_tool vitest
}

concurrent \
  - 'volta' install_volta \
  - 'node' install_tool node lts \
  - 'pnpm' install_tool pnpm \
  - 'vite' install_tool vite \
  - 'vitest' install_tool vitest \
  --require 'volta' --before 'node' \
  --require 'node' --before 'pnpm' --before 'vite' --before 'vitest' \
  - 'rust' install_rust \
  - 'brew' install_homebrew \
  - 'nushell' install_nushell \
  --require 'brew' --before 'nushell'
