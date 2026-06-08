vim.api.nvim_create_user_command("KMan", function(opts)
  vim.cmd(":Man " .. opts.args .. " | only ")
end, { desc = "Open man page in new buffer.", nargs = "+" })
