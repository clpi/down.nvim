local Path = require("plenary.path")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")

local function open_note_in_workspace()
  local workspace_path = vim.fn.expand("~/workspace/notes") -- Adjust the path to your notes directory

  pickers
    .new({}, {
      prompt_title = "Notes in Workspace",
      finder = finders.new_oneshot_job(
        { "find", workspace_path, "-type", "f" },
        {
          entry_maker = function(entry)
            return {
              value = entry,
              display = Path:new(entry):make_relative(workspace_path),
              ordinal = entry,
            }
          end,
        }
      ),
      sorter = sorters.get_fuzzy_file(),
      previewer = previewers.vim_buffer_cat.new({}),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.value)
        end)
        return true
      end,
    })
    :find()
end

return require("telescope").register_extension({
  exports = {
    notes = open_note_in_workspace,
  },
})
