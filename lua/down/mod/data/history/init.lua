local tbl = require 'table'
local clear = require 'table.clear'
local new = require 'table.new'
local mod = require 'down.mod'

---@class down.mod.data.History: down.Mod
local M = mod.new 'data.history'

---@class down.mod.data.history.Config: down.mod.Config
M.config = {
  silent = true,
  path = '',
}

---@class down.mod.data.history.Commands
M.commands = {
  next = {
    args = 0,
    enabled = true,
    condition = 'markdown',
    name = 'data.history.forward',
    subcommands = {
      list = {
        enabled = true,
        args = 0,
        condition = 'markdown',
        name = 'data.history.forward.list',
      },
    },
  },
  back = {
    args = 0,
    condition = 'markdown',
    enabled = true,
    name = 'data.history.back',
    subcommands = {
      list = {
        args = 0,
        condition = 'markdown',
        enabled = true,
        name = 'data.history.back.list',
      },
    },
  },
}

--- @type integer[]
M.history = {
  ---@type integer[]
  hist = {},
  --- @type integer[]
  buf = {},
  ---@type string[]
  file = {},
}

M.history.buf = {}

--- Clear the stacks
M.clear = function()
  clear(M.history.hist)
  clear(M.history.file)
  clear(M.history.buf)
end

M.add = {}

M.add.file = function(buf)
  table.insert(M.history.file, buf or vim.api.nvim_get_current_buf())
end
M.add.current = function(buf)
  table.insert(M.history.buf, buf or vim.api.nvim_get_current_buf())
end

M.push = function(stack, buf)
  table.insert(stack or M.history.buf, 1, buf or vim.api.nvim_get_current_buf())
end

M.pop = function(stack, buf)
  table.remove(stack or M.history.buf, 1)
end

M.print = function(self)
  for i, v in ipairs(self) do
    print(i, v.path, v.buf)
  end
end

M.back = function()
  local bn = vim.api.nvim_get_current_buf()
  if bn > 1 and #M.history.buf > 0 then
    M.push(M.history.hist, bn)
    local prev = M.history.buf[1] or 0
    vim.api.nvim_command('buffer ' .. prev)
    M.pop(M.history.buf)
    return true
  else
    if M.config.silent then
      vim.api.nvim_echo({ { "Can't go back again", 'WarningMsg' } }, true, {})
    end
    return false
  end
end

M.forward = function()
  local cb = vim.api.nvim_get_current_buf()
  local hb = M.history.hist[1]
  if hb then
    M.push(M.history.buf, cb)
    vim.api.nvim_command('buffer ' .. hb)
    M.pop(M.history.hist)
    return true
  else
    if not M.config.silent then
      vim.api.nvim_echo({ { "Can't go forward again", 'WarningMsg' } }, true, {})
    end
    return false
  end
end

---@class down..history.Config
M.config = {

  store = 'data/stores',
}

---@return down.mod.Setup
M.setup = function()
  ---@type down.mod.Setup
  return {
    dependencies = {
      'cmd',
    },
    loaded = true,
  }
end

M.commands = {
  prev = {
    args = 0,
    condition = 'markdown',
    name = 'data.history.back',
  },
  next = {
    args = 0,
    condition = 'markdown',
    name = 'data.history.forward',
  },
}

M.handle = {
  cmd = {
    ['data.history.back'] = function(e)
      local buffers = vim.api.nvim_list_buf()

      local to_delete = {}
      for buffer in vim.iter(buffers):rev() do
        if vim.fn.buflisted(buffer) == 1 then
          if not vim.endswith(vim.api.nvim_buf_get_name(buffer), '.md') then
            vim.api.nvim_win_set_buf(0, buffer)
            break
          else
            table.insert(to_delete, buffer)
          end
        end
      end

      for _, buffer in ipairs(to_delete) do
        vim.api.nvim_buf_delete(buffer, {})
      end
    end,
  },
}

return M
