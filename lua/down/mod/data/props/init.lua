local mod = require("down.mod")
local log = require("down.log")
local Frontmatter = require("down.mod.data.props.frontmatter")
local Types = require("down.mod.data.props.types")

---@class down.mod.data.props.Props
local Props = mod.new("data.props")
Props.dep = { "cmd", "workspace" }

Props.Frontmatter = Frontmatter
Props.Types = Types

Props.config = {
  format = "yaml",
  schema = {},
  defaults = {
    tags = {},
    status = "active",
    created = nil,
  },
}

Props.parse = function(lines, start_line)
  local data, pos = Frontmatter.parse(lines, start_line)
  if data then
    return data, pos and pos["end"]
  end

  local props = {}
  local in_props = false
  local end_line = start_line
  for i = start_line, #lines do
    local line = lines[i]
    if line:match("^:PROPERTIES:") then
      in_props = true
    elseif line:match("^:END:") then
      end_line = i
      break
    elseif in_props then
      local key, value = line:match("^%s*:%s*(%w+)%s*:%s*(.*)%s*$")
      if key and value then
        props[key] = value
      end
    end
  end
  if next(props) then
    return props, end_line
  end
  return {}, start_line
end

Props.get = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local data, _ = Frontmatter.parse(lines, 1)
  if data then
    return data
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local props, _ = Props.parse(lines, cursor[1])
  return props
end

Props.set = function(key, value)
  local bufnr = vim.api.nvim_get_current_buf()
  Frontmatter.update_property(bufnr, key, value)
end

Props.remove = function(key)
  local bufnr = vim.api.nvim_get_current_buf()
  Frontmatter.update_property(bufnr, key, nil)
end

Props.get_schema = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data, _ = Frontmatter.get_buffer_frontmatter(bufnr)
  if not data or not data.schema then
    return {}
  end
  return data.schema
end

Props.set_schema = function(bufnr, schema)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  Frontmatter.update_property(bufnr, "schema", schema)
end

Props.set_property_type = function(bufnr, key, kind, options)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local schema = Props.get_schema(bufnr)
  schema[key] = { type = kind }
  if options then
    if kind == "select" or kind == "multi_select" then
      schema[key].options = options
    elseif kind == "number" then
      if options.format then
        schema[key].format = options.format
      end
    elseif kind == "date" then
      if options.format then
        schema[key].format = options.format
      end
    end
  end
  Frontmatter.update_property(bufnr, "schema", schema)
end

Props.validate_value = function(value, kind, options)
  if not Types.validate[kind] then
    return true
  end
  if kind == "select" or kind == "multi_select" then
    return Types.validate[kind](value, options)
  end
  return Types.validate[kind](value)
end

Props.format_value = function(value, kind)
  if Types.format[kind] then
    return Types.format[kind](value)
  end
  return tostring(value or "")
end

Props.write = function(bufnr, props, start_line, end_line)
  Frontmatter.set_buffer_frontmatter(bufnr, props)
end

Props.cycle_todo = function(line)
  local todo_states = { "TODO", "IN_PROGRESS", "WAITING", "DONE", "CANCELLED" }
  local current_state
  for _, state in ipairs(todo_states) do
    if line:match("^%s*" .. state .. "%s") then
      current_state = state
      break
    end
  end
  local next_state
  if current_state == "TODO" then
    next_state = "IN_PROGRESS"
  elseif current_state == "IN_PROGRESS" then
    next_state = "WAITING"
  elseif current_state == "WAITING" then
    next_state = "DONE"
  elseif current_state == "DONE" or current_state == "CANCELLED" then
    next_state = "TODO"
  else
    return line:gsub("^(%s*)#(%s+)", "%1TODO%2", 1)
  end
  return line:gsub("^(%s*)" .. current_state, "%1" .. next_state, 1)
end

Props.toggle_checkbox = function(line)
  if line:match("%[ %]") then
    return line:gsub("%[ %]", "[x]", 1)
  elseif line:match("%[%x%]") then
    return line:gsub("%[%x%]", "[ ]", 1)
  end
  return line
end

