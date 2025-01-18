local down = require 'down'
local mod = require 'down.mod'
local util = require 'down.util'
local config = require 'down.config'
local noteutil = require 'down.mod.note.util'
local lib = util.lib
local log = util.log
local map = util.maps

---@class down.mod.Note: down.Mod
local M = mod.new 'note'

M.maps = {
  { 'n', ',dn', '<CMD>Down note today<CR>',     'Down today note' },
  { 'n', ',dy', '<CMD>Down note yesterday<CR>', 'Down yesterday note' },
  { 'n', ',dt', '<CMD>Down note tomorrow<CR>',  'Down tomorrow note' },
  { 'n', ',dc', '<CMD>Down note capture<CR>',   'Down capture note' },
}

---@class down.mod.note.Data
M.week_index = function()
  local wk = os.date '%V'
end
M.year_index = function()
  local yr = os.date '%Y'
  local ws = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local ws_path = M.dep['workspace'].get_workspace(ws)
  local ix = M.config.note_folder .. config.pathsep .. yr .. config.pathsep .. M.config.index
  local path = ws_path .. config.pathsep .. ix
  local index_exists = M.dep['workspace'].file_exists(path)
  if not index_exists then
    M.dep['workspace'].new_file(ix, ws)
  end
  M.dep['workspace'].open_file(ws, ix)
end
M.month_index = function()
  local yr = os.date '%Y'
  local mo = os.date '%m'
  local ws = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local ws_path = M.dep['workspace'].get_workspace(ws)
  local ix = M.config.note_folder
      .. config.pathsep
      .. yr
      .. config.pathsep
      .. mo
      .. config.pathsep
      .. M.config.index
  local path = ws_path .. config.pathsep .. ix
  local index_exists = M.dep['workspace'].file_exists(path)
  if index_exists then
    M.dep['workspace'].open_file(ws, ix)
  else
    M.dep['workspace'].new_file(ix, ws)
    M.dep['workspace'].open_file(ws, ix)
  end
end
M.select_month = function() end
M.note_index = function()
  local ws = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local ws_path = M.dep['workspace'].get_workspace(ws)
  local ix = M.config.note_folder .. config.pathsep .. M.config.index
  local path = ws_path .. config.pathsep .. ix
  local index_exists = M.dep['workspace'].file_exists(path)
  if not index_exists then
    M.dep['workspace'].new_file(ix, ws)
  end
  M.dep['workspace'].open_file(ws, ix)
end
--- Opens a note entry at the given time
---@param time? number #The time to open the note entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the note at instead
M.open_year = function(time, custom_date)
  local workspace = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local workspace_path = M.dep['workspace'].get_workspace(workspace)
  local folder_name = M.config.note_folder
  local tmpl = M.config.template.year
  if custom_date then
    local year, _month, _day = custom_date:match '^(%d%d%d%d)-(%d%d)-(%d%d)$'
    if not year then
      log.error 'Wrong date format: use YYYY-mm-dd'
      return
    end
    time = os.time {
      year = year,
      month = 1,
      day = 1,
    }
  end

  local path = os.date(
    type(M.config.strategy) == 'function' and M.config.strategy(os.date('*t', time))
    or M.config.strategy,
    time
  )

  local note_file_exists = M.dep['workspace'].file_exists(
    workspace_path .. config.pathsep .. folder_name .. config.pathsep .. path
  )

  M.dep['workspace'].new_file(folder_name .. config.pathsep .. path, workspace)

  if
      not note_file_exists
      and M.config.template.enable
      and M.dep['workspace'].file_exists(
        workspace_path .. config.pathsep .. folder_name .. config.pathsep .. tmpl
      )
  then
    vim.cmd(
      '$read '
      .. workspace_path
      .. config.pathsep
      .. folder_name
      .. config.pathsep
      .. tmpl
      .. '| silent! w'
    )
  end
