local down = require 'down'
local util = require 'down.util'
local mutil = require 'down.mod.ui.calendar.month.util'
local view = require 'down.mod.ui.calendar.month.view'
local lib = util.lib
local log = util.log
local mod = down.mod
local key, api = vim.keymap, vim.api

---@class done.mod.ui.calendar.Month: down.Mod
local M = mod.new 'ui.calendar.month'

---@return down.mod.Setup
M.setup = function()
  return {
    loaded = true,
    dependencies = {
      'ui.calendar',
      'data.time',
    },
  }
end

M.view_name = 'month'
M.setup_view = function(ui_info, mode, date, opts)
  opts.distance = opts.distance or 4
  local v = M.new_view_instance()
  v.current_mode = mode
  v:render_view(ui_info, date, nil, opts)
  do
    key.set('n', 'q', function()
      api.nvim_buf_delete(ui_info.buffer, { force = true })
    end, { buffer = ui_info.buffer })

    -- TODO: Make cursor wrapping behaviour rable
    key.set('n', 'l', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = date.day + 1 * vim.v.count1,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'h', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = date.day - 1 * vim.v.count1,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'j', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = date.day + 7 * vim.v.count1,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'k', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = date.day - 7 * vim.v.count1,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', '<cr>', function()
      local redraw = false
      if v.current_mode.handle_select ~= nil then
        vim.print('v.current_mode.handle_select ~= nil')
        redraw = v.current_mode:on_select(date)
      end
      if redraw then
        vim.print('redraw')
        v:render_view(ui_info, date, nil, opts)
      end
    end, { buffer = ui_info.buffer })

    key.set('n', 'L', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month + vim.v.count1,
        day = date.day,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'H', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month - vim.v.count1,
        day = date.day,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'm', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month + vim.v.count1,
        day = 1,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'M', function()
      if date.day > 1 then
        date.month = date.month + 1
      end
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month - vim.v.count1,
        day = 1,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'y', function()
      local new_date = mutil.reformat_time {
        year = date.year + vim.v.count1,
        month = date.month,
        day = date.day,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'Y', function()
      local new_date = mutil.reformat_time {
        year = date.year - vim.v.count1,
        month = date.month,
        day = date.day,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', '$', function()
      local new_day = date.day - (lib.number_wrap(date.wday - 1, 1, 7) - 1) + 6
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = new_day,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    local start_of_week = function()
      local new_day = date.day - (lib.number_wrap(date.wday - 1, 1, 7) - 1)
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = new_day,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end

    key.set('n', '0', start_of_week, { buffer = ui_info.buffer })
    key.set('n', '_', start_of_week, { buffer = ui_info.buffer })

    key.set('n', 't', function()
      local new_date = os.date '*t'

      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'e', function()
      local end_of_current_month = M.get_month_length(date.month, date.year)
      if end_of_current_month > date.day then
        date.month = date.month - 1
      end
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month + vim.v.count1,
        day = M.get_month_length(date.month + vim.v.count1, date.year),
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'E', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month - vim.v.count1,
        day = M.get_month_length(date.month - vim.v.count1, date.year),
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'w', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = date.day + 7 * vim.v.count1,
      }
      new_date.day = new_date.day - (lib.number_wrap(new_date.wday - 1, 1, 7) - 1)
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'W', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = date.day - 7 * vim.v.count1,
      }
      new_date.day = new_date.day - (lib.number_wrap(new_date.wday - 1, 1, 7) - 1)
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    local months = {}
    for i = 1, 12 do
      table.insert(
        months,
        (os.date('%B', os.time { year = 2000, month = i, day = 1 }) --[[@as string]]):lower()
      )
    end

    -- store the last `;` repeatable search
    local last_semi_jump = nil
    -- flag to set when we're using `;` so it doesn't cycle
    local skip_next = false

    key.set('n', ';', function()
      if last_semi_jump then
        api.nvim_feedkeys(last_semi_jump, 'm', false)
      end
    end, { buffer = ui_info.buffer })

    key.set('n', ',', function()
      if last_semi_jump then
        local action = string.sub(last_semi_jump, 1, 1)
        local subject = string.sub(last_semi_jump, 2)
        local new_keys
        if string.upper(action) == action then
          new_keys = action:lower() .. subject
        else
          new_keys = action:upper() .. subject
        end
        api.nvim_feedkeys(new_keys, 'm', false)

        skip_next = true
      end
    end, { buffer = ui_info.buffer })

    key.set('n', 'f', function()
      local char = vim.fn.getcharstr()

      for i = date.month + 1, date.month + 12 do
        local m = lib.number_wrap(i, 1, 12)
        if months[m]:match('^' .. char) then
          if not skip_next then
            last_semi_jump = 'f' .. char
          else
            skip_next = false
          end

          local new_date = mutil.reformat_time {
            year = date.year,
            month = m,
            day = date.day,
          }
          v:render_view(ui_info, new_date, date, opts)
          date = new_date
          break
        end
      end
    end, { buffer = ui_info.buffer })

    key.set('n', 'F', function()
      local char = vim.fn.getcharstr()

      for i = date.month + 11, date.month, -1 do
        local m = lib.number_wrap(i, 1, 12)
        if months[m]:match('^' .. char) then
          if not skip_next then
            last_semi_jump = 'F' .. char
          else
            skip_next = false
          end
          local new_date = mutil.reformat_time {
            year = date.year,
            month = m,
            day = date.day,
          }
          v:render_view(ui_info, new_date, date, opts)
          date = new_date
          break
        end
      end
    end, { buffer = ui_info.buffer })

    key.set('n', 'g', function()
      local day = math.min(vim.v.count1, M.get_month_length(date.month, date.year))

      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = day,
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer, nowait = true })

    key.set('n', 'G', function()
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = M.get_month_length(date.month, date.year),
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer })

    key.set('n', 'd', function()
      local n = vim.v.count1
      local wkd = math.min(n, 7)
      local new_date = mutil.reformat_time {
        year = date.year,
        month = date.month,
        day = date.day + (wkd - lib.number_wrap(date.wday - 1, 1, 7)),
      }
      v:render_view(ui_info, new_date, date, opts)
      date = new_date
    end, { buffer = ui_info.buffer, nowait = true })

    key.set(
      'n',
      '?',
      lib.wrap(M.display_win, {
        {
          { 'q', '@ns' },
          { ' - ' },
          { 'close this window', '@text.strong' },
        },
        {},
        {
          { '<CR>', '@ns' },
          { ' - ' },
          { 'select date', '@text.strong' },
        },
        {},
        {
          { '--- Basic Movement ---', '@text.title' },
        },
        {},
        {
          { 'l/h', '@ns' },
          { ' - ' },
          { 'next/previous day', '@text.strong' },
        },
        {
          { 'j/k', '@ns' },
          { ' - ' },
          { 'next/previous week', '@text.strong' },
        },
        {
          { 'w/W', '@ns' },
          { ' - ' },
          { 'start of next/this or previous week', '@text.strong' },
        },
        {
          { 't', '@ns' },
          { ' - ' },
          { 'today', '@text.strong' },
        },
        {
          { 'd', '@ns' },
          { 'n' },
          { ' - ' },
          { 'wkd ', '@text.strong' },
          { 'n' },
          { ' (1 = monday)', '@text.strong' },
        },
        {},
        {
          { '--- Moving Between Months ---', '@text.title' },
        },
        {},
        {
          { 'L/H', '@ns' },
          { ' - ' },
          { 'next/previous month (same day)', '@text.strong' },
        },
        {
          { 'm/M', '@ns' },
          { ' - ' },
          { '1st of next/this or previous month', '@text.strong' },
        },
        {
          { 'f', '@ns' },
          { 'x' },
          { '/F', '@ns' },
          { 'x' },
          { ' - ' },
          { 'next/previous month starting with ', '@text.strong' },
          { 'x' },
        },
        {},
        {
          { '--- Moving Between Years ---', '@text.title' },
        },
        {},
        {
          { 'y/Y', '@ns' },
          { ' - ' },
          { 'next/previous year (same day)', '@text.strong' },
        },
        {
          { 'gy', '@ns' },
          { ' - ' },
          { 'start of the current year', '@text.strong' },
        },
        {
          { 'c/C', '@ns' },
          { ' - ' },
          { 'next/this or previous century', '@text.strong' },
        },
        {
          { 'g/G', '@ns' },
          { ' - ' },
          { 'start/end of month', '@text.strong' },
        },
        {
          { '      ' },
          { '<n>g takes you to <n> day of the month', '@text.strong' },
        },
        {},
        {
          { '--- Additional Info ---', '@text.title' },
        },
        {},
        {
          { 'All movements accept counts' },
        },
        {
          { 'f/F and g/G work with `;` and `,`' },
        },
      }),
      { buffer = ui_info.buffer }
    )

    key.set('n', 'i', function()
      local buffer = api.nvim_create_buf(false, true)
      api.nvim_open_win(buffer, true, {
        style = 'minimal',
        border = 'single',
        title = 'Date (`?` for help)',
        row = api.nvim_win_get_height(0),
        col = 0,
        width = vim.o.columns,
        height = 1,
        relative = 'win',
        win = api.nvim_get_current_win(),
        noautocmd = true,
      })

      vim.cmd.startinsert()

      local function quit()
        vim.cmd.stopinsert()
        api.nvim_buf_delete(buffer, { force = true })
      end

      key.set('n', '<Esc>', quit, { buffer = buffer })
      key.set('i', '<C-c>', quit, { buffer = buffer })
      key.set('n', '?', lib.wrap(), { buffer = buffer })

      key.set({ 'n', 'i' }, '<CR>', function()
        local line = api.nvim_buf_get_lines(buffer, 0, -1, true)[1]

        local parsed_date = M.dep['time'].parse_date(line)

        if type(parsed_date) == 'string' then
          log.error('[ERROR]:', parsed_date)
          return
        end

        quit()

        local lua_date = M.dep['time'].to_lua_date(parsed_date)

        local should_redraw = false

        if v.current_mode.handle_select ~= nil then
          should_redraw = v.current_mode:on_select(lua_date)
        end

        if should_redraw then
          v:render_view(ui_info, lua_date, nil, opts)
        end
      end, { buffer = buffer })
    end, { buffer = ui_info.buffer })
  end
