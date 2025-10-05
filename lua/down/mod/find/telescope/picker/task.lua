local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

--- Parse tasks from buffer
---@param bufnr number
---@return table
local function parse_tasks(bufnr)
  local tasks = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
  local filepath = vim.api.nvim_buf_get_name(bufnr or 0)

  for lnum, line in ipairs(lines) do
    -- Parse markdown tasks: - [ ] or - [x]
    local status, task_text = line:match("^%s*[-*]%s*%[([%sx])%]%s*(.+)")
    if status and task_text then
      local is_done = status:lower() == "x"
      table.insert(tasks, {
        text = task_text,
        line = lnum,
        col = 1,
        done = is_done,
        status = is_done and "done" or "pending",
        file = filepath,
        full_line = line,
      })
    end
  end

  return tasks
end

--- Parse tasks from all workspace files
---@return table
local function parse_workspace_tasks()
  local mod = require("down.mod")
  local ws_mod = mod.get_mod("workspace")

  if not ws_mod then
    return {}
  end

  local ws_path = ws_mod.get_current_workspace_path()
  if not ws_path then
    return {}
  end

  local files = vim.fn.globpath(ws_path, "**/*.md", false, true)
  local all_tasks = {}

  for _, file in ipairs(files) do
    local bufnr = vim.fn.bufadd(file)
    vim.fn.bufload(bufnr)
    local tasks = parse_tasks(bufnr)

    for _, task in ipairs(tasks) do
      table.insert(all_tasks, task)
    end
  end

  return all_tasks
end

--- Task picker
---@param opts table
return function(opts)
  opts = opts or {}
  opts.scope = opts.scope or "workspace" -- buffer or workspace

  local tasks = {}

  if opts.scope == "buffer" then
    tasks = parse_tasks(0)
  elseif opts.scope == "workspace" then
    tasks = parse_workspace_tasks()
  end

  if #tasks == 0 then
    vim.notify("No tasks found", vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 8 },
      { width = 10 },
      { remaining = true },
    },
  })

  local make_display = function(entry)
    local filename = vim.fn.fnamemodify(entry.file, ":t")
    local status_icon = entry.done and "✓" or "○"
    return displayer({
      { status_icon .. " " .. entry.status, entry.done and "TelescopeResultsComment" or "TelescopeResultsIdentifier" },
      { entry.line .. ":" .. entry.col, "TelescopeResultsLineNr" },
      { filename .. " - " .. entry.text, "TelescopeResultsString" },
    })
  end

  pickers
    .new(opts, {
      prompt_title = "Tasks (" .. opts.scope .. ")",
      finder = finders.new_table({
        results = tasks,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.text,
            line = entry.line,
            col = entry.col,
            file = entry.file,
            text = entry.text,
            filename = entry.file,
            lnum = entry.line,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.vim_buffer_vimgrep.new(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd("edit " .. selection.file)
            vim.api.nvim_win_set_cursor(0, { selection.line, selection.col - 1 })
            vim.cmd("normal! zz")
          end
        end)
        return true
      end,
    })
    :find()
end
