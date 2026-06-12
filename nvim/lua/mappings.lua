require "nvchad.mappings"

local map = vim.keymap.set
local del = vim.keymap.del

-- Delete the "toggle relative number" key map set by NvChad.
del("n", "<leader>rn")

-- Delete the "toggle floating term", "toggle vertical term" and "toggle horizontal term" key maps set by NvChad.
del({ "n", "t" }, "<A-i>")
del({ "n", "t" }, "<A-v>")
del({ "n", "t" }, "<A-h>")

-- Delete the <C-x> key map that escape terminal mode. Use <C-\\><C-n> instead.
-- <C-x> is reserved for Readline.
del("t", "<C-x>")

-- Show full path of the current buffer.
map("n", "\\eb", function()
  print(vim.fn.expand "%:p")
end, { desc = "Echo full file path of the current buffer." })

-- Telescope find file under certain directory.
map("n", "<leader>fu", function()
  local dir = vim.fn.input {
    prompt = "Find under directory: ",
    default = "",
    completion = "dir",
  }

  dir = vim.fn.fnamemodify(dir, ":p")

  if vim.fn.isdirectory(dir) ~= 1 then
    vim.notify("Error: " .. dir .. " is not a directory.", vim.log.levels.ERROR)

    return
  end

  require("telescope.builtin").find_files {
    cwd = dir,
  }
end, { desc = "telescope find files under the specified directory." })

-- Telescope grep under certain directory.
map("n", "<leader>gu", function()
  local dir = vim.fn.input {
    prompt = "Grep under directory: ",
    default = "",
    completion = "dir",
  }

  require("telescope.builtin").live_grep {
    cwd = dir,
  }
end, { desc = "telescope live grep under the specified directory." })

