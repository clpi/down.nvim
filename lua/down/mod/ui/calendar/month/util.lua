local lib = require 'down.util.lib'

local M = {}

M.display_win = function(lines)
  local width, height = 44, 32
  local buffer = vim.api.nvim_create_buf(false, true)
  local window = vim.api.nvim_open_win(buffer, true, {
    style = 'minimal',
    border = 'rounded',
    title = ' Calendar ',
    title_pos = 'center',
    row = (vim.o.lines / 2) - height / 2,
    col = (vim.o.columns / 2) - width / 2,
    width = width,
    height = height,
    relative = 'editor',
    noautocmd = true,
  })
  vim.api.nvim_set_option_value('winfixbuf', true, { win = window })

  local function quit()
    vim.api.nvim_win_close(window, true)
    pcall(vim.api.nvim_buf_delete, buffer, { force = true })
  end

  vim.keymap.set('n', 'q', quit, { buffer = buffer })

  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    buffer = buffer,
    callback = quit,
  })

  local namespace = vim.api.nvim_create_namespace 'down.mod.ui.calendar.help'
  vim.api.nvim_buf_set_option(buffer, 'modifiable', false)

  vim.api.nvim_buf_set_extmark(buffer, namespace, 0, 0, {
    virt_lines = lines,
  })
end

M.view_name = 'month'

M.maps = function() end

M.open_view = function(view, date, ui_info, options)
  local should_redraw = false

  if view.current_mode.handle_select ~= nil then
    should_redraw = view.current_mode:on_select(date)
  end

  if should_redraw then
    view:render_view(ui_info, date, nil, options)
  end
end

M.show_help = function()
  lib.wrap(M.display_win, {
    {
      { 'q', '@namespace' },
      { ' - ' },
      { 'close this window', '@text.strong' },
    },
    {
      { '<CR>', '@namespace' },
      { ' - ' },
      { 'confirm date', '@text.strong' },
    },
    {},
    {
      { '--- Quitting ---', '@text.title' },
    },
    {},
    {
      { '<C-c> (insert mode)', '@namespace' },
      { ' - ' },
      { 'quit', '@text.strong' },
    },
    {
      { '<Esc>', '@namespace' },
      { ' - ' },
      { 'quit', '@text.strong' },
    },
    {},
    {
      { '--- Date Syntax ---', '@text.title' },
    },
    {},
    {
      { 'Order ' },
      { 'does not matter', '@text.strong' },
      { ' with dates.' },
    },
    {},
    {
      { 'Some things depend on locale.' },
    },
    {},
    {
      { 'Months and weekdays may be written' },
    },
    {
      { 'with a shorthand.' },
    },
    {},
    {
      { 'Years must contain 4 digits at' },
    },
    {
      { 'all times. Prefix with zeroes' },
    },
    {
      { 'where necessary.' },
    },
    {},
    {
      { 'Hour syntax: `00:00.00` (hour, min, sec)' },
    },
    {},
    {
      { '--- Examples ---', '@text.title' },
    },
    {},
    {
      { 'Tuesday May 5th 2023 19:00.23', '@down.markup.verbatim' },
    },
    {
      { '10 Feb CEST 0600', '@down.markup.verbatim' },
      { ' (', '@comment' },
      { '0600', '@text.emphasis' },
      { ' is the year)', '@comment' },
    },
    {
      { '9:00.4 2nd March Wed', '@down.markup.verbatim' },
    },
  })
end
function M.reformat_time(date)
  return os.date('*t', os.time(date))
end

function M.fmt(y, m, d)
  return M.reformat_time {
    year = y,
    month = m,
    day = d,
  }
end

return M
