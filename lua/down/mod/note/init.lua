local config = require("down.config")
local down = require("down")
local mod = require("down.mod")
local noteutil = require("down.mod.note.util")
local util = require("down.util")
local sep, log = util.sep, log

---@class down.mod.note.Note: down.Mod
local Note = mod.new("note")

Note.maps = {
  { "n", ",dn", "<CMD>Down note today<CR>",       "Down today note" },
  { "n", ",dN", "<CMD>Down note index<CR>",       "Down today note" },
  { "n", ",dm", "<CMD>Down note month index<CR>", "Down today note" },
  { "n", ",dy", "<CMD>Down note year index<CR>",  "Down today note" },
  { "n", ",dt", "<CMD>Down note tempalte<CR>",    "Down today note" },
  { "n", ",dy", "<CMD>Down note yesterday<CR>",   "Down yesterday note" },
  { "n", ",dt", "<CMD>Down note tomorrow<CR>",    "Down tomorrow note" },
  { "n", ",dc", "<CMD>Down note capture<CR>",     "Down capture note" },
}

---@class down.mod.note.Data
Note.week_index = function()
  local wk = os.date("%V")
end
Note.year_index = function()
  local yr = os.date("%Y")
  local ws = Note.config.workspace or Note.dep["workspace"].current()
  local ws_path = Note.dep["workspace"].get(ws)
  local ix = Note.config.note_folder .. sep .. yr .. sep .. Note.config.index
  local path = ws_path .. sep .. ix
  local index_exists = Note.dep["workspace"].exists(path)
  if not index_exists then
    Note.dep["workspace"].new_file(ix, ws)
  end
  Note.dep["workspace"].open_file(ws, ix)
end
Note.month_index = function()
  local yr = os.date("%Y")
  local mo = os.date("%m")
  local ws = Note.config.workspace or Note.dep["workspace"].current()
  local ws_path = Note.dep["workspace"].get(ws)
  local ix = Note.config.note_folder
      .. sep
      .. yr
      .. sep
      .. mo
      .. sep
      .. Note.config.index
  local path = ws_path .. sep .. ix
  local index_exists = Note.dep["workspace"].exists(path)
  if index_exists then
    Note.dep["workspace"].open_file(ws, ix)
  else
    Note.dep["workspace"].new_file(ix, ws)
    Note.dep["workspace"].open_file(ws, ix)
  end
end
---TODO: select onth from vim.ui.select
Note.select_month = function() end
Note.note_index = function()
  local ws = Note.config.workspace or Note.dep["workspace"].current()
  local ws_path = Note.dep["workspace"].get(ws)
  local ix = Note.config.note_folder .. sep .. Note.config.index
  local path = ws_path .. sep .. ix
  local index_exists = Note.dep["workspace"].exists(path)
  if not index_exists then
    Note.dep["workspace"].new_file(ix, ws)
  end
  Note.dep["workspace"].open_file(ws, ix)
end
--- Opens a note entry at the given time
---@param time? number #The time to open the note entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the note at instead
Note.open_year = function(time, custom_date)
  local workspace = Note.config.workspace or Note.dep["workspace"].current()
  local workspace_path = Note.dep["workspace"].get(workspace)
  local folder_name = Note.config.note_folder
  local tmpl = Note.config.template.year
  if custom_date then
    local year, _month, _day = custom_date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if not year then
      log.error("Wrong date format: use YYYY-mm-dd")
      return
    end
    time = os.time({
      year = year,
      month = 1,
      day = 1,
    })
  end

  local path = os.date(
    type(Note.config.strategy) == "function"
    and Note.config.strategy(os.date("*t", time))
    or Note.config.strategy,
    time
  )

  local note_file_exists = Note.dep["workspace"].exists(
    workspace_path .. sep .. folder_name .. sep .. path
  )

  Note.dep["workspace"].new_file(folder_name .. sep .. path, workspace)

  if
      not note_file_exists
      and Note.config.template.enable
      and Note.dep["workspace"].exists(
        workspace_path .. sep .. folder_name .. sep .. tmpl
      )
  then
    vim.cmd(
      "$read "
      .. workspace_path
      .. sep
      .. folder_name
      .. sep
      .. tmpl
      .. "| silent! w"
    )
  end
