return {
  -- test new blink
  { import = "nvchad.blink.lazyspec" },

  {
    "saghen/blink.cmp",
    opts = function()
      local options = require "nvchad.blink.config"

      options.keymap = {
        preset = "super-tab",
        ["<CR>"] = { "accept", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<Down>"] = { "select_next", "snippet_forward", "fallback" },
        ["<Up>"] = { "select_prev", "snippet_backward", "fallback" },
      }

      options.enabled = function()
        -- Disable completion in Markdown files.
        return not vim.tbl_contains({ "markdown" }, vim.bo.filetype)
      end

      -- Compared to the NvChad default, 'buffer' is removed to disable text completion.
      options.sources = { default = { "lsp", "snippets", "path" } }

      return options
    end,
  },
}
