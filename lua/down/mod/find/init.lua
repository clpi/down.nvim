local cfg = require("down.config")
local mod = require("down.mod")

---@alias down.mod.find.Finder "telescope" | "mini" | "snacks" | "fzflua" | "builtin"

local has_telescope, _ = pcall(require, "telescope")
local has_mini, _ = pcall(require, "mini.pick")
local has_snacks, _ = pcall(require, "mini.snacks")
local has_fzflua, _ = pcall(require, "fzflua")

---@class down.mod.find.Find: down.Mod
local F = mod.new("find")

---@class down.mod.find.Config: down.mod.Config
---@field public default? down.mod.find.Finder The default finder
---@field public finders? down.mod.find.Finder[] The default finder
F.config = {
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
F.picker = function(n)
  local p = require("down.mod.find." .. F.config.default)
  if p and p.picker then
    F.picker = p.picker
  end
  if n and p.down and p.down[n] then
    if type(p.down[n]) == "function" then
      return p.down[n]
    end
  end
  return p
end

---@class down.mod.find.telescope.Commands: { [string]: down.Command }
F.commands = {
  find = {
    args = 0,
    name = "find",
    enabled = true,
    callback = function(e)
      F.picker("file")()
    end,
    commands = {
      tags = {
        callback = function(e)
          F.picker("tag")()
        end,
        enabled = false,
        name = "find.links",
        args = 0,
      },
      project = {
        callback = function(e)
          F.picker("project")()
        end,
        enabled = false,
        name = "find.links",
        args = 0,
      },
      notes = {
        callback = function(e)
          F.picker("note")()
        end,
        enabled = false,
        name = "find.links",
        args = 0,
      },
      links = {
        callback = function(e)
          F.picker("link")()
        end,
        enabled = true,
        name = "find.links",
        args = 0,
      },
      tasks = {
        callback = function(e)
          F.picker("task")()
        end,
        enabled = true,
        name = "find.tags",
        args = 0,
      },
      files = {
        callback = function(e)
          F.picker("file")()
        end,
        enabled = true,
        name = "find.files",
        args = 0,
      },
      workspace = {
        callback = function(e)
          F.picker("workspace")()
        end,
        enabled = true,
        name = "find.workspace",
        args = 0,
      },
    },
  },
}

---@class down.mod.find.Maps: { [string]: down.Map }
F.maps = {
  { "n", ",dF", "<cmd>Down find file<CR>", "Down find files" },
  { "n", ",dm", "<cmd>Down find markdown<CR>", "Down find md files" },
  { "n", ",dL", "<cmd>Down find link<CR>", "Down find links" },
  {
    "n",
    ",dW",
    "<cmd>Down find workspace<CR>",
    "Down find workspaces",
  },
}

F.data = {}

F.load = function()
  if not F.config.finders then
    F.config.finders = { "builtin" }
    if has_telescope then
      table.insert(F.config.finders, "telescope")
    end
    if has_mini then
      table.insert(F.config.finders, "mini")
    end
    if has_snacks then
      table.insert(F.config.finders, "snacks")
    end
    if has_fzflua then
      table.insert(F.config.finders, "fzflua")
    end
  end
  if not F.config.default then
    if #F.config.finders > 0 then
      if vim.list_contains(F.config.finders, "telescope") then
        F.config.default = "telescope"
      else
        F.config.default = F.config.finders[1]
      end
    else
      table.insert(F.config.finders, "builtin")
      F.config.default = "builtin"
    end
  end
  F.picker = require("down.mod.find." .. F.config.default).picker
end

F.setup = function()
  return {
    loaded = true,
    dependencies = F.config.finders,
  }
end

F.post_load = function()
  -- TODO: should load and register telescope extension if it is available
end

return F
