local builtin = require("telescope.builtin")

--- Find files in current workspace
---@param opts table
return function(opts)
  opts = opts or {}

  local mod = require("down.mod")
  local ws_mod = mod.get_mod("workspace")

  if not ws_mod then
    vim.notify("Workspace module not loaded", vim.log.levels.ERROR)
    return
  end

  local ws_path = ws_mod.get_current_workspace_path()
  if not ws_path then
    vim.notify("No active workspace", vim.log.levels.WARN)
    return
  end

  -- Use telescope's find_files for current workspace
  opts.cwd = ws_path
  opts.prompt_title = "Files in Workspace"
  opts.hidden = opts.hidden or false
  opts.file_ignore_patterns = opts.file_ignore_patterns or { "node_modules", ".git" }

  builtin.find_files(opts)
end