end
---@param time? number #The time to open the note entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the note at instead
M.open_month = function(time, custom_date)
  local workspace = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local workspace_path = M.dep['workspace'].get_workspace(workspace)
  local folder_name = M.config.note_folder
  local tmpl = M.config.template.month

  if custom_date then
    local year, month, day = custom_date:match '^(%d%d%d%d)-(%d%d)-(%d%d)$'

    if not year or not month or not day then
      log.error 'Wrong date format: use YYYY-mm-dd'
      return
    end

    time = os.time {
      year = year,
      month = month,
      day = day,
    }
  end

  local path = os.date(
    type(M.config.strategy) == 'function' and M.config.strategy(os.date('*t', time))
    or M.config.strategy,
    time
  )

  local note_file_exists = M.dep['workspace'].file_exists(
    workspace_path .. config.pathsep .. folder_name .. config.pathsep .. path
  )

  M.dep['workspace'].new_file(folder_name .. config.pathsep .. path, workspace)

  if
      not note_file_exists
      and M.config.template.enable
      and M.dep['workspace'].file_exists(
        workspace_path .. config.pathsep .. folder_name .. config.pathsep .. tmpl
      )
  then
    vim.cmd(
      '$read '
      .. workspace_path
      .. config.pathsep
      .. folder_name
      .. config.pathsep
      .. tmpl
      .. '| silent! w'
    )
  end
end
M.capture = function()
  local b, w = M.dep['ui.win'].win('today', 'note', 'Down note today')
  -- vim.cmd

  -- Mod.get_mod("ui.win").cmd(w, function()
  --   vim.api.nvim_command("down note today")
  -- end)
  -- pcall(vim.api.nvim_command, ":down note today")
end
--- Opens a note entry at the given time
---@param time? number #The time to open the note entry at as returned by `os.time()`
---@param custom_date? string #A YYYY-mm-dd string that specifies a date to open the note at instead
M.open_note = function(time, custom_date)
  local workspace = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local workspace_path = M.dep['workspace'].get_workspace(workspace)
  local folder_name = M.config.note_folder
  local tmpl = M.config.template.day

  if custom_date then
    local year, month, day = custom_date:match '^(%d%d%d%d)-(%d%d)-(%d%d)$'

    if not year or not month or not day then
      log.error 'Wrong date format: use YYYY-mm-dd'
      return
    end

    time = os.time {
      year = year,
      month = month,
      day = day,
    }
  end

  local path = os.date(
    type(M.config.strategy) == 'function' and M.config.strategy(os.date('*t', time))
    or M.config.strategy,
    time
  )

  local note_file_exists =
      M.dep['workspace'].file_exists(workspace_path .. '/' .. folder_name .. config.pathsep .. path)

  M.dep['workspace'].new_file(folder_name .. config.pathsep .. path, workspace)

  if
      not note_file_exists
      and M.config.template.enable
      and M.dep['workspace'].file_exists(workspace_path .. '/' .. folder_name .. '/' .. tmpl)
  then
    vim.cmd('$read ' .. workspace_path .. '/' .. folder_name .. '/' .. tmpl .. '| silent! w')
  end
end

--- Opens a note entry for tomorrow's date
M.note_tomorrow = function()
  M.open_note(os.time() + 24 * 60 * 60)
end

--- Opens a note entry for yesterday's date
M.note_yesterday = function()
  M.open_note(os.time() - 24 * 60 * 60)
end

M.year_prev = function()
  M.open_note(os.time() - 24 * 60 * 60 * 365)
end
M.year_next = function()
  M.open_note(os.time() + 24 * 60 * 60 * 365)
end
M.month_prev = function()
  M.open_note(os.time() - 24 * 60 * 60 * 30)
end

M.month_next = function()
  M.open_note(os.time() + 24 * 60 * 60 * 30)
end

M.week_prev = function()
  M.open_note(os.time() - 24 * 60 * 60 * 7)
end

M.week_next = function()
  M.open_note(os.time() + 24 * 60 * 60 * 7)
end

--- Opens a note entry for today's date
M.note_today = function()
  M.open_note()
end

M.create_month_template = function()
  local workspace = M.config.workspace
  local folder_name = M.config.note_folder
  local tmpl = M.config.template.month
  M.dep['workspace'].new_file(
    folder_name .. config.pathsep .. tmpl,
    workspace or M.dep['workspace'].get_current_workspace()[1]
  )
