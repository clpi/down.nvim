local actions = require("telescope.actions")
local astate = require("telescope.actions.state")
local finders = require("telescope.finders")
local pick = require("telescope.pickers")
local preview = require("telescope.previewers")
local conf = require("telescope.config").values

--- Find templates in workspace
---@param opts table
return function(opts)
  opts = opts or {}

  local mod = require("down.mod")
  local ws_mod = mod.get_mod("workspace")
  local template_mod = mod.get_mod("template")

  if not ws_mod then
    vim.notify("Workspace module not loaded", vim.log.levels.ERROR)
    return
  end

  local ws_path = ws_mod.get_current_workspace_path()
  if not ws_path then
    vim.notify("No active workspace", vim.log.levels.WARN)
    return
  end

  -- Find template directory (common locations)
  local template_dirs = {
    vim.fs.joinpath(ws_path, "templates"),
    vim.fs.joinpath(ws_path, "template"),
    vim.fs.joinpath(ws_path, ".templates"),
  }

  local templates = {}
  for _, dir in ipairs(template_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local files = vim.fn.globpath(dir, "*.md", false, true)
      for _, file in ipairs(files) do
        table.insert(templates, {
          path = file,
          name = vim.fn.fnamemodify(file, ":t:r"),
          display = vim.fn.fnamemodify(file, ":t"),
        })
      end
    end
  end

  if #templates == 0 then
    vim.notify("No templates found in workspace", vim.log.levels.INFO)
    return
  end

  pick
    .new(opts, {
      prompt_title = "Templates",
      finder = finders.new_table({
        results = templates,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.name,
            path = entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = preview.vim_buffer_cat.new(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = astate.get_selected_entry()
          if selection then
            vim.cmd("edit " .. selection.path)
          end
        end)
        return true
      end,
    })
    :find()
end
