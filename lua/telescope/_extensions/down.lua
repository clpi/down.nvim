local has_tel, tel = pcall(require, "telescope")
local act = require("telescope.actions")
local bui = require("telescope.builtin")
local cfg = require("telescope.config")
local edi = require("telescope.pickers.entry_display")
local fnd = require("telescope.finders")
local pic = require("telescope.pickers")
local pre = require("telescope.previewers")
local pre = require("telescope.from_entry")
local set = require("telescope.actions.set")
local srt = require("telescope.sorters")
local sta = require("telescope.actions.state")
local win = require("telescope.pickers.window")
local has_down, down = pcall(require, "down")

local M = {}

function M.setup_keys()
  local map = vim.api.nvim_set_keymap
  local opt = { noremap = true, silent = true }
  map(
    "n",
    ",vv",
    "<cmd>lua require('down.mod.find.telescope').custom_picker()<CR>",
    opt
  )
end

function M.custom_picker(opts)
  pic
    .new(opts or {}, {
      prompt_title = "down finder",
      results_title = "results",
      sorter = srt.get_generic_fuzzy_sorter(),
      finder = fnd.new_table({
        results = {
          "Index",
          "Notes",
        },
      }),
      attach_mappings = function(prompt_bufnr, map)
        act.select_base:replace(function()
          local sel = act.get_selected_entry()
          act.close(prompt_bufnr)
          if sel.value == "Index" then
            require("down.mod.note").index()
          elseif sel.value == "Notes" then
            require("down.mod.note").notes()
          end
        end)
        return true
      end,
      previewer = pre.new_termopen_previewer({
        get_command = function(entry)
          return { "echo", entry.value }
        end,
      }),
    })
    :find()
end

M.extension = {
  exports = {
    headings = require("telescope.builtin").live_grep,
    grep = require("telescope.builtin").live_grep,
    markdown = require("telescope.builtin").find_files,
    backlinks = require("down.mod.find.telescope.picker.link.backlink"),
    note = require("down.mod.find.telescope.picker.note"),
    todo = require("down.mod.find.telescope.picker.todo"),
    lsp = require("down.mod.find.telescope.picker.lsp"),
    tags = require("down.mod.find.telescope.picker.tags"),
    links = require("down.mod.find.telescope.picker.link"),
    find_down = require("down.mod.find.telescope.picker.files"),
    linkable = require("down.mod.find.telescope.picker.link.linkable"),
    workspace = require("down.mod.find.telescope.picker.workspace"),
  },
}

function M.register(exports)
  tel.register_extension(exports or M.extension)
end

function M.load()
  tel.load_extension("down")
end

-- return M
return M
-- setup = down.setup,
