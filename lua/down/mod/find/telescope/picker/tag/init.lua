local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")
local telescope = require("telescope")

local function tag_picker()
  local opts = {}
  pickers
    .new(opts, {
      prompt_title = "Markdown Tags",
      finder = finders.new_oneshot_job(
        { "rg", "--no-heading", "--vimgrep", "#tag", vim.fn.getcwd() },
        opts
      ),
      previewer = previewers.vim_buffer_cat.new(opts),
      sorter = sorters.get_fuzzy_file(),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.filename)
          vim.fn.cursor(selection.lnum, selection.col)
        end)
        return true
      end,
    })
    :find()
end

-- To use the picker, you can call the function
-- tag_picker()
