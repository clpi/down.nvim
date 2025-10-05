local down = require 'down'
local mod = require 'down.mod'
local util = require 'down.util'
local log = require 'down.log'

local Calendar = mod.new 'ui.calendar'

Calendar.maps = {
  { 'n', ',d.', '<CMD>Down calendar<CR>', 'Open calendar' },
  { 'n', ',do', '<CMD>Down calendar<CR>' },
  { 'n', ',dl', '<CMD>Down calendar<CR>' },
}
Calendar.setup = function()
  return {
    loaded = true,
    dependencies = {
      'ui',
      'ui.calendar.day',
      'ui.calendar.month',
    },
  }
end

Calendar.modes = {}
Calendar.view = {}

Calendar.get_mode = function(name, callback)
  if Calendar.modes[name] ~= nil then
    local curr = Calendar.modes[name](callback)
    curr.id = name
    return curr
  end
  log.error 'Error: mode not set or not available'
end

Calendar.get_view = function(name)
  if Calendar.view[name or 'month'] ~= nil then
    return Calendar.view[name or 'month']
  end
  log.error 'Error: view not set or not available'
end

Calendar.extract_ui_info = function(buffer, window)
  local width = vim.api.nvim_win_get_width(window)
  local height = vim.api.nvim_win_get_height(window)

  local half_width = math.floor(width / 2)
  local half_height = math.floor(height / 2)

  return {
    window = window,
    buffer = buffer,
    width = width,
    height = height,
    half_width = half_width,
    half_height = half_height,
  }
end

Calendar.open_window = function(options)
  local MIN_HEICalendarHT = 14

  local buffer, window = Calendar.dep['ui'].new_split(
    'Calendar ' .. tostring(os.clock()):gsub('%.', '-'),
    {},
    options.height or MIN_HEICalendarHT + (options.padding or 0)
  )

  vim.bo.filetype = 'down-calendar'
  vim.api.nvim_create_autocmd({ 'WinClosed', 'BufDelete' }, {
    buffer = buffer,
    callback = function()
      pcall(vim.api.nvim_win_close, window, true)
      pcall(vim.api.nvim_buf_delete, buffer, { force = true })
    end,
  })

  return buffer, window
end
Calendar.add_mode = function(name, factory)
  Calendar.modes[name] = factory
end

Calendar.add_view = function(name, details)
  log.trace('Calendar.add_view: ', name, details)
  Calendar.view[name] = details
end

Calendar.new_calendar = function(buffer, window, options)
  local callback_and_close = function(result)
    if options.callback ~= nil then
      options.callback(result)
    end

    pcall(vim.api.nvim_win_close, window, true)
    pcall(vim.api.nvim_buf_delete, buffer, { force = true })
  end

  local mode = Calendar.get_mode(options.mode, callback_and_close)
  if mode == nil then
    return
  end

  local ui_info = Calendar.extract_ui_info(buffer, window)

  local v = Calendar.get_view(options.view or 'month')

  v.setup_view(ui_info, mode, options.date or os.date '*t', options)
end

Calendar.open = function(options)
  local buffer, window = Calendar.open_window(options)

  options.mode = 'standalone'

  return Calendar.new_calendar(buffer, window, options)
end

Calendar.select_date = function(options)
  local buffer, window = Calendar.open_window(options)
  options.mode = 'select_date'
  return Calendar.new_calendar(buffer, window, options)
end

Calendar.select_date_range = function(options)
  local buffer, window = Calendar.open_window(options)
  options.mode = 'select_range'
  return Calendar.new_calendar(buffer, window, options)
end

Calendar.load = function()
  Calendar.add_mode('standalone', function(_)
    return {}
  end)

  Calendar.add_mode('select_date', function(callback)
    return {
      on_select = function(_, date)
        if callback then
          callback(date)
        end
        return false
      end,
    }
  end)

  Calendar.add_mode('select_range', function(callback)
    return {
      range_start = nil,
      range_end = nil,

      on_select = function(self, date)
        if not self.range_start then
          self.range_start = date
          return true
        else
          if os.time(date) <= os.time(self.range_start) then
            log.error 'Error: you should choose a date that is after the starting day.'
            return false
          end

          self.range_end = date
          callback({ self.range_start, self.range_end })
          return false
        end
      end,

      get_day_highlight = function(self, date, base_highlight)
        if self.range_start ~= nil then
          if os.time(date) < os.time(self.range_start) then
            return '@comment'
          end
        end
        return base_highlight
      end,
    }
  end)
end

return Calendar
