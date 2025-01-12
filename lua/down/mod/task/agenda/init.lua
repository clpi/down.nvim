---@type down.Mod
local M = require 'down.mod'.new('task.agenda', {})

---@class down..task.agenda.Agenda
M.Agenda = {

  ---@type lsp.URI
  uri = '',

  ---@type down.Store
  store = {},

  ---@type down.Store
  tasks = {},
}

---@class table<down.mod..task.agenda.Agenda>
M.agendas = {}

---@class down.mod..task.agenda.Config
M.config = {

  ---@type lsp.URI
  uri = '',

  ---@type down.Store
  store = 'data/agendas',
}

---@return down.mod.Setup
M.setup = function()
  ---@type down.mod.Setup
  return {
    dependencies = {},
    loaded = true,
  }
end

M.load = function() end

return M
