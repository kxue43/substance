require "nvchad.options"

-- add yours here!
vim.filetype.add {
  extension = {
    bashrc = "bash",
    sh = "bash",
  },
}

local o = vim.opt

-- ── Folding ─────────────────────────────────────────────────────────────────
o.foldlevel = 99 -- keep all folds open in the current window
o.foldlevelstart = 99 -- open all folds when entering any new buffer
o.foldmethod = "indent" -- safe global fallback; autocmds upgrade to "expr" per-ft
o.foldtext = "" -- use the first (highlighted) line as fold text (Nvim 0.10+)
o.foldnestmax = 4 -- cap indent-fallback nesting depth (no effect when foldmethod=expr)

o.fillchars:append {
  foldopen = "", -- icon for an open fold in the sign column
  foldclose = "", -- icon for a closed fold
  fold = " ", -- fill character for fold lines
  foldsep = " ", -- separator between folds
}

-- o.cursorlineopt ='both' -- to enable cursorline!
