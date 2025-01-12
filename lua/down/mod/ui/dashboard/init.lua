local D = require('down.mod').new('ui.dashboard')

D.setup = function()
  return {
    loaded = true,
    dependencies = {},
  }
end

---@class down.ui.dashboard.Config
D.config = {}

return D
