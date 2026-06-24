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
    vim.lsp.config("jedi_language_server", {
      init_options = {
        diagnostics = {
          enable = false, -- ruff handles diagnostics
        },
      },
    })

    -- Enable configured LSPs.
    -- read :h vim.lsp.config for changing options of lsp servers
    local servers = { "gopls", "lua_ls", "bashls", "jedi_language_server", "ruff", "ts_ls", "eslint" }
    vim.lsp.enable(servers)
  end,
}
