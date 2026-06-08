return {
  -- Always load which-key.
  {
    "folke/which-key.nvim",
    lazy = false,
  },

  -- Add onto nvim-tree defaults.
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      filters = {
        git_ignored = false,
        dotfiles = false,
      },
      filesystem_watchers = {
        enable = true,
        ignore_dirs = { ".venv", "__pycache__", "*.egg-info", ".mypy_cache", ".pytest_cache", ".ruff_cache" },
      },
      actions = {
        expand_all = {
          exclude = { ".venv", ".git", "__pycache__", ".mypy_cache", ".pytest_cache", ".ruff_cache" },
        },
      },
    },
  },

  -- Ensure tree-sitter parsers.
  {
    "neovim-treesitter/nvim-treesitter",
    dependencies = { "neovim-treesitter/treesitter-parser-registry" },
    opts = {
      ensure_installed = {
        "go",
        "bash",
        "python",
        "javascript",
        "typescript",
        "java",
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
        "awk",
        "markdown",
        "markdown_inline",
      },
    },
    lazy = false,
    branch = "main",
  },
}
