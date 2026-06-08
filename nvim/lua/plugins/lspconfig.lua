return {
  "neovim/nvim-lspconfig",

  config = function()
    -- First use configs from Nvchad/Nvchad.
    require("nvchad.configs.lspconfig").defaults()

    -- Always show diagnostics source.
    -- vim.diagnostics.config performs table merge on config values.
    vim.diagnostic.config {
      virtual_text = { prefix = "", source = true },
      float = { border = "single", source = true },
    }

    -- Add own LSP configs from here on.
    -- Go LSP
    vim.lsp.config("gopls", {
      settings = {
        gopls = {
          completeUnimported = true,
          usePlaceholders = false,
          analyses = {
            unusedparams = true,
          },
        },
      },
    })

    -- Python LSP
    vim.lsp.config("basedpyright", {
      -- NEW: Override workspace root detection.
      -- Without this, nvim-lspconfig's default root_pattern walks upward and
      -- anchors to the nearest pyproject.toml, which is a member project —
      -- not the monorepo root. basedpyright then has no visibility into siblings.
      root_dir = function(bufnr, on_dir)
        local root = vim.fs.root(bufnr, { "uv.lock" }) -- uv workspace root (only ever at monorepo root)
          or vim.fs.root(bufnr, { ".git" }) -- repo root fallback
          or vim.fs.root(bufnr, { "pyrightconfig.json" }) -- explicit pyright config fallback
          or vim.fs.root(bufnr, { "pyproject.toml" }) -- last resort
        if root then
          on_dir(root)
        end
      end,

      settings = {
        basedpyright = {
          disableOrganizeImports = true,
          analysis = {
            autoSearchPaths = false,
            diagnosticMode = "workspace", -- NEW: analyze all files, not just open buffers
            typeCheckingMode = "basic",
            useTypingExtensions = true,
            inlayHints = {
              callArgumentNames = false,
            },
          },
        },
      },
    })

    -- Enable configured LSPs.
    -- read :h vim.lsp.config for changing options of lsp servers
    local servers = { "gopls", "lua_ls", "bashls", "basedpyright", "ruff", "ts_ls", "eslint" }
    vim.lsp.enable(servers)
  end,
}
