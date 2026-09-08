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

## Install Essential Utilities

```bash
brew install fzf bat tree jq yq
```

## Install Coding Tools

```bash
brew install git neovim ripgrep luarocks pre-commit
```

## Install Go

```bash
brew install go
```

## Install `uv`

```bash
brew install uv
```

## Install Documentation Tools

```bash
brew install hugo
```

## Install `fnm`

`fnm` is a Node versions manager that doesn't cause a noticeable slow down at activation.
The CLI interface is largely similar to that of `nvm`.

```bash
brew install fnm
```

Then install at least one LTS node version via `fnm`.

## Install AWS CLI v2

```bash
curl -fsSL https://awscli.amazonaws.com/v2/install.sh | bash
```

Update via `aws update` when needed.

## Install GitHub CLI

For authentication against GitHub, the most convenient option is to use the GitHub CLI. To install, run the
following commands.

```bash
brew install gh
```

Login immediately.

```bash
gh auth login
```

## Install `shellcheck`

```bash
brew install shellcheck
```

## Install `rustup`

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

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
gpg: requesting key from 'https://github.com/kxue43.gpg'
gpg: key C9EED408F4B6D021: "Sato Seinosuke (kxue43.github.io) <kxue43@gmail.com>" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1

gpg/card> quit
```

Then use `gpg --list-secret-keys` to confirm that the keys have been fetched.
The outputs should be something like below.

```
[keyboxd]
---------
sec>  rsa4096 2025-12-24 [SC]
      5EF2BE73370DCE7E808814DBC9EED408F4B6D021
      Card serial no. = 0006 27538718
uid           [ unknown] Sato Seinosuke (kxue43.github.io) <kxue43@gmail.com>
ssb>  rsa4096 2025-12-24 [E]
```

## Install Go Executables

```bash
go install github.com/kxue43/cli-toolkit/cmd/toolkit@latest
go install github.com/kxue43/cli-toolkit/cmd/toolkit-assume-role@latest
go install github.com/kxue43/cli-toolkit/cmd/toolkit-serve-static@latest
go install github.com/kxue43/cli-toolkit/cmd/toolkit-show-md@latest
go install mvdan.cc/sh/v3/cmd/shfmt@latest
go install golang.org/x/tools/cmd/godoc@latest
go install golang.org/x/pkgsite
go install github.com/air-verse/air@latest
```

## Install Rust Executables

```bash
cargo install --locked tree-sitter-cli
```

## Install Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

## Install Jarvis Registry CLI

[Jarvis Registry CLI](https://github.com/ascending-llc/jarvis-registry-cli) is the companion CLI for the
`jarvis-registry` MCP server; it also syncs additional Claude Code skills.

```bash
brew tap ascending-llc/jarvis
brew install ascending-llc/jarvis/jarvis-registry

mkdir -p ~/.jarvis-registry

cat >~/.jarvis-registry/config.yaml <<'EOF'
registry:
  base_url: https://jarvis-demo.ascendingdc.com
EOF
```

Authenticate and sync skills.

```bash
jarvis-registry auth login

jarvis-registry sync-skills
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