end
--- Creates a template file
M.create_year_template = function()
  local workspace = M.config.workspace
  local folder_name = M.config.note_folder
  local tmpl = M.config.template.year
  M.dep['workspace'].new_file(
    folder_name .. config.pathsep .. tmpl,
    workspace or M.dep['workspace'].get_current_workspace()[1]
  )
end
M.create_day_template = function()
  local workspace = M.config.workspace
  local folder_name = M.config.note_folder
  local tmpl = M.config.template.day

  M.dep['workspace'].new_file(
    folder_name .. config.pathsep .. tmpl,
    workspace or M.dep['workspace'].get_current_workspace()[1]
  )
end

--- Opens the toc file
M.open_toc = function()
  local workspace = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local index = mod.mod_config 'workspace'.index
  local folder_name = M.config.note_folder

  -- If the toc exists, open it, if not, create it
  if M.dep['workspace'].file_exists(folder_name .. config.pathsep .. index) then
    M.dep['workspace'].open_file(workspace, folder_name .. config.pathsep .. index)
  else
    M.create_toc()
  end
end

--- Creates or updates the toc file
M.create_toc = function()
  local workspace = M.config.workspace or M.dep['workspace'].get_current_workspace()[1]
  local index = mod.mod_config('workspace').index
  local workspace_path = M.dep['workspace'].get_workspace(workspace)
  local workspace_name_for_link = M.config.workspace or ''
  local folder_name = M.config.note_folder

  -- Each entry is a table that contains tables like { yy, mm, dd, link, title }
  local toc_entries = {}

  -- Get a filesystem handle for the files in the note folder
  -- path is for each subfolder
  local get_fs_handle = function(path)
    path = path or ''
    local handle =
        vim.loop.fs_scandir(workspace_path .. config.pathsep .. folder_name .. config.pathsep .. path)

    if type(handle) ~= 'userdata' then
      error(lib.lazy_string_concat("Failed to scan directory '", workspace, path, "': ", handle))
    end

    return handle
  end

  -- Gets the title from the metadata of a file, must be called in a vim.schedule
  local get_title = function(file)
    local buffer =
        vim.fn.bufadd(workspace_path .. config.pathsep .. folder_name .. config.pathsep .. file)
    local meta = M.dep['workspace'].get_document_metadata(buffer)
    return meta.title
  end

  vim.loop.fs_scandir(
    workspace_path .. config.pathsep .. folder_name .. config.pathsep,
    function(err, handle)
      assert(
        not err,
        lib.lazy_string_concat("Unable to generate TOC for directory '", folder_name, "' - ", err)
      )

      while true do
        -- Name corresponds to either a YYYY-mm-dd.down file, or just the year ("nested" strategy)
        local name, type = vim.loop.fs_scandir_next(handle) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        if not name then
          break
        end
        if type == 'directory' then
          local years_handle = get_fs_handle(name)
          while true do
            local mname, mtype = vim.loop.fs_scandir_next(years_handle)
            if not mname then
              break
            end

            if mtype == 'directory' then
              local months_handle = get_fs_handle(name .. config.pathsep .. mname)
              while true do
                local dname, dtype = vim.loop.fs_scandir_next(months_handle)
                if not dname then
                  break
                end

                -- If it's a .down file, also ensure it is a day entry
                if dtype == 'file' and (dname):match('%d%d%.md') then
                  -- Split the file name
                  local file = vim.split(dname, '.', { plain = true })

                  vim.schedule(function()
                    -- Get the title from the metadata, else, it just base to the name of the file
                    local title = get_title(
                      name .. config.pathsep .. mname .. config.pathsep .. dname
                    ) or file[1]

                    -- Insert a new entry
                    table.insert(toc_entries, {
                      tonumber(name),
                      tonumber(mname),
                      tonumber(file[1]),
                      '{:$'
                      .. workspace_name_for_link
                      .. config.pathsep
                      .. M.config.note_folder
                      .. config.pathsep
                      .. name
                      .. config.pathsep
                      .. mname
                      .. config.pathsep
                      .. file[1]
                      .. ':}',
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
        if type == 'file' and string.match(name, '%d+-%d+-%d+%.md') then
          -- Split yyyy-mm-dd to a table
          local file = vim.split(name, '.', { plain = true })
          local parts = vim.split(file[1], '-')

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
              '{:$'
              .. workspace_name_for_link
              .. config.pathsep
              .. M.config.note_folder
              .. config.pathsep
              .. file[1]
              .. ':}',
              title,
            })
          end)
        end
      end

      vim.schedule(function()
        local format = M.config.toc_format
            or function(entries)
              local months_text = M.months
              local output = {}
              local current_year, current_month
              for _, entry in ipairs(entries) do
                if not current_year or current_year < entry[1] then
                  current_year = entry[1]
                  current_month = nil
                  output:insert('* ' .. current_year)
                end
                if not current_month or current_month < entry[2] then
                  current_month = entry[2]
                  output:insert('** ' .. months_text[current_month])
                end

                -- Prints the file link
                output:insert('   ' .. entry[4] .. ('[%s]'):format(entry[5]))
              end

              return output
            end

        M.dep['workspace'].new_file(
          folder_name .. config.pathsep .. index,
          workspace or M.dep['workspace'].get_current_workspace()[1]
        )

        -- The current buffer now must be the toc file, so we set our toc entries there
        vim.api.nvim_buf_set_lines(0, 0, -1, false, format(toc_entries))
        -- vim.cmd("w")
      end)
    end
  )