Props.archive_subtree = function()
  local ws = mod.get_mod("workspace")
  if not ws then
    vim.notify("[down.nvim] No workspace module loaded", vim.log.levels.WARN)
    return
  end
  local current_ws = ws.current()
  local ws_path = ws.get(current_ws)
  if not ws_path then
    vim.notify("[down.nvim] No current workspace", vim.log.levels.WARN)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local indent_level = #(lines[row]:match("^%s*") or "")
  local subtree_lines = { lines[row] }
  row = row + 1
  while row <= #lines do
    local indent = #(lines[row]:match("^%s*") or "")
    if #lines[row] > 0 and indent <= indent_level then
      break
    end
    table.insert(subtree_lines, lines[row])
    row = row + 1
  end
  vim.api.nvim_buf_set_lines(0, cursor[1] - 1, row - 1, false, {})
  local archive_path = vim.fs.joinpath(ws_path, "archive.md")
  local archive_file = io.open(archive_path, "a")
  if archive_file then
    archive_file:write("\n" .. table.concat(subtree_lines, "\n") .. "\n")
    archive_file:close()
    vim.notify("Archived to " .. archive_path)
  else
    vim.notify("Failed to open archive file", vim.log.levels.ERROR)
  end
end

Props.insert_timestamp = function()
  local ts = os.date("<%Y-%m-%d %a %H:%M>")
  vim.api.nvim_put({ ts .. " " }, "c", false, true)
end

Props.insert_frontmatter = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local data, _ = Frontmatter.get_buffer_frontmatter(bufnr)
  if data then
    vim.notify("[down.nvim] Frontmatter already exists")
    return
  end
  local defaults = {
    title = vim.fn.expand("%:t:r"),
    date = os.date("%Y-%m-%d"),
    tags = {},
  }
  Frontmatter.set_buffer_frontmatter(bufnr, defaults)
  vim.notify("[down.nvim] Added frontmatter")
end

Props.show_current_props = function()
  local data, _ = Frontmatter.get_buffer_frontmatter()
  if data and not vim.tbl_isempty(data) then
    local items = {}
    for k, v in pairs(data) do
      if k ~= "schema" then
        local formatted = type(v) == "table" and table.concat(v, ", ") or tostring(v)
        table.insert(items, string.format("  %s: %s", k, formatted))
      end
    end
    if #items > 0 then
      table.insert(items, 1, "--- Frontmatter ---")
      vim.ui.select(items, {
        prompt = "Properties",
      }, function(choice)
        if choice then
          vim.fn.setreg("+", choice:match("^%s*(.-):%s*(.*)$") or choice)
        end
      end)
      return
    end
  end
  local props = Props.get()
  if not vim.tbl_isempty(props) then
    local lines = { "PROPERTIES:" }
    for k, v in pairs(props) do
      table.insert(lines, string.format("  %s: %s", k, v))
    end
    vim.ui.select(lines, {
      prompt = "Properties",
    }, function(choice)
      if choice then
        vim.fn.setreg("+", choice)
      end
    end)
    return
  end
  vim.notify("[down.nvim] No properties found")
end

Props.commands = {
  props = {
    name = "props",
    args = 0,
    max_args = 1,
    callback = function()
      Props.show_current_props()
    end,
    commands = {
      set = {
        name = "props.set",
        args = 2,
        callback = function(e)
          if e.fargs and #e.fargs >= 2 then
            Props.set(e.fargs[1], e.fargs[2])
          end
        end,
      },
      delete = {
        name = "props.delete",
        args = 1,
        callback = function(e)
          if e.fargs and #e.fargs >= 1 then
            Props.remove(e.fargs[1])
          end
        end,
      },
      type = {
        name = "props.type",
        args = 2,
        max_args = 4,
        callback = function(e)
          if e.fargs and #e.fargs >= 2 then
            local key = e.fargs[1]
            local kind = e.fargs[2]
            local options = nil
            if e.fargs[3] then
              options = { options = vim.split(e.fargs[3], ",") }
            end
            Props.set_property_type(nil, key, kind, options)
          end
        end,
      },
      archive = {
        name = "props.archive",
        args = 0,
        callback = Props.archive_subtree,
      },
      timestamp = {
        name = "props.timestamp",
        args = 0,
        callback = Props.insert_timestamp,
      },
      frontmatter = {
        name = "props.frontmatter",
        args = 0,
        callback = Props.insert_frontmatter,
      },
    },
  },
}

Props.maps = {
  { "n", "<leader>tp", Props.toggle_checkbox, "Toggle checkbox" },
  { "n", "<leader>ta", Props.archive_subtree, "Archive subtree" },
  { "n", "<leader>tt", Props.cycle_todo, "Cycle TODO state" },
  { "n", "<leader>ts", Props.insert_timestamp, "Insert timestamp" },
  { "n", "<leader>tf", Props.insert_frontmatter, "Insert frontmatter" },
}

function Props.setup()
  return {
    loaded = true,
  }
end

return Props
