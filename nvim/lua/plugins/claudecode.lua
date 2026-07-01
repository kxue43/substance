return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    terminal_cmd = "claude --dangerously-skip-permissions",
    terminal = {
      split_width_percentage = 0.45,
    },
  },
  keys = {
    { "<leader>a", nil, desc = "Claude Code" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
    },
    {
      "<leader>aw",
      function()
        local pct_str = vim.fn.input "Claude Code width %: "
        if pct_str == "" then
          return
        end

        local pct = tonumber(pct_str)
        if not pct or pct < 0 or pct > 100 then
          vim.notify("Expected an integer 0–100, got: " .. pct_str, vim.log.levels.WARN)

          return
        end

        local bufnr = require("claudecode.terminal").get_active_terminal_bufnr()
        if not bufnr then
          vim.notify("No active Claude Code terminal", vim.log.levels.WARN)

          return
        end

        local win = vim.fn.bufwinid(bufnr)
        if win == -1 then
          vim.notify("Claude Code terminal is not currently visible", vim.log.levels.WARN)

          return
        end

        vim.api.nvim_win_set_width(win, math.max(1, math.floor(vim.o.columns * pct / 100)))
      end,
      desc = "Set Claude width",
    },
  },
}
