local mod = require("down.mod")
local log = require("down.log")
local Frontmatter = require("down.mod.data.props.frontmatter")
local Schema = require("down.mod.data.database.schema")
local Query = require("down.mod.data.database.query")

local Database = mod.new("data.database")
Database.dep = { "cmd", "workspace", "data", "data.props" }

Database.Schema = Schema
Database.Query = Query

Database.config = {
  store = {
    root = "data/database",
  },
}

Database.Database = {
  uri = "",
  name = "",
  schema = {},
  rows = {},
  source = "",
}

Database.databases = {}

Database.commands = {
  database = {
    name = "database",
    args = 0,
    max_args = 1,
    callback = function(e)
      if e.fargs and e.fargs[1] then
        vim.cmd("Down database " .. table.concat(e.fargs, " "))
      else
        Database.list_databases()
      end
    end,
    commands = {
      view = {
        name = "database.view",
        args = 0,
        max_args = 2,
        callback = function(e)
          local view_type = e.fargs and e.fargs[1] or "table"
          Database.show_view(view_type, e.fargs and e.fargs[2])
        end,
      },
      create = {
        name = "database.create",
        args = 1,
        max_args = 2,
        callback = function(e)
          local name = e.fargs and e.fargs[1] or "Database"
          local schema_type = e.fargs and e.fargs[2] or "table"
          Database.create_database(name, schema_type)
        end,
      },
      add = {
        name = "database.add",
        args = 0,
        max_args = 1,
        callback = function(e)
          Database.add_row()
        end,
      },
      filter = {
        name = "database.filter",
        args = 1,
        max_args = 3,
        callback = function(e)
          if e.fargs then
            local property = e.fargs[1]
            local operator = e.fargs[2] or "eq"
            local value = e.fargs[3] or ""
            Database.show_with_filter(property, operator, value)
          end
        end,
      },
      list = {
        name = "database.list",
        args = 0,
        max_args = 1,
        callback = function()
          Database.list_databases()
        end,
      },
      open = {
        name = "database.open",
        args = 0,
        max_args = 1,
        callback = function(e)
          Database.open_database(e.fargs and e.fargs[1])
        end,
      },
    },
  },
}

Database.maps = {
  { "n", "<leader>dv", "<CMD>Down database view table<CR>", "View as table" },
  { "n", "<leader>db", "<CMD>Down database view board<CR>", "View as board" },
  { "n", "<leader>dc", "<CMD>Down database view calendar<CR>", "View as calendar" },
  { "n", "<leader>da", "<CMD>Down database add<CR>", "Add row to database" },
  { "n", "<leader>fd", "<CMD>Down find database<CR>", "Pick database" },
}

Database.parse_markdown_table = function(lines, start_line)
  local rows = {}
  local headers = nil
  local alignments = nil
  local in_table = false

  for i = start_line or 1, #lines do
    local line = lines[i]

    if not in_table then
      local cols = Database.parse_table_row(line)
      if cols and #cols > 0 then
        headers = cols
        in_table = true
      end
    else
      if line:match("^|?%s*:?%-%-%-+:?%s*|") then
        alignments = Database.parse_alignments(line)
      else
        local cols = Database.parse_table_row(line)
        if cols and #cols > 0 and headers then
          local row = {}
          for j, header in ipairs(headers) do
            local clean_header = header:gsub("^%s+", ""):gsub("%s+$", "")
            local val = cols[j]
            if val then
              val = val:gsub("^%s+", ""):gsub("%s+$", "")
            end
            row[clean_header] = val or ""
          end
          row._table_row = i
          table.insert(rows, row)
        else
          break
        end
      end
    end
  end

  return rows, headers, alignments
end

Database.parse_table_row = function(line)
  if not line:match("^%s*|") then
    return nil
  end
  local cols = {}
  for col in line:gmatch("|([^|]*)") do
    table.insert(cols, col)
  end
  if #cols > 0 then
    return cols
  end
  return nil
