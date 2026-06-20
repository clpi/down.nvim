local mod = require("down.mod")
local log = require("down.log")
local Frontmatter = require("down.mod.data.props.frontmatter")
local Query = require("down.mod.data.database.query")

---@class down.mod.Task
local Task = mod.new("task")
Task.dep = { "workspace", "cmd", "ui.calendar", "data" }

---@class down.mod.task.Task
Task.Task = {
  title = "",
  about = "",
  status = 0,
  priority = "Medium",
  due = "",
  created = "",
  tags = {},
  assignee = "",
  recurrence = nil,
  uri = "",
  pos = { line = -1, char = -1 },
}

Task.tasks = {}

Task.todo_keywords = {
  todo = { "TODO", "IN_PROGRESS", "WAITING" },
  done = { "DONE", "CANCELLED" },
}

Task.priority_levels = {
  { key = "A", name = "Critical", weight = 4 },
  { key = "B", name = "High", weight = 3 },
  { key = "C", name = "Medium", weight = 2 },
  { key = "D", name = "Low", weight = 1 },
  { key = "E", name = "Trivial", weight = 0 },
}

Task.config = {
  store = {
    root = "data/task",
    agenda = "data/task/agenda",
  },
  keywords = {
    todo = { "TODO", "IN_PROGRESS", "WAITING" },
    done = { "DONE", "CANCELLED" },
    done_words = { "done", "cancelled", "fixed", "finished" },
  },
  priorities = {
    "A", "B", "C", "D", "E",
  },
  recurrence = {
    daily = { interval = "day", count = 1 },
    weekly = { interval = "week", count = 1 },
    biweekly = { interval = "week", count = 2 },
    monthly = { interval = "month", count = 1 },
    yearly = { interval = "year", count = 1 },
    weekdays = { interval = "weekdays", count = 1 },
  },
}

Task.commands = {
  task = {
    name = "task",
    args = 0,
    condition = "markdown",
    enabled = true,
    max_args = 1,
    callback = function(e)
      log.trace("task")
    end,
    commands = {
      toggle = {
        name = "task.toggle",
        enabled = true,
        args = 0,
        max_args = 1,
        callback = function(e)
          Task.toggle()
        end,
      },
      priority = {
        name = "task.priority",
        args = 0,
        max_args = 1,
        callback = function(e)
          local level = e.fargs and e.fargs[1]
          Task.set_priority(level)
        end,
      },
      due = {
        name = "task.due",
        args = 0,
        max_args = 1,
        callback = function(e)
          local date = e.fargs and e.fargs[1]
          Task.set_due_date(date)
        end,
      },
      recur = {
        name = "task.recur",
        args = 1,
        max_args = 1,
        callback = function(e)
          local pattern = e.fargs and e.fargs[1]
          Task.set_recurrence(pattern)
        end,
      },
      list = {
        args = 0,
        max_args = 1,
        name = "task.list",
        callback = function(e)
          Task.list_tasks()
        end,
        commands = {
          today = {
            name = "task.list.today",
            args = 0,
            max_args = 1,
            callback = function(e)
              Task.list_tasks({ due = os.date("%Y-%m-%d") })
            end,
          },
          overdue = {
            name = "task.list.overdue",
            args = 0,
            max_args = 1,
            callback = function(e)
              Task.list_tasks({ overdue = true })
            end,
          },
          priority = {
            name = "task.list.priority",
            args = 0,
            max_args = 1,
            callback = function(e)
              local level = e.fargs and e.fargs[1] or "A"
              Task.list_tasks({ priority = level })
            end,
          },
          recurring = {
            name = "task.list.recurring",
            args = 0,
            max_args = 1,
            callback = function(e)
              Task.list_tasks({ recurring = true })
            end,
          },
          todo = {
            name = "task.list.todo",
            args = 0,
            max_args = 1,
            callback = function(e)
              Task.list_tasks({ status = "todo" })
            end,
          },
          done = {
            name = "task.list.done",
            args = 0,
            max_args = 1,
            callback = function(e)
              Task.list_tasks({ status = "done" })
            end,
          },
        },
      },
      add = {
        name = "task.add",
        callback = function(e)
          Task.add_task(e)
        end,
        args = 1,
        min_args = 0,
        max_args = 3,
      },
      clock_in = {
        name = "task.clock_in",
        callback = function(e)
          Task.clock_in()
        end,
        args = 0,
      },
      clock_out = {
        name = "task.clock_out",
        callback = function(e)
          Task.clock_out()
        end,
        args = 0,
      },
      archive = {
        name = "task.archive",
        callback = function(e)
          Task.archive_subtree()
        end,
        args = 0,
      },
    },
  },
}

Task.is_todo = function(state)
  return vim.tbl_contains(Task.config.keywords.todo, state)
