local mod = require 'down.mod'
local log = require 'down.util.log'

---@type down.Mod
local M = mod.new 'ui'

M.load = function()
  for _, i in pairs(M.import) do
    M = vim.tbl_extend('force', M, i)
  end
end
M.setup = function()
  return {
    namespace = vim.api.nvim_create_namespace 'down.mod.ui',
    dependencies = {},
    loaded = true,
  }
end

---@class down.mod.ui.Config
M.config = {}
M.namespace = vim.api.nvim_create_namespace 'down.mod.ui'
--- Returns a table in the form of { width, height } containing the width and height of the current window
---@param half boolean #If true returns a position that could be considered the center of the window
M.get_window_size = function(half)
  return half
      and {
        math.floor(vim.fn.winwidth(0) / 2),
        math.floor(vim.fn.winheight(0) / 2),
      }
    or { vim.fn.winwidth(0), vim.fn.winheight(0) }
end

--- Returns a modified version of floating window options.
---@param modifiers table #This option set has two values - center_x and center_y.
--                           If they either of them is set to true then the window gets centered on that axis.
---@param config table #A table containing regular Neovim options for a floating window
M.apply_custom_options = function(modifiers, config)
  -- base modifier options
  local user_options = {
    center_x = false,
    center_y = false,
  }

  -- Override the base options with the user provided options
  user_options = vim.tbl_extend('force', user_options, modifiers or {})

  -- Assign some base values to certain config options in case they're not specified
  vim.tbl_deep_extend('keep', config, {
    relative = 'win',
    row = 0,
    col = 0,
    width = 100,
    height = 100,
  })
  -- Get the current window's dimensions except halved
  local halved_window_size = M.get_window_size(true)
  -- If we want to center along the x axis then return a configuration that does so
  if user_options.center_x then
    config.row = config.row + halved_window_size[2] - math.floor(config.height / 2)
  end

  -- If we want to center along the y axis then return a configuration that does so
  if user_options.center_y then
    config.col = config.col + halved_window_size[1] - math.floor(config.width / 2)
  end

  return config
end

--- Applies a set of options to a buffer
---@param buf number the buffer number to apply the options to
---@param option_list table a table of option = value pairs
M.apply_buffer_options = function(buf, option_list)
  for option_name, value in pairs(option_list or {}) do
    vim.api.nvim_set_option_value(option_name, value, { buf = buf })
  end
end

