local has_tel, tel = pcall(require, 'telescope')
local act = require('telescope.actions')
local set = require('telescope.actions.set')
local sta = require('telescope.actions.state')
local edi = require('telescope.pickers.entry_display')
local cfg = require('telescope.config')
local pic = require('telescope.pickers')
local srt = require('telescope.sorters')
local fnd = require('telescope.finders')
local pre = require('telescope.previewers')
local pre = require('telescope.from_entry')
local bui = require('telescope.builtin')
local win = require('telescope.pickers.window')
local has_down, down = pcall(require, 'down')

local M = {}

function M.setup_keys()
  local map = vim.api.nvim_set_keymap
  local opt = { noremap = true, silent = true }
  map('n', ',vv', "<cmd>lua require('telescope._extensions.down').custom_picker()<CR>", opt)
end

function M.custom_picker(opts)
  pic
    .new(opts or {}, {
      prompt_title = 'down finder',
      results_title = 'results',
      sorter = srt.get_generic_fuzzy_sorter(),
      finder = fnd.new_table {
        results = {
          'Index',
          'Notes',
        },
      },
      attach_mappings = function(prompt_bufnr, map)
        act.select_base:replace(function()
          local sel = act.get_selected_entry()
          act.close(prompt_bufnr)
          if sel.value == 'Index' then
            require('down.mod.note').index()
          elseif sel.value == 'Notes' then
            require('down.mod.note').notes()
          end
        end)
        return true
      end,
      previewer = pre.new_termopen_previewer({
        get_command = function(entry)
          return { 'echo', entry.value }
        end,
      }),
    })
    :find()
end

M.extension = {
  exports = {
    headings = require('telescope.builtin').live_grep,
    grep = require('telescope.builtin').live_grep,
    markdown = require('telescope.builtin').find_files,
    backlinks = require('telescope._extensions.down.picker.links.backlinks'),
    note = require('telescope._extensions.down.picker.note'),
    todo = require('telescope._extensions.down.picker.todo'),
    lsp = require('telescope._extensions.down.picker.lsp'),
    tags = require('telescope._extensions.down.picker.tags'),
    links = require('telescope._extensions.down.picker.links'),
    find_down = require('telescope._extensions.down.picker.files'),
    linkable = require('telescope._extensions.down.picker.links.linkable'),
    workspace = require('telescope._extensions.down.picker.workspace'),
  },
}

function M.register(exports)
  tel.register_extension(exports or M.extension)
end

function M.load()
  tel.load_extension('down')
end

-- return M
return M
-- setup = down.setup,
