local mod = require("down.mod")
local log = require("down.log")
local Frontmatter = require("down.mod.data.props.frontmatter")

local Agenda = mod.new("task.agenda")
Agenda.dep = { "cmd", "workspace", "task", "data.props" }

Agenda.Agenda = {
  uri = "",
  store = {},
  tasks = {},
}

Agenda.agendas = {}

Agenda.config = {
  uri = "",
  store = "data/agendas",
  views = {
    "overdue",
    "today",
    "tomorrow",
    "this_week",
    "next_week",
    "this_month",
    "later",
    "no_date",
    "completed",
  },
  exclude_patterns = {
    "^archive.md$",
    "^templates/",
    "^.git/",
    "^%.obsidian/",
  },
}

Agenda.commands = {
  agenda = {
    name = "agenda",
    args = 0,
    max_args = 2,
    callback = function(e)
      local view = e.fargs and e.fargs[1] or "all"
      local tag_filter = e.fargs and e.fargs[2] or nil
      Agenda.show_agenda(view, tag_filter)
    end,
    commands = {
      tasks = {
        name = "agenda.tasks",
        args = 0,
        max_args = 1,
        callback = function(e)
          Agenda.show_simple_task_list(e.fargs and e.fargs[1])
        end,
      },
      project = {
        name = "agenda.project",
        args = 1,
        max_args = 1,
        callback = function(e)
          if e.fargs then
            Agenda.show_project_agenda(e.fargs[1])
          end
        end,
      },
      refresh = {
        name = "agenda.refresh",
        args = 0,
        callback = function()
          Agenda.refresh_cache()
        end,
      },
    },
  },
}

Agenda.maps = {
  { "n", "<leader>aa", "<CMD>Down agenda<CR>", "Open agenda" },
  { "n", "<leader>at", "<CMD>Down agenda today<CR>", "Agenda: today" },
  { "n", "<leader>ao", "<CMD>Down agenda overdue<CR>", "Agenda: overdue" },
  { "n", "<leader>aw", "<CMD>Down agenda this_week<CR>", "Agenda: this week" },
}

Agenda._task_cache = nil
Agenda._cache_time = nil
Agenda._cache_ttl = 30