---Creates a new horizontal split at the bottom of the screen
---@param  name string the name of the buffer contained within the split (will have down:// prepended to it)
---@param  config table? a table of <option> = <value> keypairs signifying buffer-local options for the buffer contained within the split
---@param  height number? the height of the new split
---@return number?, number? #Both the buffer ID and window ID
M.new_split = function(name, config, height)
  vim.validate {
    name = { name, 'string' },
    { config, 'table', true },
    height = { height, 'number', true },
  }
  local bufname = 'down://' .. name
  if vim.fn.bufexists(bufname) == 1 then ---@diagnostic disable-line
    log.error("Buffer '" .. name .. "' already exists")
    return
  end
  vim.cmd 'below new'
  if height then
    vim.api.nvim_win_set_height(0, height)
  end
  local buf = vim.api.nvim_win_get_buf(0)

  local base_options = {
    swapfile = false,
    bufhidden = 'hide',
    buftype = 'nofile',
    buflisted = false,
    filetype = 'markdown',
  }
  vim.api.nvim_buf_set_name(buf, bufname)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_option(0, 'list', false)
  vim.api.nvim_win_set_option(0, 'colorcolumn', '')
  vim.api.nvim_win_set_option(0, 'number', false)
  vim.api.nvim_win_set_option(0, 'relativenumber', false)
  vim.api.nvim_win_set_option(0, 'signcolumn', 'no')

  -- Merge the user provided options with the base options and apply them to the new buffer
  M.apply_buffer_options(buf, vim.tbl_extend('keep', config or {}, base_options))

  local window = vim.api.nvim_get_current_win()

  -- Make sure to clean up the window if the user leaves the popup at any time
  vim.api.nvim_create_autocmd({ 'BufDelete', 'WinClosed' }, {
    buffer = buf,
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, window, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end,
  })

  return buf, window
end

--- Creates a new vertical split
---@param name string the name of the buffer
---@param enter boolean enter the window or not
---@param buf_config table a table of <option> = <value> keypairs signifying buffer-local options for the buffer contained within the split
---@param win_config table table of <option>=<value> keypairs for `nvim_open_win`, must provide `win`
---@return number?, number? #The buffer and window numbers of the vertical split
M.new_vsplit = function(name, enter, buf_config, win_config)
  vim.validate {
    name = { name, 'string' },
    enter = { enter, 'boolean', true },
    { buf_config, 'table' },
    window = { win_config, 'table' },
  }

  local buf = vim.api.nvim_create_buf(false, true)

  local base_options = {
    swapfile = false,
    bufhidden = 'hide',
    buftype = 'nofile',
    buflisted = false,
    filetype = 'markdown',
  }

  vim.api.nvim_buf_set_name(buf, 'down://' .. name)
  local win_options = {
    vertical = true,
  }
  win_options = vim.tbl_deep_extend('keep', win_options, win_config)
  local window = vim.api.nvim_open_win(buf, enter, win_options)
  vim.api.nvim_set_option_value('number', false, { win = window })
  vim.api.nvim_set_option_value('relativenumber', false, { win = window })
  M.apply_buffer_options(buf, vim.tbl_extend('keep', buf_config or {}, base_options))
  vim.api.nvim_create_autocmd({ 'BufDelete', 'WinClosed' }, {
    buffer = buf,
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, window, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end,
  })

  return buf, window
end

--- Creates a new display in which you can place organized data
---@param name string #The name of the display
---@param split_type string #"vsplitl"|"vsplitr"|"split"|"nosplit" - if suffixed with "l" vertical split will be spawned on the left, else on the right. "split" is a horizontal split.
---@param content table #A table of content for the display
M.new_display = function(name, split_type, content)
  if not vim.tbl_contains({ 'nosplit', 'vsplitl', 'vsplitr', 'split' }, split_type) then
    log.error(
      "Unable to create display. Expected one of 'vsplitl', 'vsplitr', 'split' or 'nosplit', got",
      split_type,
      'instead.'
    )
    return
  end
  local namespace = vim.api.nvim_create_namespace('down://display/' .. name)
  local buf = (function()
    name = 'display/' .. name

    if split_type == 'vsplitl' then
      return M.new_vsplit(name, true, {}, { split = 'left' })
    elseif split_type == 'vsplitr' then
      return M.new_vsplit(name, true, {}, { split = 'right' })
    elseif split_type == 'split' then
      return M.new_split(name, {})
    else
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_name(buf, name)
      return buf
    end
  end)()
  vim.api.nvim_win_set_buf(0, buf)
  local length = vim.fn.len(vim.tbl_filter(function(elem)
    return vim.tbl_isempty(elem) or (elem[3] == nil and true or elem[3])
  end, content))
  vim.api.nvim_buf_set_lines(
    buf,
    0,
    length,
    false,
    vim.split(('\n'):rep(length), '\n', { plain = true })
  )
  local line_number = 1
  local buffer = {}
  for i, text_info in ipairs(content) do
    if not vim.tbl_isempty(text_info) then
      local newline = text_info[3] == nil and true or text_info[3]
      table.insert(buffer, { text_info[1], text_info[2] or 'Normal' })
      if i == #content or newline then
        vim.api.nvim_buf_set_extmark(0, namespace, line_number - 1, 0, {
          virt_text_pos = 'overlay',
          virt_text = buffer,
        })
        buffer = {}
        line_number = line_number + 1
      end
    else
      line_number = line_number + 1
    end
  end
  vim.keymap.set('n', '<Esc>', vim.cmd.bdelete, { buffer = buf, silent = true })
  vim.keymap.set('n', 'q', vim.cmb.bdelete, { buffer = buf, silent = true })
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  local cached_virtualedit = vim.opt.virtualedit:get()
  vim.opt.virtualedit = 'all'
  vim.api.nvim_create_autocmd({ 'BufLeave', 'BufDelete' }, {
    buffer = buf,
    callback = function()
      vim.opt.virtualedit = cached_virtualedit
      pcall(vim.api.nvim_win_close, 0, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end,
  })
  vim
    .cmd([[autocmd BufLeave,BufDelete <buffer=%s> set virtualedit=%s | silent! bd! %s]])
    :format(buf, cached_virtualedit[1] or '', buf)

  return { buffer = buf, namespace = namespace }
end

--- Creates a new down buffer in a split or in the main window
---@param name string the name of the buffer *without* the .down extension
---@param split_type string "vsplitl"|"vsplitr"|"split"|"nosplit" - if suffixed with "l" vertical split will be spawned on the left, else on the right. "split" is a horizontal split.
---@param config table|nil a table of { option = value } pairs that set buffer-local options for the created down buffer
---@param opts table|nil
---   - opts.keys (boolean)             if false, will not use the base keys
---   - opts.del_on_autocmd (table)    delete buffer on specified autocmd
M.new_markdown_buffer = function(name, split_type, config, opts)
  vim.validate({
    name = { name, 'string' },
    split_type = { split_type, 'string' },
    { config, 'table', true },
    opts = { opts, 'table', true },
  })
  vim.tbl_deep_extend('keep', config or {}, {
    ft = 'markdown',
  })
  opts = vim.tbl_deep_extend(
    'force',
    { keys = true, del_on_autocmd = { 'BufLeave', 'BufDelete', 'BufUnload' } },
    opts or {}
  )
  if not vim.tbl_contains({ 'nosplit', 'vsplitl', 'vsplitr', 'split' }, split_type) then
    log.error(
      "Unable to create display. Expected one of 'vsplitl', 'vsplitr', 'split' or 'nosplit', got"
        .. split_type
        .. 'instead.'
    )
    return
  end
  local buf = (function()
    name = 'down/' .. name .. '.md'

    if split_type == 'vsplitl' then
      return M.new_vsplit(name, true, {}, { split = 'left' })
    elseif split_type == 'vsplitr' then
      return M.new_vsplit(name, true, {}, { split = 'right' })
    elseif split_type == 'split' then
      return M.new_split(name, {})
    else
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_name(buf, name)
      return buf
    end
  end)()
  vim.api.nvim_win_set_buf(0, buf)
  if opts.keys == true then
    vim.keymap.set('n', '<Esc>', vim.cmd.bdelete, { buffer = buf, silent = true })
    vim.keymap.set('n', 'q', vim.cmd.bdelete, { buffer = buf, silent = true })
  end
  M.apply_buffer_options(buf, config or {})
  if opts.del_on_autocmd and #opts.del_on_autocmd ~= 0 then
    vim.cmd(
      'autocmd '
        .. opts.del_on_autocmd:concat ','
        .. (' <buffer=%s> silent! bd! %s'):format(buf, buf)
    )
  end
  return buf
end

return M
