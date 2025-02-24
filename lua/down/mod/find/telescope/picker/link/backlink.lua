local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")
local telescope = require("telescope")

local function get_backlinks_to_file(file_path)
  function find_backlinks(notes, target_note)
    local backlinks = {}
    for note, content in pairs(notes) do
      if content:find(target_note) then
        table.insert(backlinks, note)
      end
    end
    return backlinks
  end

  local backlinks = {}
  -- Assuming a function `find_backlinks` that returns a list of files linking to `file_path`
  backlinks = find_backlinks(file_path)
  return backlinks
end

local function find_backlinks(file_path)
  -- This function should be implemented to search through the workspace
  -- and return a list of files that contain links to `file_path`.
  -- For now, it returns a dummy list for demonstration purposes.
  return {
    "file1.md",
    "file2.md",
    "file3.md",
  }
end

local function backlinks_picker(opts)
  opts = opts or {}
  local file_path = vim.fn.expand("%:p") -- Get the current file path
  local backlinks = get_backlinks_to_file(file_path)

  pickers
    .new(opts, {
      prompt_title = "Backlinks to " .. file_path,
      finder = finders.new_table({
        results = backlinks,
      }),
      sorter = sorters.get_generic_fuzzy_sorter(),
      previewer = previewers.vim_buffer_cat.new(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd("edit " .. selection[1])
          end
        end)
        return true
      end,
    })
    :find()
end

-- To use the picker, you can call `backlinks_picker()` in your Neovim command line
-- or map it to a keybinding in your Neovim configuration.