Agenda.collect_all_tasks = function(force_refresh)
  if not force_refresh and Agenda._task_cache then
    local elapsed = os.time() - (Agenda._cache_time or 0)
    if elapsed < Agenda._cache_ttl then
      return Agenda._task_cache
    end
  end

  local ws = mod.get_mod("workspace")
  if not ws then
    return {}
  end

  local ws_path = ws.get(ws.current())
  if not ws_path then
    return {}
  end

  local tasks = {}

  local function is_excluded(path)
    local rel = path:sub(#ws_path + 2)
    for _, pattern in ipairs(Agenda.config.exclude_patterns) do
      if rel:match(pattern) then
        return true
      end
    end
    return false
  end

  local function scan_dir(dir)
    local handle = vim.loop.fs_scandir(dir)
    if not handle then
      return
    end
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end
      local path = vim.fs.joinpath(dir, name)
      if is_excluded(path) then
        goto continue
      end
      if type == "directory" then
        scan_dir(path)
      elseif name:match("%.md$") then
        Agenda.extract_tasks_from_file(path, tasks)
      end
      ::continue::
    end
  end

  scan_dir(ws_path)

  Agenda._task_cache = tasks
  Agenda._cache_time = os.time()
  return tasks
end

Agenda.extract_tasks_from_file = function(file_path, tasks)
  local ok, lines = pcall(vim.fn.readfile, file_path)
  if not ok then
    return
  end

  local fm_data = nil
  if #lines > 0 and lines[1]:match("^%-%-%-%s*$") then
    fm_data, _ = Frontmatter.parse(lines, 1)
  end

  local is_task_file = fm_data and (fm_data.type == "task" or fm_data.type == "database")
  local current_heading = ""

  for i, line in ipairs(lines) do
    local heading = line:match("^#+%s+(.+)")
    if heading then
      current_heading = heading:gsub("%s+$", ""):gsub("^%s+", "")
    end

    local is_task = false
    local status = "TODO"
    local priority = ""
    local due = ""
    local tags = {}
    local title = line

    for _, kw in ipairs({ "TODO", "IN_PROGRESS", "WAITING" }) do
      if line:match(kw) then
        is_task = true
        status = kw
        break
      end
    end
    if not is_task then
      for _, kw in ipairs({ "DONE", "CANCELLED" }) do
        if line:match(kw) then
          is_task = true
          status = kw
          break
        end
      end
    end
    if not is_task then
      if line:match("%- %[xX%]") then
        is_task = true
        status = "DONE"
      elseif line:match("%- %[ %]") then
        is_task = true
        status = "TODO"
      end
    end

    if is_task or is_task_file then
      if is_task then
        local pm = line:match("%[#(%u)%]")
        if pm then
          priority = pm
        end

        local dm = line:match("DEADLINE:%s*<(%d%d%d%d%-%d%d%-%d%d)")
        if dm then
          due = dm
        elseif fm_data and fm_data.due_date then
          due = fm_data.due_date
        end

        for tag in line:gmatch("#([%w_%-/]+)") do
          table.insert(tags, tag)
        end

        title = line:gsub("%[.?%]%s*", "")
          :gsub("%[#%u%]%s*", "")
          :gsub("DEADLINE:%s*<%d%d%d%d%-%d%d%-%d%d[^>]*>", "")
          :gsub("SCHEDULED:%s*<%d%d%d%d%-%d%d%-%d%d[^>]*>", "")
          :gsub("CLOCK:%s*%[.-%]", "")
          :gsub("TODO%s*", "")
          :gsub("IN_PROGRESS%s*", "")
          :gsub("WAITING%s*", "")
          :gsub("DONE%s*", "")
          :gsub("CANCELLED%s*", "")
          :gsub("^%s*%-%s*", "")
          :gsub("^%s*%*%s*", "")
          :gsub("%s+$", "")
          :gsub("^%s+", "")
      else
        title = fm_data and fm_data.title or current_heading
        status = fm_data and fm_data.status or "TODO"
        priority = fm_data and fm_data.priority or ""
        due = fm_data and fm_data.due_date or ""
        tags = fm_data and fm_data.tags or {}
      end

      table.insert(tasks, {
        title = title,
        status = status,
        priority = priority,
        due = due,
        tags = tags,
        file = file_path,
        line = i,
        heading = current_heading,
      })
    end
  end
end

Agenda.group_by_date = function(tasks)
  local today = os.date("*t")
  local today_str = os.date("%Y-%m-%d")
  local tomorrow = os.date("%Y-%m-%d", os.time(today) + 86400)
  local end_of_week = os.date("%Y-%m-%d", os.time(today) + (7 - today.wday) * 86400)
  local next_week_end = os.date("%Y-%m-%d", os.time(today) + (14 - today.wday) * 86400)
  local end_of_month = os.date("%Y-%m-%d", os.time({
    year = today.year,
    month = today.month + 1,
    day = 0,
  }))

  local groups = {
    overdue = { label = "Overdue", tasks = {} },
    today = { label = "Today", tasks = {} },
    tomorrow = { label = "Tomorrow", tasks = {} },
    this_week = { label = "This Week", tasks = {} },
    next_week = { label = "Next Week", tasks = {} },
    this_month = { label = "This Month", tasks = {} },
    later = { label = "Later", tasks = {} },
    no_date = { label = "No Date", tasks = {} },
    completed = { label = "Completed", tasks = {} },
  }

  for _, task in ipairs(tasks) do
    local is_done = task.status == "DONE" or task.status == "CANCELLED"

    if is_done then
      table.insert(groups.completed.tasks, task)
    elseif task.due == "" then
      table.insert(groups.no_date.tasks, task)
    elseif task.due < today_str then
      table.insert(groups.overdue.tasks, task)
    elseif task.due == today_str then
      table.insert(groups.today.tasks, task)
    elseif task.due == tomorrow then
      table.insert(groups.tomorrow.tasks, task)
    elseif task.due <= end_of_week then
      table.insert(groups.this_week.tasks, task)
    elseif task.due <= next_week_end then
      table.insert(groups.next_week.tasks, task)
    elseif task.due <= end_of_month then
      table.insert(groups.this_month.tasks, task)
    else
      table.insert(groups.later.tasks, task)
    end
  end

  return groups
end

Agenda.sort_tasks = function(tasks)
  table.sort(tasks, function(a, b)
    local pa = a.priority or ""
    local pb = b.priority or ""
    if pa == "A" and pb ~= "A" then
      return true
    elseif pa ~= "A" and pb == "A" then
      return false
    elseif pa > pb then
      return false
    elseif pa < pb then
      return true
    end

    if a.due ~= "" and b.due ~= "" then
      return a.due < b.due
    elseif a.due ~= "" then
      return true
    elseif b.due ~= "" then
      return false
    end

    return (a.title or "") < (b.title or "")
  end)
end

Agenda.show_agenda = function(view, tag_filter)
  local all_tasks = Agenda.collect_all_tasks()
  local filtered = all_tasks

  if tag_filter then
    filtered = vim.tbl_filter(function(t)
      return vim.tbl_contains(t.tags, tag_filter)
    end, all_tasks)
  end

  local groups = Agenda.group_by_date(filtered)

  for _, g in pairs(groups) do
    Agenda.sort_tasks(g.tasks)
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 100)
  local height = math.min(vim.o.lines - 4, 35)
  local win = vim.api.nvim_open_win(bufnr, true, {
    style = "minimal",
    border = "single",
    title = " Agenda ",
    title_pos = "center",
    row = 2,
    col = math.max(0, (vim.o.columns - width) / 2),
    width = width,
    height = height,
    relative = "editor",
  })

  local lines = {}
  local total_count = 0

  local view_order = Agenda.config.views

  for _, group_key in ipairs(view_order) do
    if view == "all" or group_key == view then
      local g = groups[group_key]
      if g and g.tasks and #g.tasks > 0 then
        table.insert(lines, string.rep("─", width - 2))
        table.insert(lines, string.format("  %s (%d)", g.label, #g.tasks))
        table.insert(lines, "")

        for _, task in ipairs(g.tasks) do
          local icon = "○"
          if task.status == "DONE" or task.status == "CANCELLED" then
            icon = "✓"
          elseif task.status == "IN_PROGRESS" then
            icon = "◉"
          elseif task.status == "WAITING" then
            icon = "◔"
          end

          local display = string.format("    %s %s", icon, task.title)
          if task.priority ~= "" then
            display = display .. string.format(" [#%s]", task.priority)
          end
          if task.due ~= "" and group_key ~= "no_date" then
            display = display .. string.format(" <%s>", task.due)
          end

          if #display > width - 2 then
            display = display:sub(1, width - 5) .. "..."
          end
          table.insert(lines, display)
          total_count = total_count + 1
        end
        table.insert(lines, "")
      end
    end
  end

  if total_count == 0 then
    table.insert(lines, "  No tasks found.")
  end

  table.insert(lines, "")
  table.insert(lines, string.format("  Total: %d tasks   q=close   <CR>=open", total_count))

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "agenda", { buf = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.bo[bufnr].bufhidden = "wipe"

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })

  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local lnum = cursor[1]
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]

    if line then
      local title_match = line:match("%a%s+(.+)%s+%[")
      if not title_match then
        title_match = line:match("%a%s+(.+)%s+<")
      end
      if not title_match then
        title_match = line:match("%a%s+(.+)")
      end
      if title_match then
        title_match = title_match:gsub("%s+$", ""):gsub("%[#[A-E]%]", ""):gsub("<%d%d%d%d%-%d%d%-%d%d>", ""):gsub("%s+$", "")
        for _, task in ipairs(all_tasks) do
          if task.title and task.title:gsub("%s+$", "") == title_match then
            pcall(vim.api.nvim_win_close, win, true)
            vim.cmd("edit " .. task.file)
            if task.line > 0 then
              vim.api.nvim_win_set_cursor(0, { task.line, 0 })
            end
            return
          end
        end
      end
    end
  end, { buffer = bufnr })

  vim.keymap.set("n", "r", function()
    pcall(vim.api.nvim_win_close, win, true)
    Agenda.show_agenda(view, tag_filter)
  end, { buffer = bufnr })
end

Agenda.show_simple_task_list = function(tag_filter)
  Agenda.show_agenda("all", tag_filter)
end

Agenda.show_project_agenda = function(project)
  local all_tasks = Agenda.collect_all_tasks()
  local filtered = vim.tbl_filter(function(t)
    return vim.tbl_contains(t.tags, project) or
      (t.file and t.file:match(project) ~= nil)
  end, all_tasks)

  local groups = Agenda.group_by_date(filtered)
  for _, g in pairs(groups) do
    Agenda.sort_tasks(g.tasks)
  end

  Agenda._task_cache = filtered
  Agenda.show_agenda("all")
  Agenda._task_cache = all_tasks
end

Agenda.refresh_cache = function()
  Agenda._task_cache = nil
  Agenda._cache_time = nil
  Agenda.collect_all_tasks(true)
  vim.notify("[down.nvim] Agenda cache refreshed")
end

Agenda.setup = function()
  return {
    loaded = true,
  }
end

return Agenda
