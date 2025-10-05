local actions = require("telescope.actions")
local astate = require("telescope.actions.state")
local builtin = require("telescope.builtin")
local finders = require("telescope.finders")
local pick = require("telescope.pickers")
local preview = require("telescope.previewers")
local sorters = require("telescope.sorters")
local conf = require("telescope.config").values

--- Find files across all workspaces
---@param opts table
return function(opts)
  opts = opts or {}

  local mod = require("down.mod")
  local ws_mod = mod.get_mod("workspace")

  if not ws_mod then
    vim.notify("Workspace module not loaded", vim.log.levels.ERROR)
    return
  end

  local workspaces = ws_mod.get_workspaces()
  if not workspaces or vim.tbl_isempty(workspaces) then
    vim.notify("No workspaces configured", vim.log.levels.WARN)
    return
  end

  -- Collect all workspace paths
  local search_dirs = {}
  for name, path in pairs(workspaces) do
    if vim.fn.isdirectory(path) == 1 then
      table.insert(search_dirs, path)
    end
  end

  if #search_dirs == 0 then
    vim.notify("No valid workspace directories found", vim.log.levels.WARN)
    return
  end

  -- Use telescope's find_files with multiple search_dirs
  opts.search_dirs = search_dirs
  opts.prompt_title = "Down Files (All Workspaces)"
  opts.hidden = opts.hidden or false
  opts.file_ignore_patterns = opts.file_ignore_patterns or { "node_modules", ".git" }

  builtin.find_files(opts)
end
