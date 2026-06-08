# Shell & Substance

## Getting started

Install dependencies according to [GitHub Pages](https://kxue43.github.io/notes-and-blogs/).

```bash
mkdir -p ~/.config
git clone https://github.com/kxue43/substance ~/.config/substance
~/.config/substance/set-up.sh
source "$HOME/.bashrc"
pre-commit install -t pre-commit -t post-merge
```

Open up `nvim` and run `:MasonInstallAll`, `:TSInstallAll`, `:checkhealth`.
