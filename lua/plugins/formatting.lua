return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- uncomment for format on save
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        go = { "gofmt" },
        yaml = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        ["javascript.jsx"] = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        ["typescript.tsx"] = { "prettier" },
      },

      default_format_opts = {
        lsp_format = "fallback",
      },

      format_on_save = {
        timeout_ms = 1000,
      },

      formatters = {
        prettier = {
          prepend_args = { "--ignore-path", "/dev/null", "--stdin-filepath", "$FILENAME" },
        },
      },
    },
  },
}
