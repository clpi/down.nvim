--- Org-mode properties drawer support for down.nvim
--- Allows storing metadata like :PROPERTIES: ... :END: blocks
local mod = require("down.mod")
local log = require("down.log")

---@class down.mod.data.props.Props
local Props = mod.new("data.props")

--- Parse a properties drawer from a line
--- @param lines table<number, string>
--- @param start_line number
--- @return table<string, string> properties, number end_line
Props.parse = function(lines, start_line)
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

  return props, end_line
end

--- Get properties for current buffer at current line or below
--- @param bufnr? number
--- @return table<string, string>
Props.get = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local props, _ = Props.parse(lines, cursor[1])
  return props
end

--- Set a property value
--- @param key string
--- @param value string
Props.set = function(key, value)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local props, end_line = Props.parse(lines, cursor[1])

  props[key] = value
  Props.write(bufnr, props, cursor[1], end_line)
end

--- Write properties back to buffer
--- @param bufnr number
--- @param props table<string, string>
--- @param start_line number
--- @param end_line number
Props.write = function(bufnr, props, start_line, end_line)
  local prop_lines = { ":PROPERTIES:" }
  for k, v in pairs(props) do
    table.insert(prop_lines, string.format(":%s: %s", k, v))
  end
  table.insert(prop_lines, ":END:")

  if end_line > start_line then
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, prop_lines)
  else
    vim.api.nvim_buf_set_lines(bufnr, start_line, start_line, false, prop_lines)
  end
end

--- Org-mode style TODO cycling (like org-mode)
--- @param line string
--- @return string
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
    -- Not a TODO, add TODO
    return line:gsub("^(%s*)#(%s+)", "%1TODO%2", 1)
  end

  local new_line = line:gsub("^(%s*)" .. current_state, "%1" .. next_state, 1)
  return new_line
end

--- Toggle checkbox style - [ ] or [x]
--- @param line string
--- @return string
Props.toggle_checkbox = function(line)
  if line:match("%[ %]") then
    return line:gsub("%[ %]", "[x]", 1)
  elseif line:match("%[%x%]") then
    return line:gsub("%[%x%]", "[ ]", 1)
  end
  return line
end

--- Archive subtree to archive file (org-mode style)
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

  -- Find subtree root
  local indent_level = #lines[row]:match("^%s*")
  local subtree_lines = { lines[row] }
  row = row + 1

  while row <= #lines do
    local indent = #lines[row]:match("^%s*")
    if #lines[row] > 0 and indent <= indent_level then
      break
    end
    table.insert(subtree_lines, lines[row])
    row = row + 1
  end

  -- Delete subtree
  vim.api.nvim_buf_set_lines(0, cursor[1] - 1, row - 1, false, {})

  -- Append to archive
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

--- Insert current date and time (like org-mode <2024-01-01 Tue 10:00>)
Props.insert_timestamp = function()
  local ts = os.date("<%Y-%m-%d %a %H:%M>")
  vim.api.nvim_put({ ts .. " " }, "c", false, true)
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
    },
  },
}

--- Show current properties in a floating window
Props.show_current_props = function()
  local props = Props.get()
  if vim.tbl_isempty(props) then
    vim.notify("[down.nvim] No properties found")
    return
  end

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
end

Props.maps = {
  { "n", "<leader>tp", Props.toggle_checkbox, "Toggle checkbox" },
  { "n", "<leader>ta", Props.archive_subtree, "Archive subtree" },
  { "n", "<leader>tt", Props.cycle_todo, "Cycle TODO state" },
  { "n", "<leader>ts", Props.insert_timestamp, "Insert timestamp" },
}

function Props.setup()
  return {
    loaded = true,
    dependencies = { "cmd", "workspace" },
  }
end

Props.load = function() end

return Props