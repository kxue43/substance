return {
  "folke/flash.nvim",
  event = "VeryLazy",
  -- Keyboard navigation
  -- fFtT followed by one character and repeated f/F/t/T hits for jump
  keys = {
    -- s for search and jump by label
    {
      "s",
      mode = { "n", "x", "o" },
      function()
        require("flash").jump()
      end,
      desc = "Flash",
    },
    -- S for visually selecting one tree-sitter node
    {
      "S",
      mode = { "n", "o", "x" },
      function()
        require("flash").treesitter()
      end,
      desc = "Flash Treesitter",
    },
    -- In operation pending mode, use r->search->label to jump to another
    -- place and then hit the navigation key to perform the action there.
    -- For example, y**e jumps to destination and yank until end of word.
    {
      "r",
      mode = "o",
      function()
        require("flash").remote()
      end,
      desc = "Remote Flash",
    },
    -- in operation pending or visual mode, use R->search->label to select a
    -- tree-sitter node and perform the action on it.
    -- For example, y** yanks that selected tree-sitter node.
    {
      "R",
      mode = { "o", "x" },
      function()
        require("flash").treesitter_search()
      end,
      desc = "Treesitter Search",
    },
    -- In NeoVim / search, hit <C-s> without typing any character to toggle
    -- NeoVim / search into flash.nvim s mode. Persists across / searches.
    {
      "<c-s>",
      mode = { "c" },
      function()
        require("flash").toggle()
      end,
      desc = "Toggle Flash Search",
    },
    -- Simulate nvim-treesitter incremental selection
    -- S selects one tree-sitter node and stops.
    -- This supports incremental selection.
    {
      "<c-t>",
      mode = { "n", "o", "x" },
      function()
        require("flash").treesitter {
          actions = {
            ["<c-t>"] = "next",
            ["<BS>"] = "prev",
          },
        }
      end,
      desc = "Treesitter Incremental Selection",
    },
  },
}
