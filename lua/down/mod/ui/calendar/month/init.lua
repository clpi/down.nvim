local down = require("down")
local util = down.util
local log = util.log
local mod = down.mod
local monthutil = require("down.mod.ui.calendar.month.util")

local Month = mod.new("ui.calendar.month")

Month.setup = function()
  return {
    loaded = true,
    dependencies = {
      "ui.calendar",
      "data.time",
    },
  }
end

Month.view_name = "month"

Month.setup_view = function(ui_info, mode, date, options)
  options.distance = options.distance or 4
  local view = Month.new_view_instance()
  view.current_mode = mode
  view:render_view(ui_info, date, nil, options)
  do
    vim.keymap.set("n", "q", function()
      vim.api.nvim_buf_delete(ui_info.buffer, { force = true })
    end, { buffer = ui_info.buffer })

    -- TODO: Monthake cursor wrapping behaviour rable
    vim.keymap.set("n", "l", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = date.day + 1 * vim.v.count1,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "h", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = date.day - 1 * vim.v.count1,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "j", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = date.day + 7 * vim.v.count1,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "k", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = date.day - 7 * vim.v.count1,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "<cr>", function()
      local should_redraw = false
      if view.current_mode.on_select ~= nil then
        should_redraw = view.current_mode:on_select(date)
      end
      if should_redraw then
        view:render_view(ui_info, date, nil, options)
      end
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "L", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month + vim.v.count1,
        day = date.day,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "H", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month - vim.v.count1,
        day = date.day,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "m", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month + vim.v.count1,
        day = 1,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "Month", function()
      if date.day > 1 then
        date.month = date.month + 1
      end
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month - vim.v.count1,
        day = 1,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "y", function()
      local new_date = monthutil.reformat_time({
        year = date.year + vim.v.count1,
        month = date.month,
        day = date.day,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "Y", function()
      local new_date = monthutil.reformat_time({
        year = date.year - vim.v.count1,
        month = date.month,
        day = date.day,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "$", function()
      local new_day = date.day - (util.number_wrap(date.wday - 1, 1, 7) - 1) + 6
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = new_day,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    local start_of_week = function()
      local new_day = date.day - (util.number_wrap(date.wday - 1, 1, 7) - 1)
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = new_day,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end

    vim.keymap.set("n", "0", start_of_week, { buffer = ui_info.buffer })
    vim.keymap.set("n", "_", start_of_week, { buffer = ui_info.buffer })

    vim.keymap.set("n", "t", function()
      local new_date = os.date("*t")

      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "e", function()
      local end_of_current_month = Month.get_month_length(date.month, date.year)
      if end_of_current_month > date.day then
        date.month = date.month - 1
      end
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month + vim.v.count1,
        day = Month.get_month_length(date.month + vim.v.count1, date.year),
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "E", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month - vim.v.count1,
        day = Month.get_month_length(date.month - vim.v.count1, date.year),
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "w", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = date.day + 7 * vim.v.count1,
      })
      new_date.day = new_date.day
          - (util.number_wrap(new_date.wday - 1, 1, 7) - 1)
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "W", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = date.day - 7 * vim.v.count1,
      })
      new_date.day = new_date.day
          - (util.number_wrap(new_date.wday - 1, 1, 7) - 1)
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    local months = {}
    for i = 1, 12 do
      table.insert(
        months,
        (
          os.date("%B", os.time({ year = 2000, month = i, day = 1 })) --[[@as string]]
        ):lower()
      )
    end

    -- store the last `;` repeatable search
    local last_semi_jump = nil
    -- flag to set when we're using `;` so it doesn't cycle
    local skip_next = false

    vim.keymap.set("n", ";", function()
      if last_semi_jump then
        vim.api.nvim_feedkeys(last_semi_jump, "m", false)
      end
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", ",", function()
      if last_semi_jump then
        local action = string.sub(last_semi_jump, 1, 1)
        local subject = string.sub(last_semi_jump, 2)
        local new_keys
        if string.upper(action) == action then
          new_keys = action:lower() .. subject
        else
          new_keys = action:upper() .. subject
        end
        vim.api.nvim_feedkeys(new_keys, "m", false)

        skip_next = true
      end
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "f", function()
      local char = vim.fn.getcharstr()

      for i = date.month + 1, date.month + 12 do
        local m = util.number_wrap(i, 1, 12)
        if months[m]:match("^" .. char) then
          if not skip_next then
            last_semi_jump = "f" .. char
          else
            skip_next = false
          end

          local new_date = monthutil.reformat_time({
            year = date.year,
            month = m,
            day = date.day,
          })
          view:render_view(ui_info, new_date, date, options)
          date = new_date
          break
        end
      end
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "F", function()
      local char = vim.fn.getcharstr()

      for i = date.month + 11, date.month, -1 do
        local m = util.number_wrap(i, 1, 12)
        if months[m]:match("^" .. char) then
          if not skip_next then
            last_semi_jump = "F" .. char
          else
            skip_next = false
          end
          local new_date = monthutil.reformat_time({
            year = date.year,
            month = m,
            day = date.day,
          })
          view:render_view(ui_info, new_date, date, options)
          date = new_date
          break
        end
      end
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "g", function()
      local day =
          math.min(vim.v.count1, Month.get_month_length(date.month, date.year))

      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = day,
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer, nowait = true })

    vim.keymap.set("n", "G", function()
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = Month.get_month_length(date.month, date.year),
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer })

    vim.keymap.set("n", "d", function()
      local n = vim.v.count1
      local weekday = math.min(n, 7)
      local new_date = monthutil.reformat_time({
        year = date.year,
        month = date.month,
        day = date.day + (weekday - util.number_wrap(date.wday - 1, 1, 7)),
      })
      view:render_view(ui_info, new_date, date, options)
      date = new_date
    end, { buffer = ui_info.buffer, nowait = true })

    vim.keymap.set(
      "n",
      "?",
      util.wrap(Month.display_help, {
        {
          { "q",                 "@namespace" },
          { " - " },
          { "close this window", "@text.strong" },
        },
        {},
        {
          { "<CR>",        "@namespace" },
          { " - " },
          { "select date", "@text.strong" },
        },
        {},
        {
          { "--- Basic Monthovement ---", "@text.title" },
        },
        {},
        {
          { "l/h",               "@namespace" },
          { " - " },
          { "next/previous day", "@text.strong" },
        },
        {
          { "j/k",                "@namespace" },
          { " - " },
          { "next/previous week", "@text.strong" },
        },
        {
          { "w/W",                                 "@namespace" },
          { " - " },
          { "start of next/this or previous week", "@text.strong" },
        },
        {
          { "t",     "@namespace" },
          { " - " },
          { "today", "@text.strong" },
        },
        {
          { "d",             "@namespace" },
          { "n" },
          { " - " },
          { "weekday ",      "@text.strong" },
          { "n" },
          { " (1 = monday)", "@text.strong" },
        },
        {},
        {
          { "--- Monthoving Between Monthonths ---", "@text.title" },
        },
        {},
        {
          { "L/H",                            "@namespace" },
          { " - " },
          { "next/previous month (same day)", "@text.strong" },
        },
        {
          { "m/Month",                            "@namespace" },
          { " - " },
          { "1st of next/this or previous month", "@text.strong" },
        },
        {
          { "f",                                  "@namespace" },
          { "x" },
          { "/F",                                 "@namespace" },
          { "x" },
          { " - " },
          { "next/previous month starting with ", "@text.strong" },
          { "x" },
        },
        {},
        {
          { "--- Monthoving Between Years ---", "@text.title" },
        },
        {},
        {
          { "y/Y",                           "@namespace" },
          { " - " },
          { "next/previous year (same day)", "@text.strong" },
        },
        {
          { "gy",                        "@namespace" },
          { " - " },
          { "start of the current year", "@text.strong" },
        },
        {
          { "c/C",                           "@namespace" },
          { " - " },
          { "next/this or previous century", "@text.strong" },
        },
        {
          { "g/G",                "@namespace" },
          { " - " },
          { "start/end of month", "@text.strong" },
        },
        {
          { "      " },
          { "<n>g takes you to <n> day of the month", "@text.strong" },
        },
        {},
        {
          { "--- Additional Info ---", "@text.title" },
        },
        {},
        {
          { "All movements accept counts" },
        },
        {
          { "f/F and g/G work with `;` and `,`" },
        },
      }),
      { buffer = ui_info.buffer }
    )

    vim.keymap.set("n", "i", function()
      local buffer = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_open_win(buffer, true, {
        style = "minimal",
        border = "single",
        title = "Date (`?` for help)",
        row = vim.api.nvim_win_get_height(0),
        col = 0,
        width = vim.o.columns,
        height = 1,
        relative = "win",
        win = vim.api.nvim_get_current_win(),
        noautocmd = true,
      })

      vim.cmd.startinsert()

      local function quit()
        vim.cmd.stopinsert()
        vim.api.nvim_buf_delete(buffer, { force = true })
      end

      vim.keymap.set("n", "<Esc>", quit, { buffer = buffer })
      vim.keymap.set("i", "<C-c>", quit, { buffer = buffer })
      vim.keymap.set(
        "n",
        "?",
        util.wrap(Month.display_help, {
          {
            { "q",                 "@namespace" },
            { " - " },
            { "close this window", "@text.strong" },
          },
          {
            { "<CR>",         "@namespace" },
            { " - " },
            { "confirm date", "@text.strong" },
          },
          {},
          {
            { "--- Quitting ---", "@text.title" },
          },
          {},
          {
            { "<C-c> (insert mode)", "@namespace" },
            { " - " },
            { "quit",                "@text.strong" },
          },
          {
            { "<Esc>", "@namespace" },
            { " - " },
            { "quit",  "@text.strong" },
          },
          {},
          {
            { "--- Date Syntax ---", "@text.title" },
          },
          {},
          {
            { "Order " },
            { "does not matter", "@text.strong" },
            { " with dates." },
          },
          {},
          {
            { "Some things depend on locale." },
          },
          {},
          {
            { "Monthonths and weekdays may be written" },
          },
          {
            { "with a shorthand." },
          },
          {},
          {
            { "Years must contain 4 digits at" },
          },
          {
            { "all times. Prefix with zeroes" },
          },
          {
            { "where necessary." },
          },
          {},
          {
            { "Hour syntax: `00:00.00` (hour, min, sec)" },
          },
          {},
          {
            { "--- Examples ---", "@text.title" },
          },
          {},
          {
            { "Tuesday Monthay 5th 2023 19:00.23", "@down.markup.verbatim" },
          },
          {
            { "10 Feb CEST 0600", "@down.markup.verbatim" },
            { " (",               "@comment" },
            { "0600",             "@text.emphasis" },
            { " is the year)",    "@comment" },
          },
          {
            { "9:00.4 2nd Montharch Wed", "@down.markup.verbatim" },
          },
        }),
        { buffer = buffer }
      )

      vim.keymap.set({ "n", "i" }, "<CR>", function()
        local line = vim.api.nvim_buf_get_lines(buffer, 0, -1, true)[1]

        local parsed_date = Month.dep["data.time"].parse_date(line)

        if type(parsed_date) == "string" then
          log.error("[ERROR]:", parsed_date)
          return
        end

        quit()

        local lua_date = Month.dep["data.time"].to_lua_date(parsed_date)

        local should_redraw = false

        if view.current_mode.on_select ~= nil then
          should_redraw = view.current_mode:on_select(lua_date)
        end

        if should_redraw then
          view:render_view(ui_info, lua_date, nil, options)
        end
      end, { buffer = buffer })
    end, { buffer = ui_info.buffer })
  end
