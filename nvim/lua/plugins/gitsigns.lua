return {
  -- Add Gitsigns key maps.
  {
    "lewis6991/gitsigns.nvim",
    event = "User FilePost",
    opts = {
      current_line_blame = true,

      on_attach = function(bufnr)
        local gitsigns = require "gitsigns"

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map("n", "]c", function()
          if vim.wo.diff then
            vim.cmd.normal { "]c", bang = true }
          else
            gitsigns.nav_hunk "next"
          end
        end, { desc = "Next diff or next hunk." })

        map("n", "[c", function()
          if vim.wo.diff then
            vim.cmd.normal { "[c", bang = true }
          else
            gitsigns.nav_hunk "prev"
          end
        end, { desc = "Previous diff or previous hunk." })

        -- Actions
        map("n", "\\hs", gitsigns.stage_hunk, { desc = "Stage/unstage hunk." })
        map("n", "\\hr", gitsigns.reset_hunk, { desc = "Reset hunk." })
        map("n", "\\hp", gitsigns.preview_hunk, { desc = "Preview hunk." })
        map("n", "\\hi", gitsigns.preview_hunk_inline, { desc = "Preview hunk inline." })

        map("v", "\\hs", function()
          gitsigns.stage_hunk { vim.fn.line ".", vim.fn.line "v" }
        end, { desc = "Stage/unstage visually selected hunk." })

        map("v", "\\hr", function()
          gitsigns.reset_hunk { vim.fn.line ".", vim.fn.line "v" }
        end, { desc = "Reset visually selected hunk." })

        map("n", "\\hS", gitsigns.stage_buffer, { desc = "Stage buffer." })
        map("n", "\\hR", gitsigns.reset_buffer, { desc = "Reset buffer." })

        map("n", "\\hb", gitsigns.blame_line, { desc = "Blame current line." })

        map("n", "\\hd", gitsigns.diffthis, { desc = "Buffer git diff" })

        map("n", "\\hD", function()
          gitsigns.diffthis "~"
        end, { desc = "Buffer git diff --cached" })

        map("n", "\\hq", gitsigns.setqflist, { desc = "Show hunks of current buffer." })
        map("n", "\\hQ", function()
          gitsigns.setqflist "all"
        end, { desc = "Show hunks of whole repository." })

        -- Toggles
        map("n", "\\tb", gitsigns.toggle_current_line_blame, { desc = "Toggle line blame." })
        map("n", "\\tw", gitsigns.toggle_word_diff, { desc = "Toggle word diff." })
      end,
    },
  },
}