end
---@param time? number #The time to open the note entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the note at instead
Note.open_month = function(time, custom_date)
  local workspace = Note.config.workspace or Note.dep["workspace"].current()
  local workspace_path = Note.dep["workspace"].get(workspace)
  local folder_name = Note.config.note_folder
  local tmpl = Note.config.template.month

  if custom_date then
    local year, month, day = custom_date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

    if not year or not month or not day then
      log.error("Wrong date format: use YYYY-mm-dd")
      return
    end

    time = os.time({
      year = year,
      month = month,
      day = day,
    })
  end

  local path = os.date(
    type(Note.config.strategy) == "function"
    and Note.config.strategy(os.date("*t", time))
    or Note.config.strategy,
    time
  )

  local note_file_exists = Note.dep["workspace"].exists(
    workspace_path .. sep .. folder_name .. sep .. path
  )

  Note.dep["workspace"].new_file(folder_name .. sep .. path, workspace)

  if
      not note_file_exists
      and Note.config.template.enable
      and Note.dep["workspace"].exists(
        workspace_path .. sep .. folder_name .. sep .. tmpl
      )
  then
    vim.cmd(
      "$read "
      .. workspace_path
      .. sep
      .. folder_name
      .. sep
      .. tmpl
      .. "| silent! w"
    )
  end
end
Note.capture = function()
  local b, w = Note.dep["ui.win"].win("today", "note", "Down note today")
  -- vim.cmd

  -- Noteod.get_mod("ui.win").cmd(w, function()
  --   vim.api.nvim_command("down note today")
  -- end)
  -- pcall(vim.api.nvim_command, ":down note today")
end
--- Opens a note entry at the given time
---@param time? number #The time to open the note entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the note at instead
Note.open_note = function(time, custom_date)
  local workspace = Note.config.workspace or Note.dep["workspace"].current()
  local workspace_path = Note.dep["workspace"].get(workspace)
  local folder_name = Note.config.note_folder
  local tmpl = Note.config.template.day

  if custom_date then
    local year, month, day = custom_date:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")

    if not year or not month or not day then
      log.error("Wrong date format: use YYYY-mm-dd")
      return
    end

    time = os.time({
      year = year,
      month = month,
      day = day,
    })
  end

  local path = os.date(
    type(Note.config.strategy) == "function"
    and Note.config.strategy(os.date("*t", time))
    or Note.config.strategy,
    time
  )

  local note_file_exists = Note.dep["workspace"].exists(
    workspace_path .. sep .. folder_name .. sep .. path
  )

  Note.dep["workspace"].new_file(folder_name .. sep .. path, workspace)

  if
      not note_file_exists
      and Note.config.template.enable
      and Note.dep["workspace"].exists(
        workspace_path .. sep .. folder_name .. sep .. tmpl
      )
  then
    vim.cmd(
      "$read "
      .. workspace_path
      .. sep
      .. folder_name
      .. sep
      .. tmpl
      .. "| silent! w"
    )
  end
end

--- Opens a note entry for tomorrow's date
Note.note_tomorrow = function()
  Note.open_note(os.time() + 24 * 60 * 60)
end

--- Opens a note entry for yesterday's date
Note.note_yesterday = function()
  Note.open_note(os.time() - 24 * 60 * 60)
end

Note.year_prev = function()
  Note.open_note(os.time() - 24 * 60 * 60 * 365)
end
Note.year_next = function()
  Note.open_note(os.time() + 24 * 60 * 60 * 365)
end
Note.month_prev = function()
  Note.open_note(os.time() - 24 * 60 * 60 * 30)
end

Note.month_next = function()
  Note.open_note(os.time() + 24 * 60 * 60 * 30)
end

Note.week_prev = function()
  Note.open_note(os.time() - 24 * 60 * 60 * 7)
end

Note.week_next = function()
  Note.open_note(os.time() + 24 * 60 * 60 * 7)
end

--- Opens a note entry for today's date
Note.note_today = function()
  Note.open_note()
end

Note.create_month_template = function()
  local workspace = Note.config.workspace
  local folder_name = Note.config.note_folder
  local tmpl = Note.config.template.month
  Note.dep["workspace"].new_file(
    folder_name .. sep .. tmpl,
    workspace or Note.dep["workspace"].current()
  )
