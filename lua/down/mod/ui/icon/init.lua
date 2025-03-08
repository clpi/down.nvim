local down = require("down")
local log, mod, utils = down.log, down.mod, down.utils

--- @class down.mod.ui.icon.Icon: down.Mod
local Icon = mod.new("ui.icon", {
  "builtin",
  "basic",
  "complex",
  "diamond",
})
Icon.render = require("down.mod.ui.icon.render")

Icon.mark = require("down.mod.ui.icon.render.mark")

Icon.util = require("down.mod.ui.icon.util")

Icon.setup = function()
  return {
    loaded = true,
    dependencies = {
      "tool.treesitter",
    },
  }
end

Icon.load = function()
  local icon =
      Icon.import[Icon.id .. "." .. Icon.config.icon].config["icon_" .. Icon.config.icon]
  if not icon then
    log.error(
      ("Unable to load icon preset '%s' - such a preset does not exist"):format(
        Icon.config.icon
      )
    )
    return
  end

  Icon.config = vim.tbl_deep_extend(
    "force",
    Icon.config,
    { icons = icon },
    Icon.config.custom or {}
  )

  Icon.commands = {
    toggle = {
      enabled = false,
      callback = function()
        Icon.config.enabled = not Icon.config.enabled
        Icon.render()
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
      Icon.mark.all.mark.changed(bufid)
    end,
  })
end

return Icon
