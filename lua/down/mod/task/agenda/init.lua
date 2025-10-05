---@type down.Agendaod
local Agenda = require 'down.mod'.new('task.agenda', {})

---@class down..task.agenda.Agenda
Agenda.Agenda = {

  ---@type lsp.URI
  uri = '',

  ---@type down.Store
  store = {},

  ---@type down.Store
  tasks = {},
}

---@class table<down.mod.task.agenda.Agenda>
Agenda.agendas = {}

---@class down.mod..task.agenda.Config
Agenda.config = {

  ---@type lsp.URI
  uri = '',

  ---@type down.Store
  store = 'data/agendas',
}

---@return down.mod.Setup
Agenda.setup = function()
  ---@type down.mod.Setup
  return {
    dependencies = {},
    loaded = true,
  }
end

Agenda.load = function() end

return Agenda
