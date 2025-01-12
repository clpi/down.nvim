local map = require 'down.util.maps'
local mod = require 'down.mod'
local log = require 'down.util.log'

---@class down.mod.cmd.Mod: down.Mod
local M = mod.new 'cmd.mod'

M.commands = {
  mod = {
    name = 'mod',
    args = 1,
    callback = function(e)
      log.trace 'Mod.commands.mod: Callback'
    end,
    subcommands = {
      new = {
        args = 1,
        name = 'mod.new',
        callback = function()
          log.trace 'Mod.commands.new: Callback'
        end,
      },
      load = {
        name = 'mod.load',
        args = 1,
        callback = function(e)
          local ok = pcall(mod.load_mod, e.body[1])
          if not ok then
            vim.notify(('mod `%s` does not exist!'):format(e.body[1]), vim.log.levels.ERROR, {})
          end
          vim.print(ok)
        end,
      },
      unload = {
        name = 'mod.unload',
        args = 1,
        callback = function(e)
          log.trace 'Mod.commands.unload: Callback'
        end,
      },
      list = {
        args = 0,
        name = 'mod.list',
        callback = function(e)
          local mods_popup = require 'nui.popup' {
            position = '50%',
            size = { width = '50%', height = '80%' },
            enter = true,
            buf_options = {
              filetype = 'markdown',
              modifiable = true,
              readonly = false,
            },
            win_options = {
              conceallevel = 3,
              concealcursor = 'nvic',
            },
          }
          mods_popup:on('VimResized', function()
            mods_popup:update_layout()
          end)

          local function close()
            mods_popup:unmount()
          end

          mods_popup:map('n', '<Esc>', close, {})
          mods_popup:map('n', 'q', close, {})
          local lines = {}
          table.insert(lines, '# Mods loaded')
          table.insert(lines, '')
          table.insert(lines, '')
          table.insert(lines, '## Mods:')
          table.insert(lines, '')
          table.insert(lines, '')
          for name, _ in pairs(mod.mods) do
            table.insert(lines, '1. `' .. name .. '`')
          end
          vim.api.nvim_buf_set_lines(mods_popup.bufnr, 0, -1, true, lines)
          vim.bo[mods_popup.bufnr].modifiable = false
          mods_popup:mount()
        end,
      },
    },
  },
}
M.maps = {
  { 'n', ',dml', '<CMD>Down mod list<CR>',   'List mods' },
  { 'n', ',dmL', '<CMD>Down mod load<CR>',   'Load mod' },
  { 'n', ',dmu', '<CMD>Down mod unload<CR>', 'Unload mod' },
}
M.setup = function()
  return { loaded = true, dependencies = { 'cmd' } }
end

return M
