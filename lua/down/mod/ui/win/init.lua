local a, c = vim.api, vim.cmd
local mod = require 'down.mod'
local buf = require('down.util.buf')
local M = require('down.mod').new('ui.win')

---@class ui.win.Win
---@field win integer
---@field buf integer
M.win = {
  buf = 0,
  win = 0,
}

function M.win:close()
  a.nvim_win_close(self.win, true)
  a.nvim_buf_delete(self.buf, { force = true })
  c.redraw()
end

M.setup = function()
  return {
    loaded = true,
    dependencies = {
      -- 'ui'
    },
  }
end
---@class down.ui.win.Config
M.config = {}

M.sel = function()
  local b = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_option(b, 'bufhidden', 'wipe')
  local width = vim.api.nvim_get_option('columns')
  local height = vim.api.nvim_get_option('lines')

  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)

  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local opts = {
    relative = 'editor',
    anchor = 'SW',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = 'none',
    title = 'Hi',
    -- title = "Capture" k...keymaps.capture_cancel..", Save capture: "..keymaps.capture_save,
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(b, true, opts)
  return { b, win }
end
M.win = function(title, foot, cmd)
  local b = vim.api.nvim_create_buf(false, true)
  local w = vim.api.nvim_open_win(b, false, {
    relative = 'editor',
    height = math.ceil(vim.api.nvim_win_get_height(buf.win()) / 2),
    anchor = 'SW',
    width = math.ceil(vim.api.nvim_win_get_width(buf.win()) / 2),
    fixed = true,
    row = 1,
    col = 1,
    focusable = true,
    footer = foot,
    title = title,
    title_pos = 'center',
    border = 'single',
    style = 'minimal',
    footer_pos = 'center',
    noautocmd = true,
  })
  if cmd then
    vim.api.nvim_win_call(w, function()
      vim.cmd(cmd)
    end)
  end
  return { b, w }
end
---@param w integer
---@param f function
M.cmd = function(w, f)
  return vim.api.nvim_win_call(w, f)
end
M.create_new = function()
  local content = [[
  # Hello World

  ![This is a remote image](https://gist.ro/s/remote.png)
  ]]
  local b = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(b, 0, -1, true, vim.split(content, '\n'))
  vim.api.nvim_set_current_buf(b)
  local width = vim.api.nvim_get_option('columns')
  local height = vim.api.nvim_get_option('lines')

  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)

  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local opts = {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = 'rounded',
    title = 'Hi',
    -- title = "Cancel capture: " k...keymaps.capture_cancel..", Save capture: "..keymaps.capture_save,
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(b, true, opts)
  return { b, win }
end

return M