end

Database.parse_alignments = function(line)
  local alignments = {}
  for col in line:gmatch("|([^|]*)") do
    local trimmed = col:gsub("%s+", "")
    local left = trimmed:match("^:") ~= nil
    local right = trimmed:match(":$") ~= nil
    if left and right then
      table.insert(alignments, "center")
    elseif right then
      table.insert(alignments, "right")
    else
      table.insert(alignments, "left")
    end
  end
  return alignments
end

Database.get_current_db_info = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local fm_data, pos = Frontmatter.parse(lines, 1)

  if not fm_data then
    return nil, nil, nil
  end

  local schema = fm_data.database or fm_data.schema or nil
  if not schema then
    return fm_data, nil, nil
  end

  if type(schema) == "table" and schema.columns then
    schema = Schema.normalize(schema.columns)
  elseif type(schema) == "table" then
    schema = Schema.normalize(schema)
  end

  local table_start = pos and (pos["end"] + 1) or 1
  local rows, headers = Database.parse_markdown_table(lines, table_start)

  return fm_data, schema, rows
end

Database.create_database = function(name, schema_type)
  local ws = mod.get_mod("workspace")
  if not ws then
    vim.notify("[down.nvim] No workspace loaded", vim.log.levels.ERROR)
    return
  end

  local ws_path = ws.get(ws.current())
  local file_path = vim.fs.joinpath(ws_path, name:gsub("%s+", "_") .. ".md")

  if schema_type == "directory" then
    vim.fn.mkdir(file_path:gsub("%.md$", ""), "p")
    file_path = vim.fs.joinpath(file_path:gsub("%.md$", ""), "database.md")
  end

  local bufnr = vim.fn.bufadd(file_path)
  if bufnr == 0 then
    bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, file_path)
  end

  local default_schema = {
    title = { type = "title" },
    status = { type = "select", options = { "Backlog", "Todo", "In Progress", "Done" } },
    priority = { type = "select", options = { "Low", "Medium", "High", "Urgent" } },
    due_date = { type = "date" },
    tags = { type = "multi_select", options = {} },
    description = { type = "text" },
  }

  local frontmatter_lines = {
    "---",
    "title: " .. name,
    "type: database",
    "database:",
  }
  for key, def in pairs(default_schema) do
    table.insert(frontmatter_lines, "  " .. key .. ":")
    table.insert(frontmatter_lines, "    type: " .. def.type)
    if def.options and #def.options > 0 then
      table.insert(frontmatter_lines, "    options:")
      for _, opt in ipairs(def.options) do
        table.insert(frontmatter_lines, "      - " .. opt)
      end
    end
  end
  table.insert(frontmatter_lines, "---")
  table.insert(frontmatter_lines, "")
  table.insert(frontmatter_lines, "| title | status | priority | due_date | tags | description |")
  table.insert(frontmatter_lines, "|-------|--------|----------|----------|------|-------------|")
  table.insert(frontmatter_lines, "| " .. name .. " | Todo | Medium | " .. os.date("%Y-%m-%d") .. " | | |")

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, frontmatter_lines)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("write")
  end)
  vim.notify("[down.nvim] Created database: " .. file_path)
end