-- Telescope find file from highlighted
map("v", "<leader>ff", function()
  -- The callback runs while still in visual mode context, so '< / '> marks
  -- haven't been committed yet. Yank to a temporary register instead, mirroring
  -- how telescope's own grep_string handles visual selections.
  local saved = vim.fn.getreg "v"
  vim.cmd [[noautocmd sil norm! "vy]]
  local selection = vim.fn.getreg "v"
  vim.fn.setreg("v", saved)

  require("telescope.builtin").find_files {
    default_text = selection,
  }
end, { desc = "telescope find files from visual selection." })

-- Toggle the current htoggleTerm between bottom and fullscreen.
map("t", "<A-k>", function()
  -- Get alternate buffer number.
  local alt_buf = vim.fn.bufnr "#"

  if alt_buf == -1 or not vim.api.nvim_buf_is_valid(alt_buf) then
    -- If alternate buffer doesn't exist or is invalid, just return.
    return
  end

  if vim.fn.bufwinnr(alt_buf) > 0 then
    -- If alternate buffer is visible, terminal window is at the bottom. Make it fullscreen.

    -- Exit from terminal mode to normal mode.
    vim.cmd.stopinsert()

    -- Move to the window above the terminal.
    vim.cmd "wincmd k"

    -- Hide the window.
    vim.cmd "hide"

    -- Return to insert mode in the terminal window
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a", true, false, true), "n", false)
  else
    -- If alternate buffer is not visible, terminal window is fullscreen. Resize it to bottom.

    -- switch to alternate buffer.
    vim.api.nvim_set_current_buf(alt_buf)

    -- Open up terminal at the bottom again.
    require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
  end
end, { desc = "Toggle the current htoggleTerm between bottom and fullscreen." })

-- Open the current htoggleTerm and make it fullscreen.
map("n", "<A-k>", function()
  -- Open the current htoggleTerminal.
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }

  -- Make it fullscreen.

  -- Exit from terminal mode to normal mode.
  vim.cmd.stopinsert()

  -- Move to the window above the terminal.
  vim.cmd "wincmd k"

  -- Hide the window.
  vim.cmd "hide"

  -- Return to insert mode in the terminal window
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a", true, false, true), "n", false)
end, { desc = "Toggle the current htoggleTerm between bottom and fullscreen." })

map({ "n" }, "<A-h>", function()
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end, { desc = "Open a new htoggleTerm at the bottom of the window." })

map("t", "<A-h>", function()
  -- Get alternate buffer number
  local alt_buf = vim.fn.bufnr "#"

  if alt_buf == -1 or not vim.api.nvim_buf_is_valid(alt_buf) then
    -- If alternate buffer doesn't exist or is invalid, just return.
    return
  end

  if vim.fn.bufwinnr(alt_buf) > 0 then
    -- If alternate buffer is visible, terminal is already at bottom.
    -- Just use "nvchad.term.toggle" to hide it.
    require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
  else
    -- If alternate buffer is not visible, set it as the current buffer,
    -- and terminal is automatically hidden.
    vim.api.nvim_set_current_buf(alt_buf)
  end
end, { desc = "Hide the current htoggleTerm, fullscreen or not." })

-- Wrap words under cursor inside backticks
local function wrap_in_backticks(boundary_pat)
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local cur = col + 1 -- convert to 1-indexed for Lua string ops

  if cur > #line or line:sub(cur, cur):match(boundary_pat) then
    return
  end

  local word_start = cur
  while word_start > 1 and not line:sub(word_start - 1, word_start - 1):match(boundary_pat) do
    word_start = word_start - 1
  end

  local word_end = cur
  while word_end < #line and not line:sub(word_end + 1, word_end + 1):match(boundary_pat) do
    word_end = word_end + 1
  end

  local new_line = line:sub(1, word_end) .. "`" .. line:sub(word_end + 1)
  new_line = new_line:sub(1, word_start - 1) .. "`" .. new_line:sub(word_start)
  vim.api.nvim_set_current_line(new_line)
end

map({ "n" }, "<leader>wg", function()
  wrap_in_backticks "%s"
end, {
  desc = "Wrap greedily the current words under cursor inside backticks. Boundaries are leftmost and right most empty space characters.",
})

map({ "n" }, "<leader>wl", function()
  wrap_in_backticks "[%s,.:;]"
end, {
  desc = "Wrap lazily the current words under cursor inside backticks. Boundaries are leftmost and right most empty space character, comma, period, colon, semi-colon.",
})

-- Close all unmodified buffers
map({ "n" }, "\\bc", function()
  local cur = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= cur and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and not vim.bo[buf].modified then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end, { desc = "Close all unmodified buffers except the current one." })

-- Jumping out of terminal mode
map({ "t" }, "<A-n>", function()
  vim.cmd.stopinsert()
end, { desc = "Jumping out of terminal mode." })

-- Dedent in the plus register
map({ "n" }, "<leader>dp", function()
  local text = vim.fn.getreg "+"
  local lines = vim.split(text, "\n", { plain = true })

  local prefix = nil
  for _, line in ipairs(lines) do
    if line:match "%S" then
      local indent = line:match "^(%s*)"
      if prefix == nil then
        prefix = indent
      else
        local i = 1
        while i <= #prefix and i <= #indent and prefix:sub(i, i) == indent:sub(i, i) do
          i = i + 1
        end
        prefix = prefix:sub(1, i - 1)
      end
    end
  end

  if not prefix or prefix == "" then
    return
  end

  for i, line in ipairs(lines) do
    if line:sub(1, #prefix) == prefix then
      lines[i] = line:sub(#prefix + 1)
    end
  end

  vim.fn.setreg("+", table.concat(lines, "\n"))
end, { desc = "Dedent the string in the plug register." })

local function buf_relpath()
  local bufpath = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
  if bufpath == "" then
    return nil
  end
  local git_root = vim.fs.root(bufpath, { ".git" })
  local root = (git_root or vim.fn.resolve(vim.fn.getcwd())) .. "/"
  return bufpath:sub(1, #root) == root and bufpath:sub(#root + 1) or bufpath
end

-- put Claude Code style line range reference in the plus register
map({ "x" }, "<leader>ks", function()
  local relpath = buf_relpath()
  if not relpath then
    return
  end
  local start_line = vim.fn.line "v"
  local end_line = vim.fn.line "."
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  vim.fn.setreg("+", string.format("@%s#L%d-%d", relpath, start_line, end_line))
end, { desc = "Put Claude Code line range reference in the plus register." })

-- put Claude Code style file reference in the plus register
map({ "n" }, "<leader>kb", function()
  local relpath = buf_relpath()
  if not relpath then
    return
  end
  vim.fn.setreg("+", "@" .. relpath)
end, { desc = "Put Claude Code file reference in the plus register." })
