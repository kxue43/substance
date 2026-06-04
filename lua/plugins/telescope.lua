return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = "Telescope",
    opts = {
      defaults = {
        file_ignore_patterns = {
          "__pycache__/",
          "%.pyc$",
          "%.pyi$",
        },
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          "--glob",
          "!**/.git/*",
        },
      },
    },
  },
}
