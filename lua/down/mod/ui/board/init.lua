local mod = require("down.mod")
local log = require("down.log")
local Query = require("down.mod.data.database.query")

local Board = mod.new("ui.board")
Board.dep = { "cmd", "workspace", "data.props", "data.database" }

Board.config = {
  default_group = "status",
  default_groups = { "Backlog", "Todo", "In Progress", "In Review", "Done" },
  group_property = "status",
  title_property = "title",
  width = 24,
  padding = 2,
}

Board.commands = {
  board = {
    name = "board",
    args = 0,
    max_args = 1,
    callback = function(e)
      Board.open_board()
    end,
    commands = {
      group = {
        name = "board.group",
        args = 1,
        max_args = 1,
        callback = function(e)
          if e.fargs then
            Board.config.default_group = e.fargs[1]
            Board.open_board()
          end
        end,
      },
    },
  },
}

Board.maps = {
  { "n", "<leader>bb", "<CMD>Down board<CR>", "Open board view" },
}

Board.open_board = function()
  local ws = mod.get_mod("workspace")
  if not ws then
    vim.notify("[down.nvim] No workspace loaded", vim.log.levels.ERROR)
    return
  end

  local tasks = Board.collect_tasks()

  local groups = Board.build_groups(tasks)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns - 4, 120)
  local height = math.min(vim.o.lines - 6, 30)
  local win = vim.api.nvim_open_win(bufnr, true, {
    style = "minimal",
    border = "single",
    title = " Board View ",
    title_pos = "center",
    row = 2,
    col = math.max(2, (vim.o.columns - width) / 2),
    width = width,
    height = height,
    relative = "editor",
  })

  local lines = Board.render_board(groups, width)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].filetype = "board"
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.bo[bufnr].bufhidden = "wipe"

  local namespace = vim.api.nvim_create_namespace("down.board")
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_lines = { { " q: close   j/k: navigate   <CR>: select   c: cycle status", "Comment" } },
    virt_lines_above = false,
  })

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })

  Board.add_navigation_keys(bufnr, win, groups, tasks)
end

Board.collect_tasks = function()
  local ws = mod.get_mod("workspace")
  if not ws then
    return {}
  end

  local tasks = {}
  local ws_path = ws.get(ws.current())
  if not ws_path then
    return {}
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
      if type == "directory" then
        scan_dir(path)
      elseif name:match("%.md$") then
        local fm_data, pos = require("down.mod.data.props.frontmatter").parse(
          vim.fn.readfile(path), 1
        )
        if fm_data then
          local task = {
            file = path,
            title = fm_data.title or name:gsub("%.md$", ""),
            status = fm_data.status or "Todo",
            priority = fm_data.priority or "Medium",
            due_date = fm_data.due_date or "",
            tags = fm_data.tags or {},
            assignee = fm_data.assignee or "",
            description = fm_data.description or "",
            properties = fm_data,
          }
          table.insert(tasks, task)
        else
          local content = vim.fn.readfile(path)
          if #content > 0 then
            local title = content[1]:match("^#%s+(.+)") or name:gsub("%.md$", "")
            local status = "Todo"
            for _, line in ipairs(content) do
              if line:match("%- %[x%]") then
                status = "Done"
                break
              elseif line:match("%- %[ %]") then
                status = "Todo"
                break
              end
            end
            table.insert(tasks, {
              file = path,
              title = title,
              status = status,
              priority = "Medium",
              due_date = "",
              tags = {},
              assignee = "",
              description = "",
              properties = {},
            })
          end
        end
      end
    end
  end

  scan_dir(ws_path)
  return tasks
end

Board.build_groups = function(tasks)
  local group_prop = Board.config.group_property
  local groups = {}
  for _, group_name in ipairs(Board.config.default_groups) do
    groups[group_name] = {}
  end
  groups["No Status"] = {}

  for _, task in ipairs(tasks) do
    local status = task.status or "Todo"
    if not groups[status] then
      groups[status] = {}
    end
    table.insert(groups[status], task)
  end

  return groups
