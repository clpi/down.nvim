local tbl = require 'table'
local clear = require 'table.clear'
local new = require 'table.new'
---@class down.Mod
local M = require 'down.mod'.new('data.history', {})

M.config = {
  silent = true,
}

M.commands = {
  back = {
    args = 0,
    condition = 'markdown',
    name = 'data.history.back',
  },
}

--- Buffer queue
--- @type table<number, integer>
M.history = {}

--- @type table<number, integer>
M.buf = {}

--- Clear the stacks
M.clear = function()
  clear(M.history)
  clear(M.buf)
end

M.push = function(stack, buf)
  table.insert(stack or M.buf, 1, buf or vim.api.nvim_get_current_buf())
end

M.pop = function(stack, buf)
  table.remove(stack or M.buf, 1)
end

M.print = function(self)
  for i, v in ipairs(self) do
    print(i, v.path, v.buf)
  end
end

M.back = function()
  local bn = vim.api.nvim_get_current_buf()
  if bn > 1 and #M.buf > 0 then
    M.push(M.history, bn)
    local prev = M.buf[1]
    vim.api.nvim_command('buffer ' .. prev)
    M.pop(M.buf)
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
  local hb = M.history[1]
  if hb then
    M.push(M.buf, cb)
    vim.api.nvim_command('buffer ' .. hb)
    M.pop(M.history)
    return true
  else
    if not M.config.silent then
      vim.api.nvim_echo({ { "Can't go forward again", 'WarningMsg' } }, true, {})
    end
    return false
  end
end

---@alias down..history.Store down.Store Store
---@type down..history.Store Store
M.store = {}

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

M.handle = function(event)
  if event.id == 'cmd.events..history.back' then
    -- Get all the buffers
  end
end

M.handle = {
  cmd = {
    ['data.history.back'] = function(e)
      local buffers = vim.api.nvim_list_bufs()

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
