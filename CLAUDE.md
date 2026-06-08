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
| `lua/configs/` | Plugin-specific config modules. Use a file here only when the config has real logic, wraps an external call, or is likely to grow. Pure data tables with a single call site belong inline in the plugin spec. |
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
- **LSP**: `nvim-lspconfig` — gopls, lua_ls, bashls, basedpyright, ruff, ts_ls, eslint; enabled via `vim.lsp.enable()`
- **Motion**: `flash.nvim` — `s`=jump-by-label, `S`=treesitter-node, `<C-t>`=incremental treesitter selection
- **Git**: `gitsigns.nvim` — inline blame on, hunk navigation `]c`/`[c`, hunk actions under `\h` prefix
- **Claude**: `claudecode.nvim` — keymaps under `<leader>a`

### LSP notes

- **Python**: `basedpyright` + `ruff` run together. Ruff's hover is disabled in `autocmds.lua` (basedpyright handles hover). `basedpyright` root detection uses `uv.lock` first (uv monorepo root), then `.git`, then `pyrightconfig.json`, then `pyproject.toml`.
- **Mason packages**: declared in `chadrc.lua` under `mason.pkgs`. `mypy`, `flake8`, and `black` are intentionally in `mason.skip` — they must be provided by the project's virtualenv.
- All shell scripts are treated as Bash (`vim.b.is_bash = 1`); macOS uses `/usr/local/bin/bash` as the shell binary.

### Folding

Treesitter-based folding is enabled with `foldlevel = 99` (all folds open by default). Use `zM` to close all folds.
