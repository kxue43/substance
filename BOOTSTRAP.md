# Bootstrap

## Introduction

This document covers how to set up an ARM64 MacBook as a developer machine, geared towards Go, Python,
and JavaScript development. Work through it before running `./set-up.sh` for the first time on a new
machine.

All commands on this page should be executed from the user's home directory.

## Install Xcode Command Line Tools

```bash
xcode-select --install
```

## Install Homebrew

Use the macOS default Terminal app.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval $(/opt/homebrew/bin/brew shellenv)
brew update
brew upgrade
```

Add the following line to both `~/.zshrc` and `~/.bash_profile`. Restart terminal.

```bash
eval $(/opt/homebrew/bin/brew shellenv)
```

## Use the Latest Version of `bash`

```bash
brew install bash bash-completion@2
```

Put `bash` inside `/usr/local/bin` and add it to `/etc/shells`.

```bash
pushd /usr/local/bin
sudo ln -s /opt/homebrew/bin/bash
popd
echo '/usr/local/bin/bash' | sudo tee -a /etc/shells
```

Change the default shell for human admin user to `/usr/local/bin/bash`.

```bash
chsh -s /usr/local/bin/bash
```

Change the default shell for `root` to `/bin/bash`.

```bash
sudo chsh -s /bin/bash
```

Restart computer for the default shell change to take effect.

## Install Ghostty

Go to the [download page](https://ghostty.org/download). Download the package installer and use it.

From now on perform all CLI operations in Ghostty.

## Install Development Tooling

```bash
brew install fzf bat tree jq yq git \
  neovim ripgrep luarocks \
  go uv fnm \
  gh shellcheck pre-commit \
  mongosh redis hugo

curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

curl -fsSL https://claude.ai/install.sh | bash
```

Then
- install at least one LTS Nodejs version via `fnm`;
- login to GitHub via `gh auth login`;
- update AWS CLI v2 via `aws update` when needed.

## Install Go Executables

```bash
go install github.com/satoseino/cli-toolkit/cmd/toolkit@latest
go install github.com/satoseino/cli-toolkit/cmd/toolkit-assume-role@latest
go install github.com/satoseino/cli-toolkit/cmd/toolkit-serve-static@latest
go install github.com/satoseino/cli-toolkit/cmd/toolkit-show-md@latest
go install mvdan.cc/sh/v3/cmd/shfmt@latest
go install golang.org/x/tools/cmd/godoc@latest
go install golang.org/x/pkgsite
go install github.com/air-verse/air@latest
```

## Install Rust Executables

```bash
cargo install --locked tree-sitter-cli
```

## Install Jarvis Registry CLI

[Jarvis Registry CLI](https://github.com/ascending-llc/jarvis-registry-cli) is the companion CLI for the
`jarvis-registry` MCP server; it also syncs additional Claude Code skills.

```bash
brew tap ascending-llc/jarvis
brew install ascending-llc/jarvis/jarvis-registry
```

Then follow the steps listed in the Homebrew formulae caveats.

## Set Up GPG to Sign Git Commits

Install `gnupg` and `pinentry-mac`. The former is the GPG software while the latter is a GUI for prompting for passphrases.

```bash
brew install gnupg pinentry-mac
echo "pinentry-program $(which pinentry-mac)" >>  ~/.gnupg/gpg-agent.conf
```

Restart `gpg-agent`.

```bash
gpg-connect-agent reloadagent /bye
```

Enter GPG interactive mode by `gpg --card-edit`, and then enter the `fetch` and `quit` command in order.
The outputs would be something like below.

```
gpg/card> fetch
gpg: requesting key from 'https://github.com/satoseino.gpg'
gpg: key 41996E9C463CE073: public key "Sato Seinosuke (Commit-signing for GitHub) <72355409+satoseino@users.noreply.github.com>" imported
gpg: Total number processed: 1
gpg:               imported: 1
```

Then use `gpg --list-secret-keys` to confirm that the keys have been fetched.
The outputs should be something like below.

```
[keyboxd]
---------
sec>  rsa3072 2026-09-26 [SC]
      E85F342A435382B5DB8C10C941996E9C463CE073
      Card serial no. = 0006 27538718
uid           [ unknown] Sato Seinosuke (Commit-signing for GitHub) <72355409+satoseino@users.noreply.github.com>
```

## Set Up `terminal-notifier` for Claude Code Notifications

This repo wires `bin/claude-notify` into Claude Code's global `Notification` hook (via the symlinked
`~/.claude/settings.json`) to send sticky macOS notifications when a session needs input. That script
shells out to `terminal-notifier`, which needs one-time setup.

```bash
brew install terminal-notifier
```

Symlink the app bundle into `~/Applications` — Notification Center only grants permission to apps under
`/Applications` or `~/Applications`, not the Homebrew Cellar.

```bash
ln -s "$(brew --prefix)/opt/terminal-notifier/terminal-notifier.app" ~/Applications/terminal-notifier.app
```

Grant `terminal-notifier` notification permission on first run, then in System Settings → Notifications →
terminal-notifier, set alert style to **Alerts** (not Banners) so `-sticky` isn't ignored.
