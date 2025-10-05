local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")
local conf = require("telescope.config").values

--- Make path relative to base
---@param path string
---@param base string
---@return string
local function make_relative(path, base)
  if vim.startswith(path, base) then
    return path:sub(#base + 2) -- +2 to skip the trailing slash
  end
  return path
end

--- Find daily notes / journal entries
---@param opts table
return function(opts)
  opts = opts or {}

  local mod = require("down.mod")
  local ws_mod = mod.get_mod("workspace")
  local note_mod = mod.get_mod("note")

  if not ws_mod then
    vim.notify("Workspace module not loaded", vim.log.levels.ERROR)
    return
  end

  local ws_path = ws_mod.get_current_workspace_path()
  if not ws_path then
    vim.notify("No active workspace", vim.log.levels.WARN)
    return
  end

  -- Get note folder (default is "journal")
  local note_folder = note_mod and note_mod.config and note_mod.config.folder or "journal"
  local notes_path = vim.fs.joinpath(ws_path, note_folder)

  if vim.fn.isdirectory(notes_path) == 0 then
    vim.notify("Notes directory not found: " .. notes_path, vim.log.levels.WARN)
    return
  end

  local notes = vim.fn.globpath(notes_path, "**/*.md", false, true)

  if #notes == 0 then
    vim.notify("No notes found in " .. notes_path, vim.log.levels.INFO)
    return
  end

  pickers
    .new(opts, {
      prompt_title = "Daily Notes",
      finder = finders.new_table({
        results = notes,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_relative(entry, notes_path),
            ordinal = make_relative(entry, notes_path),
            path = entry,
          }
        end,
      }),
      sorter = conf.file_sorter(opts),
      previewer = previewers.vim_buffer_cat.new(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd("edit " .. selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end