end

M.ns = {
  logical = api.nvim_create_namespace 'down.mod.ui.calendar.logical',
  decorational = api.nvim_create_namespace 'down.mod.ui.calendar.decorational',
}

M.set_extmark = function(ui_info, ns, row, col, length, virt_text, alignment, extra)
  if alignment then
    local text_length = 0

    for _, tuple in ipairs(virt_text) do
      vim.print('textlen', text_length, 'tuple[1]', tuple[1])
      text_length = text_length + string.len(tuple[1])
    end

    if alignment == 'center' then
      col = col + (ui_info.half_width - math.floor(text_length / 2))
    elseif alignment == 'right' then
      col = col + (ui_info.width - text_length)
    end
  end

  local base_extra = {
    virt_text = virt_text,
    virt_text_pos = 'overlay',
  }

  if length then
    base_extra.end_col = col + length
  end

  return api.nvim_buf_set_extmark(
    ui_info.buffer,
    ns,
    row,
    col,
    vim.tbl_deep_extend('force', base_extra, extra or {})
  )
end

M.set_decorational_extmark = function(ui_info, row, col, length, virt_text, alignment, extra)
  return M.set_extmark(ui_info, M.ns.decorational, row, col, length, virt_text, alignment, extra)
end

M.set_logical_extmark = function(ui_info, row, col, virt_text, alignment, extra)
  return M.set_extmark(ui_info, M.ns.logical, row, col, nil, virt_text, alignment, extra)
