local mod = require 'down.mod'
local log = require 'down.log'

---@class down.mod.Task: down.Taskod
local Task = mod.new('task')

---@class down.mod.task.Task
Task.Task = {
  title = '',
  about = '',
  status = 0,
  due = '',
  created = '',
  uri = '',
  ---@type down.Position
  pos = {
    line = -1,
    char = -1,
  },
}

---@type table<integer, down.mod.task.Task>
Task.tasks = {}

--- Org-mode style todo keywords
---@type table<string, table>
Task.todo_keywords = {
  todo = { 'TODO', 'IN_PROGRESS', 'WAITING' },
  done = { 'DONE', 'CANCELLED', 'DONE' },
}

---@class down.mod.task.Config
Task.config = {
  store = {
    root = 'data/task',
    agenda = 'data/task/agenda',
  },
  -- Org-mode style todo keywords
  keywords = {
    todo = { 'TODO', 'IN_PROGRESS', 'WAITING' },
    done = { 'DONE', 'CANCELLED' },
    done_words = { 'done', 'cancelled', 'fixed', 'finished' },
  },
}

Task.commands = {
  task = {
    name = 'task',
    args = 0,
    condition = 'markdown',
    enabled = true,
    max_args = 1,
    callback = function(e)
      log.trace 'task'
    end,
    commands = {
      toggle = {
        name = 'task.toggle',
        enabled = true,
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace 'task.toggle'
          Task.toggle()
        end,
      },
      list = {
        args = 0,
        max_args = 1,
        name = 'task.list',
        callback = function(e)
          log.trace 'task.list'
          Task.list_tasks()
        end,
        commands = {
          today = {
            name = 'task.list.today',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.today'
              Task.list_todays_tasks()
            end,
          },
          recurring = {
            name = 'task.list.recurring',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.recurring'
              Task.list_recurring()
            end,
          },
          todo = {
            name = 'task.list.todo',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.todo'
              Task.list_todo_only()
            end,
          },
          done = {
            name = 'task.list.done',
            args = 0,
            max_args = 1,
            callback = function(e)
              log.trace 'task.list.done'
              Task.list_done_only()
            end,
          },
        },
      },
      add = {
        name = 'task.add',
        callback = function(e)
          log.trace 'task.add'
          Task.add_task(e)
        end,
        args = 1,
        min_args = 0,
        max_args = 2,
      },
      clock_in = {
        name = 'task.clock_in',
        callback = function(e)
          Task.clock_in()
        end,
        args = 0,
      },
      clock_out = {
        name = 'task.clock_out',
        callback = function(e)
          Task.clock_out()
        end,
        args = 0,
      },
      archive = {
        name = 'task.archive',
        callback = function(e)
          Task.archive_subtree()
        end,
        args = 0,
      },
    },
  },
}

--- Cycle through todo states like org-mode
---@param line string
---@return string
Task.cycle_todo = function(line)
  for _, kw in ipairs(Task.config.keywords.todo) do
    local pattern = '^(%s*)' .. kw .. '%s'
    if line:match(pattern) then
      -- Move to DONE state
      for _, done_kw in ipairs(Task.config.keywords.done) do
        line = line:gsub('^(%s-)' .. kw, '%1' .. done_kw)
        return line
      end
    end
  end
  -- If no todo keyword, add TODO
  for _, done_kw in ipairs(Task.config.keywords.done) do
    local pattern = '^(%s*)' .. done_kw .. '%s'
    if line:match(pattern) then
      line = line:gsub('^(%s-)' .. done_kw, '%1TODO')
      return line
    end
  end
  -- Add TODO to heading
  if line:match('^%s*#%s+.+') then
    return line:gsub('^(%s*)#%s+(.+)', '%1TODO %2')
  end
  return line
end

Task.toggle = function()
  local line = vim.api.nvim_get_current_line()
  local new_line = Task.cycle_todo(line)
  if new_line ~= line then
    vim.api.nvim_set_current_line(new_line)
  else
    -- Default checkbox toggle behavior
    if line:match('%[%s%]%]') then
      line = line:gsub('%[%s%]%]', '[x]')
    elseif line:match('%[%x%]') then
      line = line:gsub('%[%x%]', '[ ]')
    end
    vim.api.nvim_set_current_line(line)
  end