end

Task.is_done = function(state)
  return vim.tbl_contains(Task.config.keywords.done, state)
end

Task.cycle_todo = function(line)
  for _, kw in ipairs(Task.config.keywords.todo) do
    local pattern = "^(%s*)" .. kw .. "%s"
    if line:match(pattern) then
      for _, done_kw in ipairs(Task.config.keywords.done) do
        line = line:gsub("^(%s-)" .. kw, "%1" .. done_kw)
        return line
      end
    end
  end
  for _, done_kw in ipairs(Task.config.keywords.done) do
    local pattern = "^(%s*)" .. done_kw .. "%s"
    if line:match(pattern) then
      line = line:gsub("^(%s-)" .. done_kw, "%1TODO")
      return line
    end
  end
  if line:match("^%s*#%s+.+") then
    return line:gsub("^(%s*)#%s+(.+)", "%1TODO %2")
  end
  return line
end

Task.toggle = function()
  local line = vim.api.nvim_get_current_line()
  local new_line = Task.cycle_todo(line)
  if new_line ~= line then
    vim.api.nvim_set_current_line(new_line)
  else
    if line:match("%[%s%]") then
      line = line:gsub("%[%s%]", "[x]")
    elseif line:match("%[%x%]") then
      line = line:gsub("%[%x%]", "[ ]")
    end
    vim.api.nvim_set_current_line(line)
  end
end

Task.set_priority = function(level)
  if not level then
    vim.ui.select(Task.config.priorities, {
      prompt = "Priority:",
    }, function(choice)
      if choice then
        Task.set_priority_on_line(choice)
      end
    end)
    return
  end

  local valid = vim.tbl_contains(Task.config.priorities, level)
  if not valid then
    vim.notify("[down.nvim] Invalid priority. Use A, B, C, D, or E.", vim.log.levels.WARN)
    return
  end
  Task.set_priority_on_line(level)
end

Task.set_priority_on_line = function(level)
  local line = vim.api.nvim_get_current_line()
  local has_priority = line:match("%[#%u%]")

  if has_priority then
    line = line:gsub("%[#%u%]", "[#" .. level .. "]")
  else
    line = line:gsub("^(%s*%- %[.?%] )", "%1[#" .. level .. "] ")
  end

  vim.api.nvim_set_current_line(line)
  vim.notify("[down.nvim] Priority set to " .. level)
end

Task.set_due_date = function(date)
  if not date then
    vim.ui.input({ prompt = "Due date (YYYY-MM-DD): ", default = os.date("%Y-%m-%d") }, function(input)
      if input and #input > 0 then
        Task.set_due_date_on_line(input)
      end
    end)
    return
  end
  Task.set_due_date_on_line(date)
end

Task.set_due_date_on_line = function(date)
  local line = vim.api.nvim_get_current_line()
  local has_due = line:match("DEADLINE:%s*<%d%d%d%d%-%d%d%-%d%d")

  if has_due then
    line = line:gsub("DEADLINE:%s*<%d%d%d%d%-%d%d%-%d%d[^>]*>", "DEADLINE: <" .. date .. ">")
  else
    line = line .. " DEADLINE: <" .. date .. ">"
  end

  vim.api.nvim_set_current_line(line)

  Frontmatter.update_property(nil, "due_date", date)
  vim.notify("[down.nvim] Due date set to " .. date)
end

Task.set_recurrence = function(pattern)
  if not pattern then
    local options = vim.tbl_keys(Task.config.recurrence)
    vim.ui.select(options, {
      prompt = "Recurrence:",
    }, function(choice)
      if choice then
        Task.set_recurrence_on_line(choice)
      end
    end)
    return
  end

  if not Task.config.recurrence[pattern] then
    vim.notify("[down.nvim] Unknown recurrence: " .. pattern .. ". Use: " .. table.concat(vim.tbl_keys(Task.config.recurrence), ", "), vim.log.levels.WARN)
    return
  end
  Task.set_recurrence_on_line(pattern)
end

Task.set_recurrence_on_line = function(pattern)
  local line = vim.api.nvim_get_current_line()
  local has_recur = line:match("SCHEDULED:%s*<%d%d%d%d%-%d%d%-%d%d")
  local base_date = os.date("%Y-%m-%d")

  if has_recur then
    line = line:gsub("SCHEDULED:%s*<%d%d%d%d%-%d%d%-%d%d", "SCHEDULED: <" .. base_date .. " +1" .. pattern:sub(1, 1) .. ">")
  else
    line = line .. " SCHEDULED: <" .. base_date .. " +1" .. pattern:sub(1, 1) .. ">"
  end

  vim.api.nvim_set_current_line(line)

  local recur_config = Task.config.recurrence[pattern]
  if recur_config then
    Frontmatter.update_property(nil, "recurrence", { interval = recur_config.interval, count = recur_config.count })
  end
  vim.notify("[down.nvim] Recurrence set to " .. pattern)
