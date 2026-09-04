# Shell & Substance

## Getting started

- Install dependencies according to [MacBook with Homebrew](https://kxue43.github.io/notes-and-blogs/notes/macbook-with-homebrew/).

- Clone `substance` repo and run set-up script.

  ```bash
  mkdir -p ~/.config
  git clone https://github.com/kxue43/substance ~/.config/substance
  ~/.config/substance/set-up.sh
  ```

- Open up `nvim` and run `:MasonInstallAll`, `:TSInstallAll`, `:checkhealth`.

- Install [Jarvis Registry CLI](https://github.com/ascending-llc/jarvis-registry-cli) and set up config file.

  ```bash
  brew tap ascending-llc/jarvis
  brew install ascending-llc/jarvis/jarvis-registry
  
  mkdir -p ~/.jarvis-registry

  cat >~/.jarvis-registry/config.yaml <<'EOF'
  registry:
    base_url: https://jarvis-demo.ascendingdc.com
  EOF
  ```

- Sync additional Claude Code skills via Jarvis Registry CLI.
  
  ```bash
  jarvis-registry auth login

  jarvis-registry sync-skills
  ```