end

---@class (exact) down.mod.note.Config
M.config = {
  -- Which workspace to use for the note files, the base behaviour
  -- is to use the current workspace.
  --
  -- It is recommended to set this to a static workspace, but the most optimal
  -- behaviour may vary from workflow to workflow.
  workspace = nil,

  -- The name for the folder in which the note files are put.
  note_folder = 'note',

  index = 'index.md',

  -- The strategy to use to create directories.
  -- May be "flat" (`2022-03-02.down`), "nested" (`2022/03/02.down`),
  -- a lua string with the format given to `os.date()` or a lua function
  -- that returns a lua string with the same format.
  strategy = 'nested',

  -- The name of the template file to use when running `:down note template`.
  template = {

    enable = true,
    day = 'day.md',
    month = 'month.md',
    year = 'month.md',
    week = 'week.md',
    default = 'note.md',
  },

  -- Formatter function used to generate the toc file.
  -- Receives a table that contains tables like { yy, mm, dd, link, title }.
  --
  -- The function must return a table of strings.
  toc_format = nil,
}

M.config.strategies = {
  flat = '%Y-%m-%d.md',
  nested = '%Y' .. config.pathsep .. '%m' .. config.pathsep .. '%d.md',
}

M.open_month_calendar = function(event)
  if not event.body[1] then
    local cal = M.dep['ui.calendar']
    if not cal then
      log.error '[ERROR]: `ui.calendar` is not loaded!'
      return
    end
    cal.select_date({
      callback = vim.schedule_wrap(function(osdate)
        M.open_note(
          nil,
          ('%04d'):format(osdate.year)
          .. '-'
          .. ('%02d'):format(osdate.month)
          .. '-'
          .. ('%02d'):format(osdate.day)
        )
      end),
    })
  else
    M.open_note(nil, event.body[1])
  end
end