end

Task.parse_task_line = function(line, lnum)
  local task = {
    title = "",
    status = "todo",
    priority = "",
    due = "",
    tags = {},
    lnum = lnum or 0,
  }

  local kw_found = false
  for _, kw in ipairs(Task.config.keywords.todo) do
    if line:match(kw) then
      task.status = kw
      kw_found = true
      break
    end
  end
  if not kw_found then
    for _, kw in ipairs(Task.config.keywords.done) do
      if line:match(kw) then
        task.status = kw
        kw_found = true
        break
      end
    end
  end

  local checkbox = line:match("%[(.)%]")
  if checkbox then
    if checkbox:match("[xX]") then
      task.status = "DONE"
    else
      task.status = task.status or "TODO"
    end
  end

  if line:match("DEADLINE:%s*<([^>]+)>") then
    local date_str = line:match("DEADLINE:%s*<(%d%d%d%d%-%d%d%-%d%d)")
    if date_str then
      task.due = date_str
    end
  end

  local priority_match = line:match("%[#(%u)%]")
  if priority_match then
    task.priority = priority_match
  end

  for tag in line:gmatch("#([%w_%-/]+)") do
    if tag ~= "priority" and tag ~= "recurring" then
      table.insert(task.tags, tag)
    end
  end

  local title = line:gsub("%[%]%]?%s*", "")
    :gsub("%[#%u%]%s*", "")
    :gsub("DEADLINE:%s*<%d%d%d%d%-%d%d%-%d%d[^>]*>", "")
    :gsub("SCHEDULED:%s*<%d%d%d%d%-%d%d%-%d%d[^>]*>", "")
    :gsub("CLOCK:%s*%[%d%d%d%d%-%d%d%-%d%d%s+%a+%s+%d%d:%d%d%]", "")
    :gsub("%s+$", "")
    :gsub("^%s*%-%s*", "")
    :gsub("^%s*%*%s*", "")

  for _, kw in ipairs(Task.config.keywords.todo) do
    title = title:gsub("^%s*" .. kw .. "%s*", "")
  end
  for _, kw in ipairs(Task.config.keywords.done) do
    title = title:gsub("^%s*" .. kw .. "%s*", "")
  end

  task.title = title:gsub("^%s+", ""):gsub("%s+$", "")
  return task
end

Task.list_tasks = function(filters)
  local lsp = mod.get_mod("lsp")
  if lsp and lsp.get_client and lsp.get_client() and lsp.list_tasks then
    lsp.list_tasks({ filters = filters })
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local tasks = {}

  for i, line in ipairs(lines) do
    local is_task = false
    for _, kw in ipairs(Task.config.keywords.todo) do
      if line:match(kw) then
        is_task = true
        break
      end
    end
    if not is_task then
      for _, kw in ipairs(Task.config.keywords.done) do
        if line:match(kw) then
          is_task = true
          break
        end
      end
    end
    if not is_task and line:match("%[{xX}%]") then
      is_task = true
    end
    if not is_task and line:match("%[ %]") then
      is_task = true
    end

    if is_task then
      local task = Task.parse_task_line(line, i)
      table.insert(tasks, task)
    end
  end

  if filters then
    if filters.status then
      if filters.status == "todo" then
        tasks = vim.tbl_filter(function(t)
          return Task.is_todo(t.status)
        end, tasks)
      elseif filters.status == "done" then
        tasks = vim.tbl_filter(function(t)
          return Task.is_done(t.status)
        end, tasks)
      end
    end
    if filters.priority then
      tasks = vim.tbl_filter(function(t)
        return t.priority == filters.priority
      end, tasks)
    end
    if filters.due then
      tasks = vim.tbl_filter(function(t)
        return t.due == filters.due
      end, tasks)
    end
    if filters.overdue then
      local today = os.date("%Y-%m-%d")
      tasks = vim.tbl_filter(function(t)
        return t.due ~= "" and t.due < today and Task.is_todo(t.status)
      end, tasks)
    end
    if filters.recurring then
      tasks = vim.tbl_filter(function(t)
        local line = lines[t.lnum]
        return line and line:match("SCHEDULED:") ~= nil
      end, tasks)
    end
  end

  table.sort(tasks, function(a, b)
    local pa = Task.get_priority_weight(a.priority)
    local pb = Task.get_priority_weight(b.priority)
    if pa ~= pb then
      return pa > pb
    end
    if a.due ~= "" and b.due ~= "" then
      return a.due < b.due
    elseif a.due ~= "" then
      return true
    elseif b.due ~= "" then
      return false
    end
    return a.lnum < b.lnum
  end)

  if #tasks == 0 then
    vim.notify("[down.nvim] No tasks found in current buffer")
    return
  end

  vim.ui.select(tasks, {
    prompt = "Tasks",
    format_item = function(item)
      local parts = {}
      table.insert(parts, string.format("%3d:", item.lnum))

      if item.priority ~= "" then
        table.insert(parts, "[#" .. item.priority .. "]")
      end

      local icon = Task.is_done(item.status) and "✓" or "○"
      table.insert(parts, icon)

      table.insert(parts, item.title)

      if item.due ~= "" then
        table.insert(parts, "<" .. item.due .. ">")
      end

      return table.concat(parts, " ")
    end,
  }, function(choice)
    if choice then
      vim.api.nvim_win_set_cursor(0, { choice.lnum, 0 })
    end
  end)