end

Board.render_board = function(groups, total_width)
  local lines = {}
  local group_names = Board.config.default_groups
  local displayed = {}
  for _, name in ipairs(group_names) do
    if groups[name] and #groups[name] > 0 then
      table.insert(displayed, name)
    end
  end
  for name, items in pairs(groups) do
    if not vim.tbl_contains(group_names, name) and #items > 0 then
      table.insert(displayed, name)
    end
  end

  local col_count = #displayed
  if col_count == 0 then
    return { "  No tasks found." }
  end

  local col_width = math.floor((total_width - col_count) / col_count) - 2

  local header_line = ""
  local sep_line = ""
  for _, gname in ipairs(displayed) do
    local display = " " .. gname .. " (" .. tostring(#(groups[gname] or {})) .. ") "
    header_line = header_line .. display .. string.rep(" ", col_width + 2 - #display)
    sep_line = sep_line .. string.rep("─", col_width + 2)
  end
  table.insert(lines, header_line)
  table.insert(lines, sep_line)

  local max_cards = 0
  for _, gname in ipairs(displayed) do
    max_cards = math.max(max_cards, #(groups[gname] or {}))
  end

  for row = 1, math.min(max_cards, 15) do
    local line = ""
    for _, gname in ipairs(displayed) do
      local items = groups[gname] or {}
      if items[row] then
        local item = items[row]
        local card = " ▸ " .. tostring(item.title)
        local status = string.format(" [%s]", tostring(item.priority):sub(1, 1))
        card = card .. status
        if #card > col_width then
          card = card:sub(1, col_width - 3) .. "..."
        end
        card = card .. string.rep(" ", col_width + 2 - #card)
        line = line .. card
      else
        line = line .. string.rep(" ", col_width + 2)
      end
    end
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "  Navigation: q=close  j/k=next/prev  <CR>=open  c=cycle status  h/l=prev/next group")

  return lines
end

Board.add_navigation_keys = function(bufnr, win, groups, tasks)
  local current_row = 3
  local current_col = 1

  vim.keymap.set("n", "j", function()
    current_row = current_row + 1
    vim.api.nvim_win_set_cursor(win, { current_row, 0 })
  end, { buffer = bufnr })

  vim.keymap.set("n", "k", function()
    current_row = math.max(3, current_row - 1)
    vim.api.nvim_win_set_cursor(win, { current_row, 0 })
  end, { buffer = bufnr })

  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_buf_get_lines(bufnr, current_row - 1, current_row, false)[1]
    if line then
      local task_title = line:match("▸%s+(.+)%s+%[")
      if task_title then
        for _, task in ipairs(tasks) do
          if task.title == task_title:gsub("%s+$", "") then
            vim.api.nvim_win_close(win, true)
            local bufnr = vim.fn.bufadd(task.file)
            if bufnr and bufnr > 0 then
              vim.api.nvim_set_current_buf(bufnr)
              vim.api.nvim_buf_call(bufnr, function()
                vim.cmd("edit " .. task.file)
              end)
            end
            return
          end
        end
      end
    end
  end, { buffer = bufnr })

  vim.keymap.set("n", "c", function()
    local line = vim.api.nvim_buf_get_lines(bufnr, current_row - 1, current_row, false)[1]
    if line then
      local task_title = line:match("▸%s+(.+)%s+%[")
      if task_title then
        task_title = task_title:gsub("%s+$", "")
        local statuses = Board.config.default_groups
        vim.ui.select(statuses, {
          prompt = "Move to status:",
        }, function(choice)
          if choice then
            for _, task in ipairs(tasks) do
              if task.title == task_title then
                require("down.mod.data.props.frontmatter").update_property(
                  vim.fn.bufadd(task.file), "status", choice
                )
                Board.open_board()
                return
              end
            end
          end
        end)
      end
    end
  end, { buffer = bufnr })
end

Board.setup = function()
  return {
    loaded = true,
  }
end

return Board