M.commands = {
  calendar = {
    min_args = 0,
    max_args = 1,
    callback = M.open_month_calendar,
    name = 'calendar',
  }, -- format :yyyy-mm-dd
  note = {
    name = 'note',
    callback = function(e)
      log.trace 'note'
    end,
    min_args = 1,
    max_args = 2,
    commands = {
      index = {
        callback = M.note_index,
        args = 0,
        enabled = true,
        name = 'note.index',
      },
      month = {
        max_args = 1,
        enabled = true,
        name = 'note.month',
        callback = M.month_index,
        commands = {
          index = {
            callback = M.month_index,
            args = 0,
            enabled = true,
            name = 'note.month.index',
          },
          previous = {
            args = 0,
            callback = M.month_prev,
            name = 'note.month.previous',
          },
          next = {
            args = 0,
            name = 'note.month.next',
            callback = M.month_next,
          },
        },
      },
      week = {
        commands = {
          index = {
            args = 0,
            name = 'note.week.index',
            callback = M.week_index,
          },
          previous = {
            args = 0,
            name = 'note.week.previous',
            callback = M.week_prev,
          },
          next = {
            args = 0,
            name = 'note.week.next',
            callback = M.week_next,
          },
        },
        max_args = 1,
        name = 'note.week',
        callback = M.week_index,
      },
      year = {
        max_args = 1,
        name = 'note.year',
        callback = M.year_index,
        commands = {
          index = {
            args = 0,
            callback = M.year_index,
            name = 'note.year.index',
          },
          previous = {
            args = 0,
            name = 'note.year.previous',
            callback = M.year_prev,
          },
          next = {
            args = 0,
            name = 'note.year.next',
            callback = M.year_next,
          },
        },
      },
      capture = {
        callback = M.capture,
        args = 0,
        enabled = false,
        name = 'note.capture',
      },
      tomorrow = {
        callback = M.note_tomorrow,
        args = 0,
        name = 'note.tomorrow',
      },
      yesterday = {
        args = 0,
        name = 'note.yesterday',
        callback = M.note_yesterday,
      },
      today = {
        callback = M.note_today,
        args = 0,
        name = 'note.today',
      },
      calendar = {
        callback = M.open_month_calendar,
        max_args = 1,
        name = 'note.calendar',
      }, -- format :yyyy-mm-dd
      template = {
        callback = M.create_day_template,
        commands = {
          year = {
            callback = M.create_year_template,
            name = 'notes.template.year',
            args = 0,
          },
          week = {
            callback = M.create_year_template,
            name = 'notes.template.week',
            args = 0,
          },
          month = {
            callback = M.create_month_template,
            name = 'notes.template.month',
            args = 0,
          },
          day = {
            callback = M.create_day_template,
            name = 'notes.template.day',
            args = 0,
          },
        },
        args = 0,
        name = 'note.template',
      },
      toc = {
        enabled = false,
        args = 1,
        name = 'note.toc',
        callback = M.open_toc,
        commands = {
          open = {
            callback = M.open_toc,
            args = 0,
            name = 'note.toc.open',
          },
          update = {
            args = 0,
            name = 'note.toc.update',
            callback = M.create_toc,
          },
        },
      },
    },
  },
}

M.load = function()
  if M.config.strategies[M.config.strategy] then
    M.config.strategy = M.config.strategies[M.config.strategy]
  end
end

---@return down.mod.Setup
M.setup = function()
  return {
    loaded = true,
    dependencies = {
      'ui.win',
      'ui.calendar',
      'data',
      'cmd',
      'template',
      'workspace',
      'tool.treesitter',
    },
  }
end

-- -@class down.mod.note.Subscribed
-- M.handle = {
-- cmd = {
-- ['note.index'] = M.note_index,
-- ['note.month'] = M.month_index,
-- ['note.week'] = M.week_index,
-- ['note.year'] = M.year_index,
-- ['note'] = function(e) end
-- ['note.month.previous'] = M.month_prev,
-- ['note.week.previous'] = M.week_prev,
-- ['note.year.previous'] = M.year_prev,
-- ['note.month.next'] = M.month_next,
-- ['note.week.next'] = M.week_next,
-- ['note.year.next'] = M.year_next,
-- ['note.month.index'] = M.month_index,
-- ['note.week.index'] = M.week_index,
-- ['note.year.index'] = M.year_index,
-- ['note.yesterday'] = M.note_yesterday,
-- ['note.tomorrow'] = M.note_tomorrow,
-- ['note.capture'] = M.capture,
-- ['note.today'] = M.note_today,
-- ['calendar'] = M.open_note,
-- ['note.calendar'] = M.open_note,
-- ['note.template'] = M.create_day_template,
-- ['note.template.day'] = M.create_day_template,
-- ['note.template.month'] = M.create_month_template,
-- ['note.template.year'] = M.create_year_template,
-- ['note.toc.update'] = M.create_toc,
-- ['note.toc.open'] = M.open_toc,
-- ['note.template.week'] = function(e) end,
-- },
-- }

return M