end

Task.get_priority_weight = function(level)
  for _, p in ipairs(Task.priority_levels) do
    if p.key == level then
      return p.weight
    end
  end
  return 0
end

Task.add_task = function(e)
  local title = e and e.fargs and e.fargs[1] or ""
  local priority = e and e.fargs and e.fargs[2] or ""
  local due = e and e.fargs and e.fargs[3] or ""

  if title == "" then
    vim.ui.input({
      prompt = "Task: ",
      default = title,
    }, function(input)
      if input and #input > 0 then
        Task.insert_task(input, priority, due)
      end
    end)
    return
  end

  Task.insert_task(title, priority, due)
end

Task.insert_task = function(title, priority, due)
  local parts = { "- [ ]" }

  if priority ~= "" and vim.tbl_contains(Task.config.priorities, priority) then
    table.insert(parts, "[#" .. priority .. "]")
  end

  local first_kw = Task.config.keywords.todo[1] or "TODO"
  table.insert(parts, first_kw)

  table.insert(parts, title)

  if due ~= "" and due:match("^%d%d%d%d%-%d%d%-%d%d") then
    table.insert(parts, "DEADLINE: <" .. due .. ">")
  end

  local line = table.concat(parts, " ")
  vim.api.nvim_put({ line .. "\n" }, "c", false, true)
end

Task.clock_in = function()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local timestamp = os.date("%Y-%m-%d %a %H:%M")
  local clock_line = string.format("CLOCK: [%s]\n", timestamp)

  local row = cursor[1]
  local next_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
  if next_line and not next_line:match("^CLOCK:") then
    vim.api.nvim_buf_set_lines(0, row, row, false, { clock_line:gsub("\n", "") })
  else
    vim.api.nvim_buf_set_lines(0, row, row, false, { clock_line:gsub("\n", ""), next_line or "" })
  end
end

Task.clock_out = function()
  local line = vim.api.nvim_get_current_line()
  local timestamp = os.date(" %H:%M")
  if line:match("^CLOCK:") then
    if not line:match("%]%s*$") then
      line = line:gsub("%s*$", timestamp .. "]")
    else
      line = line:gsub("%]", timestamp .. "]")
    end
    vim.api.nvim_set_current_line(line)
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  for i = lnum, math.max(1, lnum - 5), -1 do
    local prev = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if prev and prev:match("^CLOCK:") and not prev:match("%]%s*$") then
      prev = prev:gsub("%s*$", timestamp .. "]")
      vim.api.nvim_buf_set_lines(0, i - 1, i, false, { prev })
      vim.notify("[down.nvim] Clocked out")
      return
    end
  end
  vim.notify("[down.nvim] No active clock found", vim.log.levels.WARN)
end

Task.archive_subtree = function()
  local ws = mod.get_mod("workspace")
  if not ws then
    return
  end

  local current_ws = ws.current()
  local ws_path = ws.get(current_ws)
  if not ws_path then
    return
  end

  local archive_path = vim.fs.joinpath(ws_path, "archive.md")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local f = io.open(archive_path, "a")
  if f then
    f:write("\n" .. table.concat(lines, "\n") .. "\n")
    f:close()
  end

  vim.notify("[down.nvim] Subtree archived to " .. archive_path)
end

Task.setup = function()
  return {
    loaded = true,
  }
end

Task.maps = {
  { "n", "<leader>tt", Task.toggle, "Toggle task" },
  { "n", "<leader>tp", function() Task.set_priority() end, "Set task priority" },
  { "n", "<leader>td", function() Task.set_due_date() end, "Set task due date" },
  { "n", "<leader>tr", function() Task.set_recurrence() end, "Set task recurrence" },
  { "n", "<leader>ta", Task.clock_in, "Clock in" },
  { "n", "<leader>tw", Task.clock_out, "Clock out" },
  { "n", "<leader>tx", Task.archive_subtree, "Archive subtree" },
}

return Task
