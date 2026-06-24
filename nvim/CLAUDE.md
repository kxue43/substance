# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Base

Built on [NvChad v2.5](https://github.com/NvChad/NvChad) (forked from `NvChad/starter`), using `lazy.nvim` for plugin management. NvChad provides the UI layer (`base46` theming, tabufline, statusline, `nvchad.term`, and NvChad-bundled plugin defaults). This config layers on top of those defaults rather than replacing them.

## Lua formatting

Use `stylua` (settings in `.stylua.toml`): 120-column width, 2-space indent, double quotes, no call parentheses on standalone calls.

```bash
stylua lua/          # format all Lua files
stylua lua/foo.lua   # format a single file
```

## Architecture

### Load order

`init.lua` enforces this order — changing it breaks things:

```
options → autocmds → commands → mappings
```

`mappings.lua` is deferred via `vim.schedule` so that plugin keymaps are registered first.

### Directory layout

| Path | Purpose |
|------|---------|
| `lua/plugins/*.lua` | lazy.nvim plugin specs (each file returns a table) |
| `lua/configs/fold.lua` | Layered fold config module (treesitter + LSP); called from `autocmds.lua` |
| `lua/chadrc.lua` | NvChad UI/theme config and Mason package list |
| `lua/options.lua` | Vim options extending `nvchad.options` |
| `lua/autocmds.lua` | Autocommands extending `nvchad.autocmds` |
| `lua/mappings.lua` | Keymaps extending `nvchad.mappings` |
| `lua/commands.lua` | Custom user commands |
| `snippets/` | VSCode-format JSON snippet files (loaded via `vim.g.vscode_snippets_path`) |

### Plugin inventory

- **Completion**: `blink.cmp` (sources: lsp + snippets + path; disabled for Markdown)
- **Formatting**: `conform.nvim` — format on save; lua→stylua, go→gofmt, yaml/json/js/ts→prettier
- **Linting**: `nvim-lint` — mypy for Python (only invoked if `mypy` is executable; should come from project venv, not Mason)
- **LSP**: `nvim-lspconfig` — gopls, lua_ls, bashls, jedi_language_server, ruff, ts_ls, eslint; enabled via `vim.lsp.enable()`
- **Motion**: `flash.nvim` — `s`=jump-by-label, `S`=treesitter-node, `<C-t>`=incremental treesitter selection; `tabout.nvim` — `<Tab>`/`<S-Tab>` to jump out of brackets/quotes (loads after `blink.cmp` via `dependencies`)
- **Git**: `gitsigns.nvim` — inline blame on, hunk navigation `]c`/`[c`, hunk actions under `\h` prefix
- **Claude**: `claudecode.nvim` — keymaps under `<leader>a`

### Treesitter

This config uses `neovim-treesitter/nvim-treesitter` (the community fork, not the original `nvim-treesitter/nvim-treesitter`). Always reference it as `"neovim-treesitter/nvim-treesitter"` in plugin specs and dependencies. It requires `neovim-treesitter/treesitter-parser-registry` as a dependency.

### LSP notes

- **Python**: `jedi_language_server` + `ruff` run together. Ruff's hover is disabled in `autocmds.lua` (jedi handles hover). Jedi's own diagnostics are disabled via `init_options` since ruff handles linting. Root detection uses default lspconfig markers (`pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt`, `Pipfile`, `.git`).
- **Mason packages**: declared in `chadrc.lua` under `mason.pkgs`. `mypy`, `flake8`, and `black` are intentionally in `mason.skip` — they must be provided by the project's virtualenv.
- All shell scripts are treated as Bash (`vim.b.is_bash = 1`); macOS uses `/usr/local/bin/bash` as the shell binary.

### Folding

Folding uses a two-layer system defined in `lua/configs/fold.lua` (mirrors LazyVim's approach), wired in via `autocmds.lua`:

- **Layer 1 (FileType)** — upgrades `foldmethod` to `expr` + treesitter `foldexpr` for any filetype that has a TS "folds" query. Silently skips unsupported filetypes (help, terminal, etc.).
- **Layer 2 (LspAttach)** — further upgrades to `vim.lsp.foldexpr()` when the attached LSP server advertises `foldingRangeProvider` (requires Neovim 0.11+).

Both layers use `set_default()`, which won't override options the user has explicitly set for a window/buffer.

Global fallback options (set in `options.lua`): `foldmethod = "indent"`, `foldlevel = 99`, `foldlevelstart = 99` (all folds open by default), `foldtext = ""` (first line used as fold text, Nvim 0.10+), `foldnestmax = 4`. Fold gutter icons are set via `fillchars`.

`chadrc.lua` overrides `Folded = { bg = "#3c3836" }` to make folded regions more visible. Use `zM` to close all folds.
