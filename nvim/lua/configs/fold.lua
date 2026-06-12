--- Layered fold configuration — mirrors LazyVim's approach:
---
---   Layer 1 (FileType)  → tree-sitter folds, only for filetypes that have a
---                          "folds" query; silently skips help/terminal/lazy UI/etc.
---   Layer 2 (LspAttach) → upgrades to vim.lsp.foldexpr() when the attached
---                          server advertises foldingRange support (Neovim 0.11+).
---
--- Both layers use set_default(), which will not override an option the user
--- has explicitly set for a window/buffer.

local M = {}

-- ── Private state ────────────────────────────────────────────────────────────

--- Cache of "lang:folds" → bool so foldexpr() is cheap on repeated calls.
local _query_cache = {} ---@type table<string, boolean>

--- Option values this module has written. Allows re-applying on buffer reload
--- without mistaking our own previous value for a user override.
local _own_defaults = {} ---@type table<string, boolean>

-- ── Helpers ──────────────────────────────────────────────────────────────────

--- Set a window-local option only if the user has not explicitly customized it.
--- Returns true when the option was actually changed.
---
--- Mirrors LazyVim's `LazyVim.set_default()`:
---   safe when  (a) local value == global value  (not user-customized), or
---              (b) current value was previously written by this function itself.
---
---@param option string
---@param value  string|number|boolean
---@param win    integer?   window handle; defaults to current window (0)
---@return boolean was_set
local function set_default(option, value, win)
  local scope_local = win and { scope = "local", win = win } or { scope = "local" }
  local lval = vim.api.nvim_get_option_value(option, scope_local)
  local gval = vim.api.nvim_get_option_value(option, { scope = "global" })

  local own_key = option .. "=" .. tostring(value) -- value we're about to write
  local cur_key = option .. "=" .. tostring(lval) -- value currently in place

  _own_defaults[own_key] = true -- remember this is ours

  if lval == gval or _own_defaults[cur_key] then
    vim.api.nvim_set_option_value(option, value, scope_local)
    return true
  end
  return false
end

--- True when the current buffer's language has both a TS parser and a "folds"
--- query. Result is memoised per language, so calling this from foldexpr is O(1)
--- after the first invocation.
---@return boolean
local function has_ts_folds()
  local ft = vim.bo.filetype
  if ft == "" then
    return false
  end

  local lang = vim.treesitter.language.get_lang(ft)
  if not lang then
    return false
  end

  local key = lang .. ":folds"
  if _query_cache[key] == nil then
    -- inspect() throws if the parser binary is missing — guard with pcall.
    local parser_ok = pcall(vim.treesitter.language.inspect, lang)
    _query_cache[key] = parser_ok and vim.treesitter.query.get(lang, "folds") ~= nil
  end
  return _query_cache[key]
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- foldexpr value — mirrors LazyVim's `LazyVim.treesitter.foldexpr()`:
---   • delegates to vim.treesitter.foldexpr() when a folds query exists
---   • returns "0" (no folding) otherwise, preventing errors in unsupported fts
function M.foldexpr()
  return has_ts_folds() and vim.treesitter.foldexpr() or "0"
end

-- Expose as a named global so the option string below resolves correctly.
-- Usage in foldexpr:  "v:lua.NvFold.foldexpr()"
_G.NvFold = M

--- Wire up the fold autocmds. Call once from autocmds.lua.
function M.setup()
  -- ── Layer 1: tree-sitter, applied per FileType ──────────────────────────
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("fold_treesitter", { clear = true }),
    desc = "Enable tree-sitter folding for supported filetypes",
    callback = function()
      if not has_ts_folds() then
        return
      end
      if set_default("foldmethod", "expr") then
        set_default("foldexpr", "v:lua.NvFold.foldexpr()")
      end
    end,
  })

  -- ── Layer 2: LSP folds, upgrade when server supports foldingRange ────────
  -- vim.lsp.foldexpr was added in Neovim 0.11; skip the whole block on older builds.
  if not vim.lsp.foldexpr then
    return
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("fold_lsp", { clear = true }),
    desc = "Upgrade to LSP folding when the server supports foldingRange",
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then
        return
      end
      if not (client.server_capabilities or {}).foldingRangeProvider then
        return
      end

      -- Defer so Layer 1 (FileType) always runs first, and the LSP parse
      -- tree has stabilised before we hand fold computation to the server.
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(ev.buf) then
          return
        end

        -- Apply to every window that is currently showing this buffer,
        -- using the win= parameter so we never need to switch the current window.
        for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
          if set_default("foldmethod", "expr", win) then
            set_default("foldexpr", "v:lua.vim.lsp.foldexpr()", win)
          end
        end
      end)
    end,
  })
end

return M