end
--- Creates a template file
Note.create_year_template = function()
  local workspace = Note.config.workspace
  local folder_name = Note.config.note_folder
  local tmpl = Note.config.template.year
  Note.dep["workspace"].new_file(
    folder_name .. sep .. tmpl,
    workspace or Note.dep["workspace"].current()
  )
end
Note.create_day_template = function()
  local workspace = Note.config.workspace
  local folder_name = Note.config.note_folder
  local tmpl = Note.config.template.day

  Note.dep["workspace"].new_file(
    folder_name .. sep .. tmpl,
    workspace or Note.dep["workspace"].current()
  )
end

--- Opens the toc file
Note.open_toc = function()
  local workspace = Note.config.workspace or Note.dep["workspace"].current()
  local index = mod.mod_config("workspace").index
  local folder_name = Note.config.note_folder

  -- If the toc exists, open it, if not, create it
  if Note.dep["workspace"].exists(folder_name .. sep .. index) then
    Note.dep["workspace"].open_file(workspace, folder_name .. sep .. index)
  else
    Note.create_toc()
  end
end

--- Creates or updates the toc file
Note.create_toc = function()
  local workspace = Note.config.workspace or Note.dep["workspace"].current()
  local index = mod.mod_config("workspace").index
  local workspace_path = Note.dep["workspace"].get(workspace)
  local workspace_name_for_link = Note.config.workspace or ""
  local folder_name = Note.config.note_folder

  -- Each entry is a table that contains tables like { yy, mm, dd, link, title }
  local toc_entries = {}

  -- Get a filesystem handle for the files in the note folder
  -- path is for each subfolder
  local get_fs_handle = function(path)
    path = path or ""
    local handle =
        vim.loop.fs_scandir(workspace_path .. sep .. folder_name .. sep .. path)

    if type(handle) ~= "userdata" then
      error(
        util.lazy_string_concat(
          "Failed to scan directory '",
          workspace,
          path,
          "': ",
          handle
        )
      )
    end

    return handle
  end

  -- Gets the title from the metadata of a file, must be called in a vim.schedule
  local get_title = function(file)
    local buffer =
        vim.fn.bufadd(workspace_path .. sep .. folder_name .. sep .. file)
    local meta = Note.dep["workspace"].get_document_metadata(buffer)
    return meta.title
  end

  vim.loop.fs_scandir(
    workspace_path .. sep .. folder_name .. sep,
    function(err, handle)
      assert(
        not err,
        util.lazy_string_concat(
          "Unable to generate TOC for directory '",
          folder_name,
          "' - ",
          err
        )
      )

      while true do
        -- Name corresponds to either a YYYY-mm-dd.down file, or just the year ("nested" strategy)
        local name, type = vim.loop.fs_scandir_next(handle) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        if not name then
          break
        end
        if type == "directory" then
          local years_handle = get_fs_handle(name)
          while true do
            local mname, mtype = vim.loop.fs_scandir_next(years_handle)
            if not mname then
              break
            end

            if mtype == "directory" then
              local months_handle = get_fs_handle(name .. sep .. mname)
              while true do
                local dname, dtype = vim.loop.fs_scandir_next(months_handle)
                if not dname then
                  break
                end

                -- If it's a .down file, also ensure it is a day entry
                if dtype == "file" and (dname):match("%d%d%.md") then
                  -- Split the file name
                  local file = vim.split(dname, ".", { plain = true })

                  vim.schedule(function()
                    -- Get the title from the metadata, else, it just base to the name of the file
                    local title = get_title(
                      name .. sep .. mname .. sep .. dname
                    ) or file[1]

                    -- Insert a new entry
                    table.insert(toc_entries, {
                      tonumber(name),
                      tonumber(mname),
                      tonumber(file[1]),
                      "{:$"
                      .. workspace_name_for_link
                      .. sep
                      .. Note.config.note_folder
                      .. sep
                      .. name
                      .. sep
                      .. mname
                      .. sep
                      .. file[1]
                      .. ":}",
                      title,
                    })
                  end)
                end
              end
            end
          end
        end

        -- Handles flat entries
        -- If it is a .down file, but it's not any user generated file.
        -- The match is here to avoid handling files made by the user, like a template file, or
        -- the toc file
        if type == "file" and string.match(name, "%d+-%d+-%d+%.md") then
          -- Split yyyy-mm-dd to a table
          local file = vim.split(name, ".", { plain = true })
          local parts = vim.split(file[1], "-")

          -- Convert the parts into numbers
          for k, v in pairs(parts) do
            parts[k] = tonumber(v) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
          end

          vim.schedule(function()
            -- Get the title from the metadata, else, it just base to the name of the file
            local title = get_title(name) or parts[3]

            -- And insert a new entry that corresponds to the file
            table.insert(toc_entries, {
              parts[1],
              parts[2],
              parts[3],
              "{:$"
              .. workspace_name_for_link
              .. sep
              .. Note.config.note_folder
              .. sep
              .. file[1]
              .. ":}",
              title,
            })
          end)
        end
      end

      vim.schedule(function()
        local format = Note.config.toc_format
            or function(entries)
              local months_text = Note.months
              local output = {}
              local current_year, current_month
              for _, entry in ipairs(entries) do
                if not current_year or current_year < entry[1] then
                  current_year = entry[1]
                  current_month = nil
                  output:insert("* " .. current_year)
                end
                if not current_month or current_month < entry[2] then
                  current_month = entry[2]
                  output:insert("** " .. months_text[current_month])
                end

                -- Prints the file link
                output:insert("   " .. entry[4] .. ("[%s]"):format(entry[5]))
              end

              return output
            end

        Note.dep["workspace"].new_file(
          folder_name .. sep .. index,
          workspace or Note.dep["workspace"].current()
        )

        -- The current buffer now must be the toc file, so we set our toc entries there
        vim.api.nvim_buf_set_lines(0, 0, -1, false, format(toc_entries))
        -- vim.cmd("w")
      end)
    end
  )