end

Month.namespaces = {
  logical = vim.api.nvim_create_namespace("down.mod.ui.calendar.logical"),
  decorational = vim.api.nvim_create_namespace(
    "down.mod.ui.calendar.decorational"
  ),
}

Month.set_extmark = function(
    ui_info,
    namespace,
    row,
    col,
    length,
    virt_text,
    alignment,
    extra
)
  if alignment then
    local text_length = 0

    for _, tuple in ipairs(virt_text) do
      text_length = text_length + tuple[1]:len()
    end

    if alignment == "center" then
      col = col + (ui_info.half_width - math.floor(text_length / 2))
    elseif alignment == "right" then
      col = col + (ui_info.width - text_length)
    end
  end

  local base_extra = {
    virt_text = virt_text,
    virt_text_pos = "overlay",
  }

  if length then
    base_extra.end_col = col + length
  end

  return vim.api.nvim_buf_set_extmark(
    ui_info.buffer,
    namespace,
    row,
    col,
    vim.tbl_deep_extend("force", base_extra, extra or {})
  )
end

Month.set_decorational_extmark = function(
    ui_info,
    row,
    col,
    length,
    virt_text,
    alignment,
    extra
)
  return Month.set_extmark(
    ui_info,
    Month.namespaces.decorational,
    row,
    col,
    length,
    virt_text,
    alignment,
    extra
  )