Database.add_row = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local _, schema = Database.get_current_db_info(bufnr)

  if not schema then
    vim.notify("[down.nvim] No database schema found in current buffer", vim.log.levels.WARN)
    return
  end

  local new_row = {}
  for key, def in pairs(schema) do
    new_row[key] = Schema.default_value(def)
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local headers = nil
  local last_table_line = nil

  for i = 1, #lines do
    local line = lines[i]
    if not headers then
      local cols = Database.parse_table_row(line)
      if cols and #cols > 0 then
        headers = cols
      end
    else
      if line:match("^|?%s*:?%-%-%-+:?%s*|") then
      else
        local cols = Database.parse_table_row(line)
        if cols then
          last_table_line = i
        else
          break
        end
      end
    end
  end

  if not headers or not last_table_line then
    vim.notify("[down.nvim] No table found in buffer", vim.log.levels.WARN)
    return
  end

  local col_values = {}
  for _, h in ipairs(headers) do
    local clean_h = h:gsub("^%s+", ""):gsub("%s+$", "")
    local val = new_row[clean_h]
    if val == nil then
      val = ""
    elseif type(val) == "table" then
      val = table.concat(val, ", ")
    elseif type(val) == "boolean" then
      val = val and "Yes" or "No"
    end
    table.insert(col_values, " " .. tostring(val) .. " ")
  end

  local row_line = "|" .. table.concat(col_values, "|") .. "|"
  vim.api.nvim_buf_set_lines(bufnr, last_table_line, last_table_line, false, { row_line })

  local cursor_row = last_table_line + 1
  local cursor_col = row_line:find("| ") + 1
  if cursor_col then
    vim.api.nvim_win_set_cursor(0, { cursor_row, cursor_col - 1 })
  end
end

