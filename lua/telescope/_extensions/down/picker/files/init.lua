local finders = require("telescope.finders")
local mod = require("down.mod")
local pickers = require("telescope.pickers")
local ws = require("down.mod.workspace")
local conf = require("telescope.config").values -- allows us to use the values from the users config
local make_entry = require("telescope.make_entry")
local downld, down = pcall(require, "down")

return function(opt)
  opt = opt or {}

  local f = ws.markdown(ws.current())
  opt.entry_maker = make_entry.gen_from_file(opt)
  pickers
    .new(opt, {
      prompt_title = "Find down Files",
      previewer = conf.file_previewer(opt),
      sorter = conf.file_sorter(opt),
      cwd = ws.get(ws.current()),
      finder = finders.new_table({
        results = f,
        entry_maker = make_entry.gen_from_file({ cwd = ws.get(ws.current()) }),
      }),
    })
    :find()
end
