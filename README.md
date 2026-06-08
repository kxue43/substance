# Shell & Substance

## Getting started

```bash
mkdir -p ~/.config
git clone https://github.com/kxue43/dotfiles ~/.config/dotfiles
~/.config/dotfiles/set-up.sh
```

See [GitHub pages](https://kxue43.github.io/notes-and-blogs/) for dependency installations.

## MCP servers

Use `mcp-remote` as a wrapper because it handles OAuth better than Claude Code does for streamable-http MCP servers.

```bash
claude mcp add --scope user jarvis-registry -- npx -y mcp-remote@latest https://jarvis.ascendingdc.com/gateway/proxy/mcpgw/mcp
```