end

---@class (exact) down.mod.note.Config
Note.config = {
  -- Which workspace to use for the note files, the base behaviour
  -- is to use the current workspace.
  --
  -- It is recommended to set this to a static workspace, but the most optimal
  -- behaviour may vary from workflow to workflow.
  workspace = nil,

  -- The name for the folder in which the note files are put.
  note_folder = "note",

  index = "index.md",

  -- The strategy to use to create directories.
  -- Noteay be "flat" (`2022-03-02.down`), "nested" (`2022/03/02.down`),
  -- a lua string with the format given to `os.date()` or a lua function
  -- that returns a lua string with the same format.
  strategy = "nested",

  -- The name of the template file to use when running `:down note template`.
  template = {

    enable = true,
    day = "day.md",
    month = "month.md",
    year = "month.md",
    week = "week.md",
    default = "note.md",
  },

  -- Formatter function used to generate the toc file.
  -- Receives a table that contains tables like { yy, mm, dd, link, title }.
  --
  -- The function must return a table of strings.
  toc_format = nil,
}

Note.config.strategies = {
  flat = "%Y-%m-%d.md",
  nested = "%Y" .. sep .. "%m" .. sep .. "%d.md",
}

Note.open_month_calendar = function(event)
  if not event.body[1] then
    local cal = Note.dep["ui.calendar"]
    if not cal then
      log.error("[ERROR]: `ui.calendar` is not loaded!")
      return
    end
    cal.select_date({
      callback = vim.schedule_wrap(function(osdate)
        Note.open_note(
          nil,
          ("%04d"):format(osdate.year)
          .. "-"
          .. ("%02d"):format(osdate.month)
          .. "-"
          .. ("%02d"):format(osdate.day)
        )
      end),
    })
  else
    Note.open_note(nil, event.body[1])
  end
end

