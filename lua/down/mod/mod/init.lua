local map = require 'down.util.maps'
local mod = require 'down.mod'
local log = require 'down.util.log'
local ins = table.insert

---@class down.mod.Mod: down.Mod
local M = mod.new 'mod'

M.style = {
  table = function(s)
    return '|' .. s .. '|'
  end,
  i = function(s)
    return '__' .. s .. '__'
  end,
  b = function(s)
    return '**' .. s .. '**'
  end,
  code = function(s)
    return '`' .. s .. '`'
  end,
}

M.print = {
  fns = function(m)
  end,
  deps = function(m, tb, pre)
    pre = pre or ''
    if m.dependencies and not vim.tbl_isempty(m.dependencies) then
      ins(tb, pre .. '' .. '- **Dependencies:**')
      for i, d in ipairs(m.dependencies) do
        local ix = M.print.index(i, pre .. '\t')
        ins(tb, ix .. '' .. '`' .. d .. '`')
      end
    end
  end,
  setup = function(m, tb, pre)
    pre = pre or ''
    local s = m.setup()
    if s.loaded then
      ins(tb, M.print.index(nil, pre, 'Loaded', tostring(s.loaded)))
    end
    if s.dependencies then
      M.print.deps(m.setup(), tb, pre)
    end
  end,
  index = function(i, pre, title, value)
    pre = pre or ''
    title = tostring(title or '')
    value = tostring(value or '')
    if title ~= '' then
      title = '**' .. title .. '**: '
    end
    if value ~= '' then
      value = '`' .. value .. '`'
    end
    title = title or ''
    local ix
    if i then
      ix = i .. '. '
    else
      ix = '- '
    end
    return pre .. ix .. title .. value
  end,
  command = function(tb, pre, cmd, v, i)
    local index = M.print.index(i, pre)
    local enabled = ''
    if v.enabled ~= nil then
      enabled = '**enabled**: ' .. '`' .. tostring(v.enabled) .. '`'
    end
    ins(tb, index .. ' __' .. cmd .. "__ `" .. (v.name or '') .. '`' .. ' ' .. enabled)
    M.print.commands(v, tb, cmd, pre, i)
  end,
  commands = function(m, tb, name, pre, i)
    pre = pre or '\t'
    ix = M.print.index(nil, pre)
    if m.commands then
      if vim.tbl_isempty(m.commands) then
        return
      end
      if pre == '' then
        ins(tb, ix .. '**Commands:**')
      end
      local i = 0
      for k, v in pairs(m.commands) do
        i = i + 1
        local ix = M.print.index(i, pre)
        M.print.command(tb, pre .. '\t', k, v, i)
      end
    end
  end,
  mod = function(m, tb, i, name)
    local ix = M.print.index(i)
    ins(tb, '### ' .. (i or '') .. '. ' .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2))
    ins(tb, '')
    -- ins(tb, .. '`' .. (name or m.name or '') .. '`')
    -- M.print.commands(m, tb, m.name, '', i)
    M.print.setup(m, tb, m.name, '')
    M.print.commands(m, tb, m.name, '')
  end,
  title = function(lines)
    ins(lines, '# Mods loaded')
    ins(lines, '')
  end,
  mods = function(tb)
    local lines = tb or {}
    M.print.title(lines)
    ins(lines, '## Mods:')
    ins(lines, '')
    local i = 0
    for name, m in pairs(mod.mods) do
      local s = string.split(name, '.')
      -- if type(s[1]) == 'string' and type(s[2]) == 'string' then
      --   i = 0
      --   local sub = lines[s[1]] or {}
      --   sub[s[2]] = m
      --   M.print.mod(m, sub, i, name)
      --   name = s2
      -- else
      i = i + 1
      M.print.mod(m, lines, i, name)
      table.insert(lines, '---')
      -- end
    end
    return lines
  end,
}

M.commands = {
  mod = {
    enabled = true,
    name = 'mod',
    args = 1,
    callback = function(e)
      log.trace 'Mod.commands.mod: Callback'
    end,
    commands = {
      new = {
        args = 1,
        name = 'mod.new',
        enabled = false,
        callback = function()
          log.trace 'Mod.commands.new: Callback'
        end,
      },
      load = {
        name = 'mod.load',
        args = 1,
        enabled = false,
        callback = function(e)
          local ok = pcall(mod.load_mod, e.body[1])
          if not ok then
            vim.notify(('mod `%s` does not exist!'):format(e.body[1]), vim.log.levels.ERROR, {})
          end
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
          local lines = M.print.mods()
          vim.api.nvim_buf_set_lines(mods_popup.bufnr, 0, -1, true, lines)
          vim.bo[mods_popup.bufnr].modifiable = false
          mods_popup:mount()
        end
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