--- Update a single table cell in a database buffer.
---@param bufnr number
---@param row_line number 1-based line number in buffer
---@param column string column name
---@param value string new cell value
---@return boolean
Database.update_cell = function(bufnr, row_line, column, value)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not row_line or not column then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line = lines[row_line]
  if not line then
    return false
  end

  local headers = nil
  for i = 1, #lines do
    local cols = Database.parse_table_row(lines[i])
    if cols and #cols > 0 and not lines[i]:match("^|?%s*:?%-%-%-+:?%s*|") then
      headers = cols
      break
    end
  end
  if not headers then
    return false
  end

  column = column:gsub("^%s+", ""):gsub("%s+$", "")
  local col_idx = nil
  for i, h in ipairs(headers) do
    local clean = h:gsub("^%s+", ""):gsub("%s+$", "")
    if clean:lower() == column:lower() then
      col_idx = i
      break
    end
  end
  if not col_idx then
    return false
  end

  local cells = Database.parse_table_row(line)
  if not cells then
    return false
  end
  while #cells < #headers do
    cells[#cells + 1] = ""
  end
  cells[col_idx] = " " .. tostring(value) .. " "

  local new_line = "|" .. table.concat(cells, "|") .. "|"
  vim.api.nvim_buf_set_lines(bufnr, row_line - 1, row_line, false, { new_line })
  return true
end

Database.show_view = function(view_type, group_by)
  local bufnr = vim.api.nvim_get_current_buf()
  local fm_data, schema, rows = Database.get_current_db_info(bufnr)

  if not rows or #rows == 0 then
    vim.notify("[down.nvim] No table data found in current buffer", vim.log.levels.WARN)
    return
  end

  Database.resolve_formulas({ schema = schema, rows = rows, root = (function()
    local ws = mod.get_mod("workspace")
    return ws and ws.get(ws.current()) or vim.loop.cwd()
  end)() })

  local ws = mod.get_mod("workspace")
  local root = ws and ws.get(ws.current()) or vim.loop.cwd()
  local ctx = {
    source_bufnr = bufnr,
    source_path = vim.api.nvim_buf_get_name(bufnr),
    root = root,
  }
  if view_type == "board" then
    Database.show_board_view(schema, rows, group_by or "status", ctx)
  elseif view_type == "calendar" then
    Database.show_calendar_view(schema, rows, group_by or "due_date", ctx)
  elseif view_type == "list" then
    Database.show_list_view(schema, rows, group_by, ctx)
  else
    Database.show_table_view(schema, rows, ctx)
  end
end

Database.show_with_filter = function(property, operator, value)
  local bufnr = vim.api.nvim_get_current_buf()
  local _, schema, rows = Database.get_current_db_info(bufnr)
  if not rows then
    return
  end

  local ws = mod.get_mod("workspace")
  local root = ws and ws.get(ws.current()) or vim.loop.cwd()
  Database.resolve_formulas({ schema = schema, rows = rows, root = root })

  local filtered = Query.filter(rows, {
    property = property,
    operator = operator,
    value = value,
  })

  Database.show_table_view(schema, filtered, {
    source_bufnr = bufnr,
    source_path = vim.api.nvim_buf_get_name(bufnr),
    root = root,
  })
end

Database.show_table_view = function(schema, rows, ctx)
  ctx = ctx or {}
  local source_bufnr = ctx.source_bufnr or vim.api.nvim_get_current_buf()
  local columns = vim.tbl_keys(schema or {})
  table.sort(columns)
  if #columns == 0 then
    schema = {}
    for _, row in ipairs(rows) do
      for k in pairs(row) do
        if k ~= "_table_row" then
          schema[k] = { type = "text" }
          columns[#columns + 1] = k
        end
      end
    end
    table.sort(columns)
  end

  local function render_lines()
    local display_lines = {}
    local col_widths = {}
    for _, col in ipairs(columns) do
      col_widths[col] = #col + 2
    end
    for _, row in ipairs(rows) do
      for _, col in ipairs(columns) do
        local val = tostring(row[col] or "")
        col_widths[col] = math.max(col_widths[col], #val + 2)
      end
    end
    local function pad(val, w)
      val = tostring(val)
      return val .. string.rep(" ", w - #val)
    end
    local header_parts = {}
    for _, col in ipairs(columns) do
      table.insert(header_parts, " " .. pad(col, col_widths[col] - 1))
    end
    table.insert(display_lines, "|" .. table.concat(header_parts, "|") .. "|")
    local sep_parts = {}
    for _, col in ipairs(columns) do
      table.insert(sep_parts, "|" .. string.rep("-", col_widths[col]))
    end
    table.insert(display_lines, table.concat(sep_parts, "") .. "|")
    for _, row in ipairs(rows) do
      local row_parts = {}
      for _, col in ipairs(columns) do
        local val = tostring(row[col] or "")
        table.insert(row_parts, " " .. pad(val, col_widths[col] - 1))
      end
      table.insert(display_lines, "|" .. table.concat(row_parts, "|") .. "|")
    end
    return display_lines
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 120)
  local height = math.min(vim.o.lines - 4, #rows + 8)
  local win = vim.api.nvim_open_win(bufnr, true, {
    style = "minimal",
    border = "single",
    title = " Table View (e edit, q close) ",
    title_pos = "center",
    row = 2,
    col = math.max(0, (vim.o.columns - width) / 2),
    width = width,
    height = height,
    relative = "editor",
  })

  local function refresh()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, render_lines())
  end
  refresh()
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.bo[bufnr].bufhidden = "wipe"

  local function cell_at_cursor()
    local row_idx = vim.api.nvim_win_get_cursor(win)[1]
    local col_idx = vim.api.nvim_win_get_cursor(win)[2]
    if row_idx <= 2 then
      return nil
    end
    local data_row = row_idx - 2
    if data_row < 1 or data_row > #rows then
      return nil
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, row_idx - 1, row_idx, false)[1] or ""
    local col_no = 1
    local current = 1
    for i, col in ipairs(columns) do
      local start = line:find("|", current, true)
      if not start then break end
      local finish = line:find("|", start + 1, true)
      if not finish then break end
      if col_idx >= start and col_idx <= finish then
        return rows[data_row], col, data_row
      end
      current = finish + 1
      col_no = i + 1
    end
    local col = columns[math.min(col_no, #columns)]
    return rows[data_row], col, data_row
  end

  local function edit_cell()
    local row, col, idx = cell_at_cursor()
    if not row or not col then
      return
    end
    local fd = (schema or {})[col] or {}
    if fd.type == "formula" or fd.type == "rollup" then
      vim.notify("[down.nvim] Computed columns are read-only", vim.log.levels.WARN)
      return
    end
    local current = tostring(row[col] or "")
    vim.ui.input({ prompt = col .. ": ", default = current }, function(val)
      if val == nil then return end
      Database.update_cell(source_bufnr, row._table_row, col, val)
      row[col] = val
      Database.resolve_formulas({ schema = schema, rows = rows, root = ctx.root })
      refresh()
    end)
  end

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })
  vim.keymap.set("n", "e", edit_cell, { buffer = bufnr })
  vim.keymap.set("n", "<CR>", edit_cell, { buffer = bufnr })
end

Database.show_board_view = function(schema, rows, group_by)
  group_by = group_by or "status"
  local groups = Query.group(rows, group_by)

  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 120)
  local max_rows = 0
  for _, items in pairs(groups) do
    max_rows = math.max(max_rows, #items)
  end
  local height = math.min(vim.o.lines - 4, max_rows + 10)
  local win = vim.api.nvim_open_win(bufnr, true, {
    style = "minimal",
    border = "single",
    title = " Board View (" .. group_by .. ") ",
    title_pos = "center",
    row = 2,
    col = math.max(0, (vim.o.columns - width) / 2),
    width = width,
    height = height,
    relative = "editor",
  })

  local display_lines = {}
  local group_names = vim.tbl_keys(groups)
  table.sort(group_names)

  local col_width = math.floor((width - #group_names) / #group_names)

  local header_line = ""
  for _, gname in ipairs(group_names) do
    local display_name = tostring(gname)
    local padded = display_name .. string.rep(" ", col_width - #display_name)
    header_line = header_line .. padded .. " "
  end
  if #header_line > 0 then
    table.insert(display_lines, header_line)
    table.insert(display_lines, string.rep("─", width))
  end

  local display_rows = {}
  for gidx, gname in ipairs(group_names) do
    local items = groups[gname] or {}
    for ridx, item in ipairs(items) do
      display_rows[ridx] = display_rows[ridx] or {}
      local title = tostring(item.title or item._table_row or "")
      if #title > col_width - 2 then
        title = title:sub(1, col_width - 5) .. "..."
      end
      local entry = "▸ " .. title .. string.rep(" ", col_width - #title - 3)
      display_rows[ridx][gidx] = entry
    end
  end

  for _, row_data in ipairs(display_rows) do
    local line = ""
    for gidx, gname in ipairs(group_names) do
      local entry = row_data[gidx] or string.rep(" ", col_width)
      line = line .. entry .. " "
    end
    table.insert(display_lines, line)
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.bo[bufnr].bufhidden = "wipe"

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })
end

Database.show_calendar_view = function(schema, rows, date_field)
  date_field = date_field or "due_date"

  local date_rows = {}
  for _, row in ipairs(rows) do
    local date_val = row[date_field]
    if date_val and date_val:match("^%d%d%d%d%-%d%d%-%d%d") then
      local year, month, day = date_val:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
      local key = string.format("%s-%s-%s", year, month, day)
      date_rows[key] = date_rows[key] or {}
      table.insert(date_rows[key], row)
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 100)
  local height = math.min(vim.o.lines - 4, #date_rows + 5)
  local win = vim.api.nvim_open_win(bufnr, true, {
    style = "minimal",
    border = "single",
    title = " Calendar View (" .. date_field .. ") ",
    title_pos = "center",
    row = 2,
    col = math.max(0, (vim.o.columns - width) / 2),
    width = width,
    height = height,
    relative = "editor",
  })

  local display_lines = {}
  local sorted_dates = vim.tbl_keys(date_rows)
  table.sort(sorted_dates)

  for _, date_key in ipairs(sorted_dates) do
    local items = date_rows[date_key]
    table.insert(display_lines, "## " .. date_key)
    for _, item in ipairs(items) do
      local title = tostring(item.title or item._table_row or "Untitled")
      local status = item.status or ""
      local line = "  - " .. title
      if status ~= "" then
        line = line .. " [" .. status .. "]"
      end
      table.insert(display_lines, line)
    end
    table.insert(display_lines, "")
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.bo[bufnr].bufhidden = "wipe"

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })
end

Database.show_list_view = function(schema, rows, group_by)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 100)
  local height = math.min(vim.o.lines - 4, #rows + 8)
  local win = vim.api.nvim_open_win(bufnr, true, {
    style = "minimal",
    border = "single",
    title = " List View ",
    title_pos = "center",
    row = 2,
    col = math.max(0, (vim.o.columns - width) / 2),
    width = width,
    height = height,
    relative = "editor",
  })

  local display_lines = {}
  local sorted = Query.sort(rows, { { property = "title", direction = "ascending" } })

  if group_by then
    local groups = Query.group(sorted, group_by)
    local group_names = vim.tbl_keys(groups)
    table.sort(group_names)
    for _, gname in ipairs(group_names) do
      table.insert(display_lines, "## " .. tostring(gname))
      for _, item in ipairs(groups[gname]) do
        local title = tostring(item.title or "Untitled")
        local status = item.status or ""
        local line = "  - " .. title
        if status ~= "" then
          line = line .. " [" .. status .. "]"
        end
        table.insert(display_lines, line)
      end
      table.insert(display_lines, "")
    end
  else
    for _, item in ipairs(sorted) do
      local title = tostring(item.title or "Untitled")
      table.insert(display_lines, "- " .. title)
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.bo[bufnr].bufhidden = "wipe"

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })
end

