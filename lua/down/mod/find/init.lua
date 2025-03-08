local cfg = require("down.config")
local mod = require("down.mod")

---@alias down.mod.find.Findinder "telescope" | "mini" | "snacks" | "fzflua" | "builtin"

local has_telescope, _ = pcall(require, "telescope")
local has_mini, _ = pcall(require, "mini.pick")
local has_snacks, _ = pcall(require, "mini.snacks")
local has_fzflua, _ = pcall(require, "fzflua")

---@class down.mod.find.Findind: down.Mod
local Find = mod.new("find")

---@class down.mod.find.Config: down.mod.Config
---@field public default? down.mod.find.Findinder The default finder
---@field public finders? down.mod.find.Findinder[] The default finder
Find.config = {
  default = nil,
  finders = nil,
  enabled = true,
}

---@alias down.mod.find.Picker
---| 'file'
---| 'link'
---| 'tag'
---| 'workspace'
---| 'task'
---| 'note'
---| 'template'
---| 'markdown'
---| 'project'

---@param n down.mod.find.Picker
---@return fun()|table
Find.picker = function(n)
  local p = require("down.mod.find." .. Find.config.default)
  if p and p.picker then
    Find.picker = p.picker
  end
  if n and p.down and p.down[n] then
    if type(p.down[n]) == "function" then
      return p.down[n]
    end
  end
  return p
end

---@class down.mod.find.telescope.Commands: { [string]: down.Command }
Find.commands = {
  find = {
    args = 0,
    name = "find",
    enabled = true,
    callback = function(e)
      Find.picker("file")()
    end,
    commands = {
      tags = {
        callback = function(e)
          Find.picker("tag")()
        end,
        enabled = false,
        name = "find.links",
        args = 0,
      },
      project = {
        callback = function(e)
          Find.picker("project")()
        end,
        enabled = false,
        name = "find.links",
        args = 0,
      },
      notes = {
        callback = function(e)
          Find.picker("note")()
        end,
        enabled = false,
        name = "find.links",
        args = 0,
      },
      links = {
        callback = function(e)
          Find.picker("link")()
        end,
        enabled = true,
        name = "find.links",
        args = 0,
      },
      tasks = {
        callback = function(e)
          Find.picker("task")()
        end,
        enabled = true,
        name = "find.tags",
        args = 0,
      },
      files = {
        callback = function(e)
          Find.picker("file")()
        end,
        enabled = true,
        name = "find.files",
        args = 0,
      },
      workspace = {
        callback = function(e)
          Find.picker("workspace")()
        end,
        enabled = true,
        name = "find.workspace",
        args = 0,
      },
    },
  },
}

---@class down.mod.find.Maps: { [string]: down.Map }
Find.maps = {
  { "n", ",dFind", "<cmd>Down find file<CR>",     "Down find files" },
  { "n", ",dm",    "<cmd>Down find markdown<CR>", "Down find md files" },
  { "n", ",dL",    "<cmd>Down find link<CR>",     "Down find links" },
  {
    "n",
    ",dW",
    "<cmd>Down find workspace<CR>",
    "Down find workspaces",
  },
}

Find.data = {}

Find.load = function()
  if not Find.config.finders then
    Find.config.finders = { "builtin" }
    if has_telescope then
      table.insert(Find.config.finders, "telescope")
    end
    if has_mini then
      table.insert(Find.config.finders, "mini")
    end
    if has_snacks then
      table.insert(Find.config.finders, "snacks")
    end
    if has_fzflua then
      table.insert(Find.config.finders, "fzflua")
    end
  end
  if not Find.config.default then
    if #Find.config.finders > 0 then
      if vim.list_contains(Find.config.finders, "telescope") then
        Find.config.default = "telescope"
      else
        Find.config.default = Find.config.finders[1]
      end
    else
      table.insert(Find.config.finders, "builtin")
      Find.config.default = "builtin"
    end
  end
  Find.picker = require("down.mod.find." .. Find.config.default).picker
end

Find.setup = function()
  return {
    loaded = true,
    dependencies = Find.config.finders,
  }
end

Find.after = function()
  -- TODO: should load and register telescope extension if it is available
end

return Find
