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
      log.trace("database")
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
    },
  },
}

Database.maps = {
  { "n", "<leader>dv", "<CMD>Down database view table<CR>", "View as table" },
  { "n", "<leader>db", "<CMD>Down database view board<CR>", "View as board" },
  { "n", "<leader>dc", "<CMD>Down database view calendar<CR>", "View as calendar" },
  { "n", "<leader>da", "<CMD>Down database add<CR>", "Add row to database" },
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
            local val = cols[j]
            if val then
              val = val:gsub("^%s+", ""):gsub("%s+$", "")
            end
            row[header] = val or ""
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

Database.show_view = function(view_type, group_by)
  local fm_data, schema, rows = Database.get_current_db_info()

  if not rows or #rows == 0 then
    vim.notify("[down.nvim] No table data found in current buffer", vim.log.levels.WARN)
    return
  end

  if view_type == "board" then
    Database.show_board_view(schema, rows, group_by or "status")
  elseif view_type == "calendar" then
    Database.show_calendar_view(schema, rows, group_by or "due_date")
  elseif view_type == "list" then
    Database.show_list_view(schema, rows, group_by)
  else
    Database.show_table_view(schema, rows)
  end
end

Database.show_with_filter = function(property, operator, value)
  local _, schema, rows = Database.get_current_db_info()
  if not rows then
    return
  end

  local filtered = Query.filter(rows, {
    property = property,
    operator = operator,
    value = value,
  })

  Database.show_table_view(schema, filtered)
end

Database.show_table_view = function(schema, rows)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(vim.o.columns, 120)
  local height = math.min(vim.o.lines - 4, #rows + 5)
  local win = vim.api.nvim_open_win(bufnr, true, {
    style = "minimal",
    border = "single",
    title = " Table View ",
    title_pos = "center",
    row = 2,
    col = math.max(0, (vim.o.columns - width) / 2),
    width = width,
    height = height,
    relative = "editor",
  })

  local display_lines = {}

  if not schema or vim.tbl_isempty(schema) then
    schema = {}
    for _, row in ipairs(rows) do
      for k in pairs(row) do
        if k ~= "_table_row" then
          schema[k] = { type = "text" }
        end
      end
    end
  end

  local columns = vim.tbl_keys(schema)
  table.sort(columns)

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

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_lines)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.bo[bufnr].bufhidden = "wipe"

  vim.keymap.set("n", "q", function()
    pcall(vim.api.nvim_win_close, win, true)
  end, { buffer = bufnr })
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
function Database.compute_rollup (row, field, all_rows)
  local relation_field = field.relation or field.rollup_relation
  local target_field = field.target or field.rollup_target
  local aggregate = field.aggregate or "count"

  if not relation_field or not target_field then return nil end

  local related_values = {}
  for _, r in ipairs (all_rows) do
    if r[relation_field] == row[relation_field] then
      local val = r[target_field]
      if val ~= nil then
        related_values[#related_values + 1] = val
      end
    end
  end

  if aggregate == "count" then
    return #related_values
  elseif aggregate == "count_unique" then
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
      if n then total = total + n end
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
  elseif aggregate == "join" or aggregate == "concat" then
    local t = {}
    for _, v in ipairs (related_values) do
      if v ~= nil and tostring (v) ~= "" then t[#t + 1] = tostring (v) end
    end
    return table.concat (t, ", ")
  elseif aggregate == "list" or aggregate == "array" then
    return related_values
  end

  return nil
end

--- Resolve all formula/rollup fields in a database
---@param db table
function Database.resolve_formulas (db)
  for _, row in ipairs (db.rows or {}) do
    for key, field in pairs (db.schema or {}) do
      if field.type == "formula" then
        row[key] = Database.compute_formula (row, field, db.rows)
      elseif field.type == "rollup" then
        row[key] = Database.compute_rollup (row, field, db.rows)
      end
    end
  end
end

return Database
