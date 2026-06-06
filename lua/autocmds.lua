require "nvchad.autocmds"

local map = vim.keymap.set

-- NvChad's nvdash and terminal set `number = false` as a window-local option.
-- NeoVim copies window-local options to new splits, so opening any split from
-- those windows propagates the missing line numbers. Re-assert it on entry.
vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function(args)
    if vim.bo[args.buf].buftype == "" then
      vim.wo.number = true
    end
  end,
})

-- All shell scripts are in Bash.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "bash", "sh" },
  callback = function()
    vim.g.is_bash = 1
  end,
})

-- For Markdown files, map "\\ll" to `toolkit-show-md`.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    map("n", "\\ll", function()
      local curr_file = vim.fn.expand "%:p"

      vim.fn.system("toolkit-show-md " .. curr_file .. " >/dev/null 2>&1")
    end, { buffer = true, desc = "Convert and show the current Markdown file in browswer." })
  end,
})

-- For JS/TS files, add the "grl" mapping.
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  callback = function()
    map("n", "grl", function()
      vim.cmd "LspTypescriptSourceAction"
    end, { buffer = true, desc = "List TypeScript source actions." })
  end,
})

-- The ruff and basedpyright LSPs are used together. Disable hover capability from ruff.
-- In configs.lspconfig, disable certain capabilities of basedpyright to use ruff exclusively for linting and formatting.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_attach_disable_ruff_hover", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client == nil then
      return
    end
    if client.name == "ruff" then
      -- Disable hover in favor of basedpyright
      client.server_capabilities.hoverProvider = false
    end
  end,
  desc = "LSP: Disable hover capability from Ruff",
})
