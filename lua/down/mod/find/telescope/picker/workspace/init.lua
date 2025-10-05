local ws = require("down.mod.workspace")

local actions = require("telescope.actions")
local astate = require("telescope.actions.state")
local autil = require("telescope.actions.utils")
local entry = require("telescope.from_entry")
local finders = require("telescope.finders")
local gen = require("telescope.actions.generate")
local hist = require("telescope.actions.history")
local mt = require("telescope.actions.mt")
local pick = require("telescope.pickers")
local preview = require("telescope.previewers")
local set = require("telescope.actions.set")
local sorters = require("telescope.sorters")
local ws = require("down.mod.workspace")

---@param o table
return function(o)
  pick
    .new(o or {}, {
      prompt_title = "Down workspaces",
      prompt_prefix = " ",
      results_title = "Workspaces",
      sorter = sorters.get_generic_fuzzy_sorter({}),
      finder = finders.new_table({
        results = ws.as_lsp_workspaces(),
      }),
      previewer = preview.vim_buffer_vimgrep.new({}),
      result_display = function(entry)
        return entry.value
      end,
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = astate.get_selected_entry()
          ws.open(selection.value)
        end)
        return true
      end,
      theme = "dropdown",
      layout_config = {
        width = 0.5,
        height = 0.4,
      },
    })
    :find()
end