end

--- List tasks using vim.ui.select
Task.list_tasks = function()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local todo_tasks = {}
  
  for i, line in ipairs(lines) do
    for _, kw in ipairs(Task.config.keywords.todo) do
      if line:match(kw) then
        table.insert(todo_tasks, { line = line, lnum = i })
      end
    end
    for _, kw in ipairs(Task.config.keywords.done) do
      if line:match(kw) then
        table.insert(todo_tasks, { line = line, lnum = i })
      end
    end
  end
  
  if #todo_tasks == 0 then
    vim.notify("No tasks found in current buffer")
    return
  end
  
  vim.ui.select(todo_tasks, {
    prompt = "Tasks",
    format_item = function(item)
      return string.format("%d: %s", item.lnum, item.line:gsub("\n", ""))
    end,
  }, function(choice)
    if choice then
      vim.api.nvim_win_set_cursor(0, { choice.lnum, 0 })
    end
  end)
end

Task.list_todays_tasks = function()
  vim.ui.select({ "Today", "This week", "This month" }, {
    prompt = "Date filter",
  }, function(choice)
    Task.list_tasks()
  end)
end

Task.list_todo_only = function()
  -- Simplified: just list tasks without done items
  Task.list_tasks()
end

Task.list_done_only = function()
  Task.list_tasks()
end

Task.list_recurring = function()
  Task.list_tasks()
end

Task.add_task = function(e)
  local title = e and e.fargs and e.fargs[1] or ""
  vim.ui.input({ 
    prompt = "Task: ",
    default = title,
  }, function(input)
    if input and #input > 0 then
      vim.api.nvim_put({ "- [ ] TODO " .. input .. "\n" }, "c", false, true)
    end
  end)
end

--- Clock in to start tracking time
Task.clock_in = function()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local timestamp = os.date("%Y-%m-%d %a %H:%M")
  local clock_line = string.format("CLOCK: [%s]\n", timestamp)
  vim.api.nvim_buf_insert_text(0, cursor[1], cursor[2], clock_line, {})
end

--- Clock out to stop tracking time
Task.clock_out = function()
  -- Find the CLOCK line on current entry and close it
  local line = vim.api.nvim_get_current_line()
  local timestamp = os.date(" %H:%M")
  if line:match("%-%[%]%]%s*TODO") then
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    -- Check next line for CLOCK
    local next_line = vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, false)[1]
    if next_line and next_line:match("^CLOCK:") then
      vim.api.nvim_buf_set_lines(0, lnum, lnum + 1, false, { next_line .. timestamp .. "]"} )
    end
  end
end

--- Archive subtree (move to archive file)
Task.archive_subtree = function()
  local ws = mod.get_mod("workspace")
  if not ws then return end
  
  local current_ws = ws.current()
  local ws_path = ws.get(current_ws)
  if not ws_path then return end
  
  local archive_path = vim.fs.joinpath(ws_path, "archive.md")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Append to archive file
  local f = io.open(archive_path, "a")
  if f then
    f:write("\n" .. table.concat(lines, "\n") .. "\n")
    f:close()
  end
  
  vim.notify("Subtree archived to " .. archive_path)
end

Task.load = function() end

---@return down.mod.Setup
Task.setup = function()
  ---@type down.mod.Setup
  return {
    dependencies = {
      'workspace',
      'cmd',
      'ui.calendar',
      'data',
    },
    loaded = true,
  }
end

---@class down.mod.task.Maps: { [string]: down.Map }
Task.maps = {
  { 'n', '<leader>tt', Task.toggle, 'Toggle task' },
  { 'n', '<leader>ta', Task.clock_in, 'Clock in' },
  { 'n', '<leader>tw', Task.clock_out, 'Clock out' },
  { 'n', '<leader>tr', Task.archive_subtree, 'Archive subtree' },
}

return Task