Note.commands = {
  calendar = {
    min_args = 0,
    max_args = 1,
    callback = Note.open_month_calendar,
    name = "calendar",
  }, -- format :yyyy-mm-dd
  note = {
    name = "note",
    callback = function(e)
      log.trace("note")
    end,
    min_args = 1,
    max_args = 2,
    commands = {
      index = {
        callback = Note.note_index,
        args = 0,
        enabled = true,
        name = "note.index",
      },
      month = {
        max_args = 1,
        enabled = true,
        name = "note.month",
        callback = Note.month_index,
        commands = {
          index = {
            callback = Note.month_index,
            args = 0,
            enabled = true,
            name = "note.month.index",
          },
          previous = {
            args = 0,
            callback = Note.month_prev,
            name = "note.month.previous",
          },
          next = {
            args = 0,
            name = "note.month.next",
            callback = Note.month_next,
          },
        },
      },
      week = {
        commands = {
          index = {
            args = 0,
            name = "note.week.index",
            callback = Note.week_index,
          },
          previous = {
            args = 0,
            name = "note.week.previous",
            callback = Note.week_prev,
          },
          next = {
            args = 0,
            name = "note.week.next",
            callback = Note.week_next,
          },
        },
        max_args = 1,
        name = "note.week",
        callback = Note.week_index,
      },
      year = {
        max_args = 1,
        name = "note.year",
        callback = Note.year_index,
        commands = {
          index = {
            args = 0,
            callback = Note.year_index,
            name = "note.year.index",
          },
          previous = {
            args = 0,
            name = "note.year.previous",
            callback = Note.year_prev,
          },
          next = {
            args = 0,
            name = "note.year.next",
            callback = Note.year_next,
          },
        },
      },
      capture = {
        callback = Note.capture,
        args = 0,
        enabled = false,
        name = "note.capture",
      },
      tomorrow = {
        callback = Note.note_tomorrow,
        args = 0,
        name = "note.tomorrow",
      },
      yesterday = {
        args = 0,
        name = "note.yesterday",
        callback = Note.note_yesterday,
      },
      today = {
        callback = Note.note_today,
        args = 0,
        name = "note.today",
      },
      calendar = {
        callback = Note.open_month_calendar,
        max_args = 1,
        name = "note.calendar",
      }, -- format :yyyy-mm-dd
      template = {
        callback = Note.create_day_template,
        commands = {
          year = {
            callback = Note.create_year_template,
            name = "notes.template.year",
            args = 0,
          },
          week = {
            callback = Note.create_year_template,
            name = "notes.template.week",
            args = 0,
          },
          month = {
            callback = Note.create_month_template,
            name = "notes.template.month",
            args = 0,
          },
          day = {
            callback = Note.create_day_template,
            name = "notes.template.day",
            args = 0,
          },
        },
        args = 0,
        name = "note.template",
      },
      toc = {
        enabled = false,
        args = 1,
        name = "note.toc",
        callback = Note.open_toc,
        commands = {
          open = {
            callback = Note.open_toc,
            args = 0,
            name = "note.toc.open",
          },
          update = {
            args = 0,
            name = "note.toc.update",
            callback = Note.create_toc,
          },
        },
      },
    },
  },
}

Note.load = function()
  if Note.config.strategies[Note.config.strategy] then
    Note.config.strategy = Note.config.strategies[Note.config.strategy]
  end
end

---@return down.mod.Setup
Note.setup = function()
  return {
    loaded = true,
    dependencies = {
      "ui.win",
      "ui.calendar",
      "data",
      "cmd",
      "template",
      "workspace",
      "integration.treesitter",
    },
  }
end

-- -@class down.mod.note.Subscribed
-- Note.handle = {
-- cmd = {
-- ['note.index'] = Note.note_index,
-- ['note.month'] = Note.month_index,
-- ['note.week'] = Note.week_index,
-- ['note.year'] = Note.year_index,
-- ['note'] = function(e) end
-- ['note.month.previous'] = Note.month_prev,
-- ['note.week.previous'] = Note.week_prev,
-- ['note.year.previous'] = Note.year_prev,
-- ['note.month.next'] = Note.month_next,
-- ['note.week.next'] = Note.week_next,
-- ['note.year.next'] = Note.year_next,
-- ['note.month.index'] = Note.month_index,
-- ['note.week.index'] = Note.week_index,
-- ['note.year.index'] = Note.year_index,
-- ['note.yesterday'] = Note.note_yesterday,
-- ['note.tomorrow'] = Note.note_tomorrow,
-- ['note.capture'] = Note.capture,
-- ['note.today'] = Note.note_today,
-- ['calendar'] = Note.open_note,
-- ['note.calendar'] = Note.open_note,
-- ['note.template'] = Note.create_day_template,
-- ['note.template.day'] = Note.create_day_template,
-- ['note.template.month'] = Note.create_month_template,
-- ['note.template.year'] = Note.create_year_template,
-- ['note.toc.update'] = Note.create_toc,
-- ['note.toc.open'] = Note.open_toc,
-- ['note.template.week'] = function(e) end,
-- },
-- }

return Note
