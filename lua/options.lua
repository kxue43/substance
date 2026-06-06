require "nvchad.options"

-- add yours here!
vim.filetype.add {
  extension = {
    bashrc = "bash",
    sh = "bash",
  },
}

local o = vim.o

-- Enable folding via treesitter.
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldlevel = 99 -- Open all folds by default; Use zM to close all.

-- o.cursorlineopt ='both' -- to enable cursorline!
