#!/bin/sh
# Codespace creation hook (dotfiles). Runs once per fresh codespace as the
# codespace user, cwd=$HOME/.dotfiles. Idempotent.
set -eu

# gh CLI: baked into the image; install from the official apt repo if a
# future image drops it.
if ! command -v gh >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl gnupg
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh
fi

# GH_TOKEN arrives as an env var from the user-level Codespaces secret.
# Persist a gh login (hosts.yml) and rc-file exports without ever writing
# the token value itself to disk (the rc line re-reads it from the env).
if [ -n "${GH_TOKEN:-}" ]; then
  if ! gh auth status >/dev/null 2>&1; then
    tmp=$(mktemp)
    printf '%s' "$GH_TOKEN" > "$tmp"
    chmod 600 "$tmp"
    env -u GH_TOKEN gh auth login --with-token < "$tmp"
    shred -u "$tmp" 2>/dev/null || rm -f "$tmp"
  fi
  for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.zshenv"; do
    [ -f "$f" ] || touch "$f"
    grep -q '^export GH_TOKEN=' "$f" || printf '\nexport GH_TOKEN="${GH_TOKEN:-}"\n' >> "$f"
  done
fi

# ~/.local/bin on PATH for non-interactive shells.
for f in "$HOME/.profile" "$HOME/.zshenv"; do
  [ -f "$f" ] || touch "$f"
  grep -q '.local/bin' "$f" || printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$f"
done
