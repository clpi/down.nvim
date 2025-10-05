--- Snacks find module
---
--- @class down.mod.find.snacks.Snacks: down.Mod
local Snacks = require("down.mod").new("find.snacks")

--- @class down.mod.find.snacks.Config: down.mod.Config
Snacks.config = {}

Snacks.setup = function()
  return {
    dependencies = {},
    loaded = pcall(require, "snacks"),
  }
end

Snacks.load = function() end

--- Picker functions for snacks.nvim
Snacks.down = {
  link = function(opts)
    return require("down.mod.find.snacks.picker.link")(opts)
  end,
  tag = function(opts)
    return require("down.mod.find.snacks.picker.tag")(opts)
  end,
  workspace = function(opts)
    -- Reuse workspace picker if available
    local ws_mod = require("down.mod").get_mod("workspace")
    if ws_mod then
      local workspaces = ws_mod.get_workspaces()
      local items = {}
      for name, path in pairs(workspaces) do
        table.insert(items, {
          text = name .. " - " .. path,
          name = name,
          path = path,
        })
      end

      local snacks = require("snacks")
      snacks.picker({
        source = items,
        prompt = "Workspaces",
        format = function(item)
          return item.text
        end,
        confirm = function(item)
          if item then
            ws_mod.set_workspace(item.name)
          end
        end,
      })
    end
  end,
  file = function(opts)
    local snacks = require("snacks")
    snacks.picker.files(opts)
  end,
  note = function(opts)
    local snacks = require("snacks")
    snacks.picker.files(opts)
  end,
  task = function(opts)
    -- TODO: implement task picker
    vim.notify("Task picker not yet implemented for snacks", vim.log.levels.WARN)
  end,
}

Snacks.picker = Snacks.down

return Snacks