Database.setup = function()
  return {
    loaded = true,
  }
end

--- Compute formula fields for a row
---@param row table
---@param field table
---@param all_rows table
---@return any
function Database.compute_formula (row, field, all_rows)
  local expr = field.formula or field.expression or ""
  if expr == "" then return nil end

  -- Simple formula evaluation
  -- Supported: field references {field_name}, basic math
  local result = expr

  -- Replace {field_name} with values
  for k, v in pairs (row) do
    local val = tostring (v or "")
    result = result:gsub ("{" .. k .. "}", val)
  end

  -- Basic math evaluation
  if result:match ("^[%d%s%+%-%*/%.()]+$") then
    local ok, val = pcall (load ("return " .. result))
    if ok then return val end
  end

  -- Length formula
  if result:match ("^length%((.+%)%)$") then
    local field = result:match ("length%((.+)%)$")
    if field and row[field] then
      return #tostring (row[field])
    end
  end

  -- If/else formula: if(cond, then, else)
  if result:match ("^if%(.+%)$") then
    local inner = result:match ("^if%((.+)%)$")
    local parts = {}
    local depth, start = 0, 1
    for i = 1, #inner do
      local c = inner:sub (i, i)
      if c == "(" then depth = depth + 1
      elseif c == ")" then depth = depth - 1
      elseif c == "," and depth == 0 then
        parts[#parts + 1] = inner:sub (start, i - 1):gsub ("^%s+", ""):gsub ("%s+$", "")
        start = i + 1
      end
    end
    parts[#parts + 1] = inner:sub (start):gsub ("^%s+", ""):gsub ("%s+$", "")

    if #parts >= 2 then
      local cond = parts[1]:gsub ("^%s+", ""):gsub ("%s+$", "")
      local cond_val = false
      -- Check if condition matches a field value
      for k, v in pairs (row) do
        if cond == k then cond_val = v ~= nil and v ~= false and v ~= "" end
        if cond == "not " .. k then cond_val = not (v ~= nil and v ~= false and v ~= "") end
        if cond == k .. " == true" then cond_val = v == true end
        if cond == k .. " == false" then cond_val = v == false end
      end
      -- Try boolean evaluation
      if cond == "true" then cond_val = true
      elseif cond == "false" then cond_val = false end

      return cond_val and parts[2] or (parts[3] or "")
    end
  end

  return result
end

--- Compute rollup: aggregate values from related rows
---@param row table
---@param field table
---@param all_rows table
---@return any
function Database.compute_rollup (row, field, all_rows, ctx)
  local relation_field = field.relation or field.rollup_relation
  local target_field = field.target or field.rollup_target
  local aggregate = field.aggregate or "count"

  if not relation_field or not target_field then return nil end

  local related_values = {}
  local schema = (ctx and ctx.schema) or {}
  local relation_def = schema[relation_field] or {}
  local target_db_name = relation_def.database or relation_def.target_database

  if target_db_name and ctx and ctx.databases then
    local target_db = nil
    for _, db in ipairs(ctx.databases) do
      if db.title and db.title:lower() == target_db_name:lower() then
        target_db = db
        break
      end
      if db.rel and db.rel:lower():find(target_db_name:lower(), 1, true) then
        target_db = db
        break
      end
    end
    if target_db and target_db.path and vim.fn.filereadable(target_db.path) == 1 then
      local lines = vim.fn.readfile(target_db.path)
      local _, _, target_rows = Database.parse_markdown_table(lines, 1)
      local linked = {}
      for token in tostring(row[relation_field] or ""):gmatch("[^,]+") do
        local part = token:gsub("^%s+", ""):gsub("%s+$", "")
        if part ~= "" then linked[#linked + 1] = part:lower() end
      end
      for _, r in ipairs(target_rows or {}) do
        local title = tostring(r.title or r.name or ""):lower()
        for _, link in ipairs(linked) do
          if title == link then
            local val = r[target_field]
            if val ~= nil then related_values[#related_values + 1] = val end
            break
          end
        end
      end
    end
  else
    for _, r in ipairs (all_rows) do
      if r[relation_field] == row[relation_field] then
        local val = r[target_field]
        if val ~= nil then
          related_values[#related_values + 1] = val
        end
      end
    end
  end

  if aggregate == "count" then
    return #related_values
  elseif aggregate == "count_unique" or aggregate == "unique" then
    local seen = {}
    for _, v in ipairs (related_values) do seen[tostring (v)] = true end
    local count = 0
    for _ in pairs (seen) do count = count + 1 end
    return count
  elseif aggregate == "sum" then
    local total = 0
    for _, v in ipairs (related_values) do
      local n = tonumber (v)
      if n then total = total + n end
    end
    return total
  elseif aggregate == "average" or aggregate == "avg" then
    local total, count = 0, 0
    for _, v in ipairs (related_values) do
      local n = tonumber (v)
      if n then total = total + n; count = count + 1 end
    end
    return count > 0 and (total / count) or 0
  elseif aggregate == "min" then
    local min_val = nil
    for _, v in ipairs (related_values) do
      if min_val == nil or v < min_val then min_val = v end
    end
    return min_val
  elseif aggregate == "max" then
    local max_val = nil
    for _, v in ipairs (related_values) do
      if max_val == nil or v > max_val then max_val = v end
    end
    return max_val
  elseif aggregate == "join" or aggregate == "concat" or aggregate == "list" then
    local parts = {}
    for _, v in ipairs (related_values) do
      if v ~= nil and tostring (v) ~= "" then parts[#parts + 1] = tostring (v) end
    end
    return table.concat (parts, ", ")
  end

  return nil
end

local function down_bin_path()
  local paths = {}
  for _, path in ipairs(vim.api.nvim_get_runtime_file("scripts/bin/down", true)) do
    paths[#paths + 1] = path
  end
  paths[#paths + 1] = vim.fn.stdpath("data") .. "/down/bin/down"
  paths[#paths + 1] = "down"
  for _, path in ipairs(paths) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
  return "down"
end

Database.scan_workspace = function(root)
  local ws = mod.get_mod("workspace")
  root = root or (ws and ws.get(ws.current())) or vim.loop.cwd()
  local out, err = vim.system({ down_bin_path(), "database", "list", "--json" }, { cwd = root, text = true }):wait()
  local items = {}
  if out and out.code == 0 and out.stdout and out.stdout ~= "" then
    local ok, decoded = pcall(vim.json.decode, out.stdout)
    if ok and type(decoded) == "table" then
      for _, entry in ipairs(decoded) do
        local rel = entry.rel or ""
        local db_path = entry.path
        if not db_path or db_path == "" then
          db_path = rel ~= "" and vim.fs.joinpath(root, rel) or ""
        end
        items[#items + 1] = {
          title = entry.title or "",
          rows = entry.rows or 0,
          columns = entry.columns or 0,
          path = db_path,
          rel = rel,
        }
      end
    else
      for line in out.stdout:gmatch("[^\n]+") do
        local title, rows, rel = line:match("^(.-)%s+(%d+)%s+rows%s+(.+)$")
        if title and rel then
          items[#items + 1] = {
            title = title:match("%s*(.-)%s*$"),
            rows = tonumber(rows) or 0,
            path = vim.fs.joinpath(root, rel),
            rel = rel,
          }
        end
      end
    end
  end
  Database.databases = items
  return items, err
end


Database.picker = function(opts)
  local ok, find = pcall(require, "down.mod.find")
  if ok and find and find.picker then
    local picker = find.picker("database")
    if type(picker) == "function" then
      picker(opts or {})
      return true
    end
  end
  return false
end

Database.open_database = function(target)
  local ws = mod.get_mod("workspace")
  local root = ws and ws.get(ws.current()) or vim.loop.cwd()
  local path = target
  if not path or path == "" then
    if Database.picker({ prompt = "Open database" }) then
      return
    end
    local items = Database.scan_workspace(root)
    if #items == 0 then
      vim.notify("[down.nvim] No databases found in workspace", vim.log.levels.WARN)
      return
    end
    if #items == 1 then
      path = items[1].path
    else
      vim.ui.select(items, {
        prompt = "Open database",
        format_item = function(item)
          return string.format("%s (%d rows) — %s", item.title, item.rows, item.rel)
        end,
      }, function(choice)
        if choice then
          vim.cmd("edit " .. vim.fn.fnameescape(choice.path))
        end
      end)
      return
    end
  end
  if not path:match("%.md$") then
    local out = vim.system({ down_bin_path(), "database", "show", path }, { cwd = root, text = true }):wait()
    if out and out.stdout then
      local rel = out.stdout:match("%(([^)]+)%)")
      if rel then
        path = vim.fs.joinpath(root, rel)
      end
    end
  end
  if vim.fn.filereadable(path) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  else
    vim.notify("[down.nvim] Database not found: " .. tostring(path), vim.log.levels.ERROR)
  end
end

Database.list_databases = function()
  if Database.picker({ prompt = "Databases" }) then
    return
  end
  local lsp = mod.get_mod("lsp")
  if lsp and lsp.get_client and lsp.get_client() and lsp.list_databases then
    lsp.list_databases()
    return
  end
  local ws = mod.get_mod("workspace")
  local root = ws and ws.get(ws.current()) or vim.loop.cwd()
  local items = Database.scan_workspace(root)
  if #items == 0 then
    vim.notify("[down.nvim] No databases in workspace", vim.log.levels.INFO)
    return
  end
  local lines = { "# Databases", "" }
  for _, item in ipairs(items) do
    lines[#lines + 1] = string.format("- **%s** — %d rows (`%s`)", item.title, item.rows, item.rel)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.min(80, vim.o.columns - 4),
    height = math.min(#lines + 2, vim.o.lines - 4),
    row = 2,
    col = 2,
    style = "minimal",
    border = "rounded",
    title = " Databases ",
  })
end

--- Resolve all formula/rollup fields in a database
---@param db table
function Database.resolve_formulas (db)
  local root = db.root
  if root then
    db.databases = Database.scan_workspace(root)
  end
  for _, row in ipairs (db.rows or {}) do
    for key, field in pairs (db.schema or {}) do
      if field.type == "formula" then
        row[key] = Database.compute_formula (row, field, db.rows)
      elseif field.type == "rollup" then
        row[key] = Database.compute_rollup (row, field, db.rows, db)
      end
    end
  end
end

return Database
