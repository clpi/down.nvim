local down = require('down')

local Sidebar = require('down.mod').new('ui.sidebar')

Sidebar.setup = function()
  return {
    loaded = true,
  }
end

---@class down.ui.sidebar.Config
Sidebar.config = {}

return Sidebar
