# Shell & Substance

## Getting started

Install dependencies according to [GitHub Pages](https://kxue43.github.io/notes-and-blogs/).

```bash
mkdir -p ~/.config
git clone https://github.com/kxue43/substance ~/.config/substance
~/.config/substance/set-up.sh
```

Open up `nvim` and run `:MasonInstallAll`, `:TSInstallAll`, `:checkhealth`.

Install [Jarvis Registry CLI](https://github.com/ascending-llc/jarvis-registry-cli) and sync skills.

```bash
brew tap ascending-llc/jarvis
brew install ascending-llc/jarvis/jarvis-registry

mkdir -p ~/.jarvis-registry
cat >~/.jarvis-registry/config.yaml <<'EOF'
registry:
  base_url: https://jarvis-demo.ascendingdc.com
EOF

jarvis-registry auth login
jarvis-registry sync-skills
```
