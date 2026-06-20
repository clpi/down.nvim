if vim.g.down_loaded then
  return
end
vim.g.down_loaded = true

vim.api.nvim_create_user_command("Down", function(data)
  local ok, down = pcall(require, "down")
  if not ok then
    vim.notify(
      "[down.nvim] Failed to load: " .. tostring(down),
      vim.log.levels.ERROR
    )
    return
  end
  if not down.config.started then
    down.setup(vim.g.down_config or {})
  end
  local cmd_mod = require("down.mod").mods["cmd"]
  if cmd_mod and cmd_mod.cb then
    cmd_mod.cb(data)
  else
    vim.notify("[down.nvim] Command module not loaded", vim.log.levels.WARN)
  end
end, {
  desc = "down.nvim command",
  range = true,
  force = true,
  nargs = "*",
  complete = function(arg_lead, cmd_line, cursor_pos)
    local ok, mod = pcall(require, "down.mod")
    if not ok then
      return {}
    end
    local cmd_mod = mod.mods["cmd"]
    if cmd_mod and cmd_mod.generate_completions then
      return cmd_mod.generate_completions(nil, cmd_line) or {}
    end
    return {}
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "md", "down" },
  once = true,
  callback = function()
    local ok, down = pcall(require, "down")
    if ok and not down.config.started then
      down.setup(vim.g.down_config or {})
    end
  end,
  desc = "Lazy-load down.nvim when editing markdown",
})