end

Month.set_logical_extmark = function(ui_info, row, col, virt_text, alignment, extra)
  return Month.set_extmark(
    ui_info,
    Month.namespaces.logical,
    row,
    col,
    nil,
    virt_text,
    alignment,
    extra
  )
end

Month.new_view_instance = function()
  return {
    current_mode = {},

    extmarks = {
      decorational = {
        calendar_text = nil,
        help_and_custom_input = nil,
        current_view = nil,
        month_headings = {},
        weekday_displays = {},
      },
      logical = {
        year = nil,
        months = {
          -- [3] = { [31] = <id> }
        },
      },
    },

    -- TODO: implemant distance like in render_weekday_banner
    render_month_banner = function(
        self,
        ui_info,
        date,
        weekday_banner_extmark_id
    )
      local month_name = os.date(
        "%B",
        os.time({
          year = date.year,
          month = date.month,
          day = date.day,
        })
      )
      ---@cast month_name string
      local month_length = vim.api.nvim_strwidth(month_name)

      local weekday_banner_id = vim.api.nvim_buf_get_extmark_by_id(
        ui_info.buffer,
        Month.namespaces.decorational,
        weekday_banner_extmark_id,
        {
          details = true,
        }
      )

      self.extmarks.decorational.month_headings[weekday_banner_extmark_id] = Month.set_decorational_extmark(
        ui_info,
        4,
        weekday_banner_id[2]
        + math.ceil((weekday_banner_id[3].end_col - weekday_banner_id[2]) / 2)
        - math.floor(month_length / 2),
        month_length,
        { { month_name, "@text.underline" } },
        nil,
        {
          id = self.extmarks.decorational.month_headings[weekday_banner_extmark_id],
        }
      )
    end,

    render_weekday_banner = function(self, ui_info, offset, distance)
      offset = offset or 0
      distance = distance or 4

      -- Render the days of the week
      -- To effectively do this, we grab all the weekdays from a constant time.
      -- This makes the weekdays retrieved locale dependent (which is what we want).
      local weekdays = {}
      local weekdays_string_length = 0
      for i = 1, 7 do
        local weekday =
            os.date("%a", os.time({ year = 2000, month = 5, day = i }))
        ---@cast weekday string
        local truncated = util.truncate_by_cell(weekday, 2)
        local truncated_length = vim.api.nvim_strwidth(truncated)
        weekdays[#weekdays + 1] = { truncated, "@text.title" }
        weekdays[#weekdays + 1] = { (" "):rep(4 - truncated_length) }
        weekdays_string_length = truncated_length -- remember last day's length
      end
      weekdays[#weekdays] = nil                   -- delete last padding
      weekdays_string_length = weekdays_string_length + 4 * 6

      -- This serves as the index of this week banner extmark inside the extmark table
      local absolute_offset = offset + (offset < 0 and (-offset * 100) or 0)

      local extmark_position = 0

      -- Calculate offset position only for the previous and following months
      if offset ~= 0 then
        extmark_position = (weekdays_string_length * math.abs(offset))
            + (distance * math.abs(offset))
      end

      -- For previous months, revert the offset
      if offset < 0 then
        extmark_position = -extmark_position
      end

      local weekday_banner_id = Month.set_decorational_extmark(
        ui_info,
        6,
        extmark_position,
        weekdays_string_length,
        weekdays,
        "center",
        {
          id = self.extmarks.decorational.weekday_displays[absolute_offset],
        }
      )

      self.extmarks.decorational.weekday_displays[absolute_offset] =
          weekday_banner_id

      return weekday_banner_id
    end,

    render_month = function(
        self,
        ui_info,
        target_date,
        weekday_banner_extmark_id
    )
      --> Monthonth rendering routine
      -- We render the first month at the very center of the screen. Each
      -- month takes up a static amount of characters.

      -- Render the top text of the month (June, August etc.)
      -- Render the numbers for weekdays
      local days_of_month = {
        -- [day of month] = <day of week>,
      }

      local current_date = os.date("*t")

      local month, year = target_date.month, target_date.year

      local days_in_current_month = Month.get_month_length(month, year)

      for i = 1, days_in_current_month do
        days_of_month[i] = tonumber(os.date(
          "%u",
          os.time({
            year = year,
            month = month,
            day = i,
          })
        ))
      end

      local beginning_of_weekday_extmark = vim.api.nvim_buf_get_extmark_by_id(
        ui_info.buffer,
        Month.namespaces.decorational,
        weekday_banner_extmark_id,
        {}
      )

      local render_column = days_of_month[1] - 1
      local render_row = 1

      self.extmarks.logical.months[month] = self.extmarks.logical.months[month]
          or {}

      for day_of_month, day_of_week in ipairs(days_of_month) do
        local is_current_day = current_date.year == year
            and current_date.month == month
            and day_of_month == current_date.day

        local start_row = beginning_of_weekday_extmark[1] + render_row
        local start_col = beginning_of_weekday_extmark[2] + (4 * render_column)

        if is_current_day then
          -- TODO: Monthake this rable. The user might want the cursor to start
          -- on a specific date in a specific month.
          -- Just look up the extmark and place the cursor there.
          vim.api.nvim_win_set_cursor(
            ui_info.window,
            { start_row + 1, start_col }
          )
        end

        local day_highlight = is_current_day and "@text.todo" or nil

        if self.current_mode.get_day_highlight then
          day_highlight = self.current_mode:get_day_highlight({
            year = year,
            month = month,
            day = day_of_month,
          }, day_highlight)
        end

        self.extmarks.logical.months[month][day_of_month] =
            vim.api.nvim_buf_set_extmark(
              ui_info.buffer,
              Month.namespaces.logical,
              start_row,
              start_col,
              {
                virt_text = {
                  {
                    (day_of_month < 10 and "0" or "") .. tostring(day_of_month),
                    day_highlight,
                  },
                },
                virt_text_pos = "overlay",
                id = self.extmarks.logical.months[month][day_of_month],
              }
            )

        if day_of_week == 7 then
          render_column = 0
          render_row = render_row + 1
        else
          render_column = render_column + 1
        end
      end
    end,

    render_month_array = function(self, ui_info, date, options)
      -- Render the first weekday banner in the middle
      local weekday_banner =
          self:render_weekday_banner(ui_info, 0, options.distance)
      self:render_month_banner(ui_info, date, weekday_banner)
      self:render_month(ui_info, date, weekday_banner)

      local months_to_render =
          Month.rendered_months_in_width(ui_info.width, options.distance)
      months_to_render = math.floor(months_to_render / 2)

      for i = 1, months_to_render do
        weekday_banner =
            self:render_weekday_banner(ui_info, i, options.distance)

        local positive_target_date = monthutil.reformat_time({
          year = date.year,
          month = date.month + i,
          day = 1,
        })

        self:render_month_banner(ui_info, positive_target_date, weekday_banner)
        self:render_month(ui_info, positive_target_date, weekday_banner)

        weekday_banner =
            self:render_weekday_banner(ui_info, i * -1, options.distance)

        local negative_target_date = monthutil.reformat_time({
          year = date.year,
          month = date.month - i,
          day = 1,
        })

        self:render_month_banner(ui_info, negative_target_date, weekday_banner)
        self:render_month(ui_info, negative_target_date, weekday_banner)
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

      local extmark = Month.set_logical_extmark(ui_info, 2, 0, {
        { "< ",           "Whitespace" },
        { tostring(year), "@number" },
        { " >",           "Whitespace" },
      }, "center", extra)

      if self.extmarks.logical.year == nil then
        self.extmarks.logical.year = extmark
      end
    end,

    render_decorative_text = function(self, ui_info, view)
      --> Decorational section
      -- CALENDAR text:
      self.extmarks.decorational =
          vim.tbl_deep_extend("force", self.extmarks.decorational, {
            calendar_text = Month.set_decorational_extmark(ui_info, 0, 0, 0, {
              { "ui.calendar", "@text.strong" },
            }, "center"),

            -- Help text at the bottom left of the screen
            help_and_custom_input = Month.set_decorational_extmark(
              ui_info,
              ui_info.height - 1,
              0,
              0,
              {
                { "?",            "@character" },
                { " - " },
                { "help",         "@text.strong" },
                { "    " },
                { "i",            "@character" },
                { " - " },
                { "custom input", "@text.strong" },
              }
            ),

            -- The current view (bottom right of the screen)
            current_view = Month.set_decorational_extmark(
              ui_info,
              ui_info.height - 1,
              0,
              0,
              {
                { "[",  "Whitespace" },
                { view, "@label" },
                { "]",  "Whitespace" },
              },
              "right"
            ),
          })
    end,

    select_current_day = function(self, ui_info, date)
      local extmark_id = self.extmarks.logical.months[date.month][date.day]

      local position = vim.api.nvim_buf_get_extmark_by_id(
        ui_info.buffer,
        Month.namespaces.logical,
        extmark_id,
        {}
      )

      vim.api.nvim_win_set_cursor(
        ui_info.window,
        { position[1] + 1, position[2] }
      )
    end,

    render_view = function(self, ui_info, date, previous_date, options)
      local is_first_render = (previous_date == nil)

      if is_first_render then
        vim.api.nvim_buf_clear_namespace(
          ui_info.buffer,
          Month.namespaces.decorational,
          0,
          -1
        )
        vim.api.nvim_buf_clear_namespace(
          ui_info.buffer,
          Month.namespaces.logical,
          0,
          -1
        )

        vim.api.nvim_buf_set_option(ui_info.buffer, "modifiable", true)

        Month.fill_buffer(ui_info)
        self:render_decorative_text(ui_info, Month.view_name:upper())
        self:render_year_tag(ui_info, date.year)
        self:render_month_array(ui_info, date, options)
        self:select_current_day(ui_info, date)

        vim.api.nvim_buf_set_option(ui_info.buffer, "modifiable", false)
        vim.api.nvim_set_option_value(
          "winfixbuf",
          true,
          { win = ui_info.window }
        )

        return
      end

      local year_changed = (date.year ~= previous_date.year)
      local month_changed = (date.month ~= previous_date.month)
      local day_changed = (date.day ~= previous_date.day)

      if year_changed then
        self:render_year_tag(ui_info, date.year)
      end

      if year_changed or month_changed then
        self:render_month_array(ui_info, date, options)
        self:clear_extmarks(ui_info, date, options)
      end

      if year_changed or month_changed or day_changed then
        self:select_current_day(ui_info, date)
      end
    end,

    clear_extmarks = function(self, ui_info, current_date, options)
      local cur_month = current_date.month

      local rendered_months_offset = math.floor(
        Month.rendered_months_in_width(ui_info.width, options.distance) / 2
      )

      -- Monthimics ternary operator to be concise
      local month_min = cur_month - rendered_months_offset
      month_min = month_min <= 0 and (12 + month_min) or month_min

      local month_max = cur_month + rendered_months_offset
      month_max = month_max > 12 and (month_max - 12) or month_max

      local clear_extmarks_for_month = function(month)
        for _, extmark_id in ipairs(self.extmarks.logical.months[month]) do
          vim.api.nvim_buf_del_extmark(
            ui_info.buffer,
            Month.namespaces.logical,
            extmark_id
          )
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

Month.fill_buffer = function(ui_info)
  -- There are many steps to render a calendar.
  -- The first step is to fill the entire buffer with spaces. This lets
  -- us place extmarks at any position in the document. Won't be used for
  -- the meaty stuff, but will come in handy for rendering decorational
  -- elements.
  local fill = {}
  local filler = (" "):rep(ui_info.width)

  for i = 1, ui_info.height do
    fill[i] = filler
  end

  vim.api.nvim_buf_set_lines(ui_info.buffer, 0, -1, true, fill)
end

--- get the number of days in the month, months are wrapped (ie, month 13 <==> month 1)
Month.get_month_length = function(month, year)
  return ({
    31,
    (Month.is_leap_year(year)) and 29 or 28,
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
  })[util.number_wrap(month, 1, 12)]
end

Month.is_leap_year = function(year)
  if year % 4 ~= 0 then
    return false
  end

  -- Years disible by 100 are leap years only if also divisible by 400
  if year % 100 == 0 and year % 400 ~= 0 then
    return false
  end

  return true
end

Month.rendered_months_in_width = function(width, distance)
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

Month.display_help = function(lines)
  local width, height = 44, 32
  local buffer = vim.api.nvim_create_buf(false, true)
  local window = vim.api.nvim_open_win(buffer, true, {
    style = "minimal",
    border = "rounded",
    title = " Calendar ",
    title_pos = "center",
    row = (vim.o.lines / 2) - height / 2,
    col = (vim.o.columns / 2) - width / 2,
    width = width,
    height = height,
    relative = "editor",
    noautocmd = true,
  })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = window })

  local function quit()
    vim.api.nvim_win_close(window, true)
    pcall(vim.api.nvim_buf_delete, buffer, { force = true })
  end

  vim.keymap.set("n", "q", quit, { buffer = buffer })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buffer,
    callback = quit,
  })

  local namespace = vim.api.nvim_create_namespace("down.mod.ui.calendar.help")
  vim.api.nvim_buf_set_option(buffer, "modifiable", false)

  vim.api.nvim_buf_set_extmark(buffer, namespace, 0, 0, {
    virt_lines = lines,
  })
end

Month.load = function()
  mod.get("ui.calendar").add_view(Month.view_name, Month)
end

return Month
