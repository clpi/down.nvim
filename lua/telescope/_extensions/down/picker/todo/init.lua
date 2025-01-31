local modok, mod = pcall(require, "down.mod")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values -- allows us to use the values from the users config
local make_entry = require("telescope.make_entry")
local downld, down = pcall(require, 'down')

-- assert(downld, "down is not loaded - load it before telescope")

local function get_md_files()
  local ws = Mod.get_mod("workspace") ---@type mod.workspace
  if not ws then return nil end
  local cw = ws.get_current_workspace()
  local mdf = ws.get_down_files(cw[1])
  return {
    cw[2]:tostring(), vim.tbl_map(tostring, mdf)
  }
end

return function(opt)
  opt = opt or {}

  local f = get_md_files()
  if not (f and f[2]) then return end
  opt.entry_maker = make_entry.gen_from_file(opt)
  pickers.new(opt, {
    prompt_title = "Find down Files",
    previewer = conf.file_previewer(opt),
    sorter = conf.file_sorter(opt),
    cwd = f[1],
    finder = finders.new_table({
      results = f[2],
      entry_maker = make_entry.gen_from_file({ cwd = f[1] })
    })
  })
end
