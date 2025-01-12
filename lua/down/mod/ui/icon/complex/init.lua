local down = require('down')
local mod = down.mod

local M = mod.new('ui.icon.diamond')

---@class down.ui.icon.diamond.Config
M.config = {
  icon_diamond = {
    heading = {
      icons = { '◈', '◇', '◆', '⋄', '❖', '⟡' },
    },

    footnote = {
      single = {
        icon = '†',
      },
      multi_prefix = {
        icon = '‡ ',
      },
      multi_suffix = {
        icon = '‡ ',
      },
    },
  },
}

return M