end

M.new_view_instance = function()
  return {
    current_mode = {},
    extmarks = {
      decorational = {
        calendar_text = nil,
        help_and_custom_input = nil,
        current_view = nil,
        month_headings = {},
        wkd_displays = {},
      },
      logical = {
        year = nil,
        months = {
          -- [3] = { [31] = <id> }
        },
      },
    },

    -- TODO: implemant distance like in render_wkd_banner
    render_month_banner = function(self, ui_info, date, wkd_banner_extmark_id)
      local month_name =
        os.date('%B', os.time { year = date.year, month = date.month, day = date.day })
      ---@cast month_name string
      local month_length = api.nvim_strwidth(month_name)
      local wkd_banner_id =
        api.nvim_buf_get_extmark_by_id(ui_info.buffer, M.ns.decorational, wkd_banner_extmark_id, {
          details = true,
        })

      self.extmarks.decorational.month_headings[wkd_banner_extmark_id] = M.set_decorational_extmark(
        ui_info,
        4,
        wkd_banner_id[2]
          + math.ceil((wkd_banner_id[3].end_col - wkd_banner_id[2]) / 2)
          - math.floor(month_length / 2),
        month_length,
        { { month_name, '@text.underline' } },
        nil,
        {
          id = self.extmarks.decorational.month_headings[wkd_banner_extmark_id],
        }
      )
    end,

    render_wkd_banner = function(self, ui_info, offset, distance)
      offset = offset or 0
      distance = distance or 4

      -- Render the days of the week
      -- To effectively do this, we grab all the wkds from a constant time.
      -- This makes the wkds retrieved locale dependent (which is what we want).
      local wkds = {}
      local wkds_string_length = 0
      for i = 1, 7 do
        local wkd = os.date('%a', os.time { year = 2000, month = 5, day = i })
        ---@cast wkd string
        local truncated = util.truncate_by_cell(wkd, 2)
        local truncated_length = api.nvim_strwidth(truncated)
        wkds[#wkds + 1] = { truncated, '@text.title' }
        wkds[#wkds + 1] = { (' '):rep(4 - truncated_length) }
        wkds_string_length = truncated_length -- remember last day's length
      end
      wkds[#wkds] = nil -- delete last padding
      wkds_string_length = wkds_string_length + 4 * 6

      -- This serves as the index of this week banner extmark inside the extmark table
      local absolute_offset = offset + (offset < 0 and (-offset * 100) or 0)

      local extmark_position = 0

      -- Calculate offset position only for the previous and following months
      if offset ~= 0 then
        extmark_position = (wkds_string_length * math.abs(offset)) + (distance * math.abs(offset))
      end

      -- For previous months, revert the offset
      if offset < 0 then
        extmark_position = -extmark_position
      end

      local wkd_banner_id = M.set_decorational_extmark(
        ui_info,
        6,
        extmark_position,
        wkds_string_length,
        wkds,
        'center',
        {
          id = self.extmarks.decorational.wkd_displays[absolute_offset],
        }
      )

      self.extmarks.decorational.wkd_displays[absolute_offset] = wkd_banner_id

      return wkd_banner_id
    end,

    render_month = function(self, ui_info, target_date, wkd_banner_extmark_id)
      --> Month rendering routine
      -- We render the first month at the very center of the screen. Each
      -- month takes up a static amount of characters.

      -- Render the top text of the month (June, August etc.)
      -- Render the numbers for wkds
      local days_of_month = {
        -- [day of month] = <day of week>,
      }

      local current_date = os.date '*t'

      local month, year = target_date.month, target_date.year

      local days_in_current_month = M.get_month_length(month, year)

      for i = 1, days_in_current_month do
        days_of_month[i] = tonumber(os.date(
          '%u',
          os.time {
            year = year,
            month = month,
            day = i,
          }
        ))
      end

      local beginning_of_wkd_extmark =
        api.nvim_buf_get_extmark_by_id(ui_info.buffer, M.ns.decorational, wkd_banner_extmark_id, {})

      local render_column = days_of_month[1] - 1
      local render_row = 1

      self.extmarks.logical.months[month] = self.extmarks.logical.months[month] or {}

      for day_of_month, day_of_week in ipairs(days_of_month) do
        local is_current_day = current_date.year == year
          and current_date.month == month
          and day_of_month == current_date.day

        local start_row = beginning_of_wkd_extmark[1] + render_row
        local start_col = beginning_of_wkd_extmark[2] + (4 * render_column)

        if is_current_day then
          -- TODO: Make this rable. The user might want the cursor to start
          -- on a specific date in a specific month.
          -- Just look up the extmark and place the cursor there.
          api.nvim_win_set_cursor(ui_info.window, { start_row + 1, start_col })
        end

        local day_highlight = is_current_day and '@text.todo' or nil

        if self.current_mode.get_day_highlight then
          day_highlight = self.current_mode:get_day_highlight({
            year = year,
            month = month,
            day = day_of_month,
          }, day_highlight)
        end

        self.extmarks.logical.months[month][day_of_month] =
          api.nvim_buf_set_extmark(ui_info.buffer, M.ns.logical, start_row, start_col, {
            virt_text = {
              {
                (day_of_month < 10 and '0' or '') .. tostring(day_of_month),
                day_highlight,
              },
            },
            virt_text_pos = 'overlay',
            id = self.extmarks.logical.months[month][day_of_month],
          })

        if day_of_week == 7 then
          render_column = 0
          render_row = render_row + 1
        else
          render_column = render_column + 1
        end
      end
    end,

    render_month_array = function(self, ui_info, date, opts)
      -- Render the first wkd banner in the middle
      local wkd_banner = self:render_wkd_banner(ui_info, 0, opts.distance)
      self:render_month_banner(ui_info, date, wkd_banner)
      self:render_month(ui_info, date, wkd_banner)

      local months_to_render = M.rendered_months_in_width(ui_info.width, opts.distance)
      months_to_render = math.floor(months_to_render / 2)

      for i = 1, months_to_render do
        wkd_banner = self:render_wkd_banner(ui_info, i, opts.distance)

        local positive_target_date = mutil.reformat_time {
          year = date.year,
          month = date.month + i,
          day = 1,
        }

        self:render_month_banner(ui_info, positive_target_date, wkd_banner)
        self:render_month(ui_info, positive_target_date, wkd_banner)

        wkd_banner = self:render_wkd_banner(ui_info, i * -1, opts.distance)

        local negative_target_date = mutil.reformat_time {
          year = date.year,
          month = date.month - i,
          day = 1,
        }

        self:render_month_banner(ui_info, negative_target_date, wkd_banner)
        self:render_month(ui_info, negative_target_date, wkd_banner)
      end
    end,

    render_year_tag = function(self, ui_info, year)
      -- Display the current year (i.e. `< 2022 >`)
      local extra = nil

      if self.extmarks.logical.year ~= nil then
        extra = {
          id = self.extmarks.logical.year,
        }
      end

      local extmark = M.set_logical_extmark(ui_info, 2, 0, {
        { '< ', 'Whitespace' },
        { tostring(year), '@number' },
        { ' >', 'Whitespace' },
      }, 'center', extra)

      if self.extmarks.logical.year == nil then
        self.extmarks.logical.year = extmark
      end
    end,

    render_decorative_text = function(self, ui_info, v)
      --> Decorational section
      -- CALENDAR text:
      self.extmarks.decorational = vim.tbl_deep_extend('force', self.extmarks.decorational, {
        calendar_text = M.set_decorational_extmark(ui_info, 0, 0, 0, {
          { 'ui.calendar', '@text.strong' },
        }, 'center'),

        -- Help text at the bottom left of the screen
        help_and_custom_input = M.set_decorational_extmark(ui_info, ui_info.height - 1, 0, 0, {
          { '?', '@character' },
          { ' - ' },
          { 'help', '@text.strong' },
          { '    ' },
          { 'i', '@character' },
          { ' - ' },
          { 'custom input', '@text.strong' },
        }),

        -- The current view (bottom right of the screen)
        current_view = M.set_decorational_extmark(ui_info, ui_info.height - 1, 0, 0, {
          { '[', 'Whitespace' },
          { v, '@label' },
          { ']', 'Whitespace' },
        }, 'right'),
      })
    end,

    select_current_day = function(self, ui_info, date)
      local extmark_id = self.extmarks.logical.months[date.month][date.day]

      local position = api.nvim_buf_get_extmark_by_id(ui_info.buffer, M.ns.logical, extmark_id, {})

      api.nvim_win_set_cursor(ui_info.window, { position[1] + 1, position[2] })
    end,

    render_view = function(self, ui_info, date, previous_date, opts)
      local is_first_render = (previous_date == nil)

      if is_first_render then
        api.nvim_buf_clear_namespace(ui_info.buffer, M.ns.decorational, 0, -1)
        api.nvim_buf_clear_namespace(ui_info.buffer, M.ns.logical, 0, -1)

        api.nvim_buf_set_option(ui_info.buffer, 'modifiable', true)

        M.fill_buffer(ui_info)
        self:render_decorative_text(ui_info, M.view_name:upper())
        self:render_year_tag(ui_info, date.year)
        self:render_month_array(ui_info, date, opts)
        self:select_current_day(ui_info, date)

        api.nvim_buf_set_option(ui_info.buffer, 'modifiable', false)
        api.nvim_set_option_value('winfixbuf', true, { win = ui_info.window })

        return
      end

      local year_changed = (date.year ~= previous_date.year)
      local month_changed = (date.month ~= previous_date.month)
      local day_changed = (date.day ~= previous_date.day)

      if year_changed then
        self:render_year_tag(ui_info, date.year)
      end

      if year_changed or month_changed then
        self:render_month_array(ui_info, date, opts)
        self:clear_extmarks(ui_info, date, opts)
      end

      if year_changed or month_changed or day_changed then
        self:select_current_day(ui_info, date)
      end
    end,

    clear_extmarks = function(self, ui_info, current_date, opts)
      local cur_month = current_date.month

      local rendered_months_offset =
        math.floor(M.rendered_months_in_width(ui_info.width, opts.distance) / 2)

      -- Mimics ternary operator to be concise
      local month_min = cur_month - rendered_months_offset
      month_min = month_min <= 0 and (12 + month_min) or month_min

      local month_max = cur_month + rendered_months_offset
      month_max = month_max > 12 and (month_max - 12) or month_max

      local clear_extmarks_for_month = function(month)
        for _, extmark_id in ipairs(self.extmarks.logical.months[month]) do
          api.nvim_buf_del_extmark(ui_info.buffer, M.ns.logical, extmark_id)
        end

        self.extmarks.logical.months[month] = nil
      end

      for month, _ in pairs(self.extmarks.logical.months) do
        -- Check if the month is outside the current view range
        -- considering the month wrapping after 12
        if month_min < month_max then
          if month_min > month or month > month_max then
            clear_extmarks_for_month(month)
          end
        elseif month_min > month_max then
          if month_max < month and month < month_min then
            clear_extmarks_for_month(month)
          end
        elseif month_min == month_max then
          if month ~= cur_month then
            clear_extmarks_for_month(month)
          end
        end
      end
    end,
  }
end

M.fill_buffer = function(ui_info)
  -- There are many steps to render a calendar.
  -- The first step is to fill the entire buffer with spaces. This lets
  -- us place extmarks at any position in the document. Won't be used for
  -- the meaty stuff, but will come in handy for rendering decorational
  -- elements.
  local fill = {}
  local filler = (' '):rep(ui_info.width)

  for i = 1, ui_info.height do
    fill[i] = filler
  end

  api.nvim_buf_set_lines(ui_info.buffer, 0, -1, true, fill)
end

--- get the number of days in the month, months are wrapped (ie, month 13 <==> month 1)
M.get_month_length = function(month, year)
  return ({
    31,
    (M.is_leap_year(year)) and 29 or 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  })[lib.number_wrap(month, 1, 12)]
end

M.is_leap_year = function(year)
  if year % 4 ~= 0 then
    return false
  end

  -- Years disible by 100 are leap years only if also divisible by 400
  if year % 100 == 0 and year % 400 ~= 0 then
    return false
  end

  return true
end

M.rendered_months_in_width = function(width, distance)
  local rendered_month_width = 26
  local months = math.floor(width / (rendered_month_width + distance))

  -- Do not show more than one year
  if months > 12 then
    months = 12
  end

  if months % 2 == 0 then
    return months - 1
  end
  return months
end

M.load = function()
  M.dep['ui.calendar'].add_view(M.view_name, M)
end

return M
