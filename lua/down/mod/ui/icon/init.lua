local down = require("down")
local log, mod, utils = down.log, down.mod, down.utils

local M = mod.new("ui.icon", {
  "builtin",
  "basic",
  "complex",
  "diamond",
})
M.render = require("down.mod.ui.icon.render")

M.mark = require("down.mod.ui.icon.render.mark")

M.util = require("down.mod.ui.icon.util")

M.setup = function()
  return {
    loaded = true,
    dependencies = {
      "tool.treesitter",
    },
  }
end

M.load = function()
  local icon =
    M.import[M.id .. "." .. M.config.icon].config["icon_" .. M.config.icon]
  if not icon then
    log.error(
      ("Unable to load icon preset '%s' - such a preset does not exist"):format(
        M.config.icon
      )
    )
    return
  end

  M.config = vim.tbl_deep_extend(
    "force",
    M.config,
    { icons = icon },
    M.config.custom or {}
  )

  M.commands = {
    toggle = {
      enabled = false,
      callback = function()
        M.config.enabled = not M.config.enabled
        M.render()
      end,
      completion = function()
        return { "on", "off" }
      end,
      name = "icon.toggle",
      args = 0,
      condition = "markdown",
    },
  }

  vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "conceallevel",
    callback = function()
      local bufid = vim.api.nvim_get_current_buf()
      if vim.bo[bufid].ft ~= "markdown" then
        return
      end
      M.mark.all.mark.changed(bufid)
    end,
  })
end

return M
