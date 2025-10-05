local pickers = {
  -- Files in current workspace (default for :Down find)
  file = require("down.mod.find.telescope.picker.workspace_files"),
  files = require("down.mod.find.telescope.picker.workspace_files"),

  -- Workspace pickers
  workspace = require("down.mod.find.telescope.picker.workspace"),

  -- All files from all workspaces
  all_files = require("down.mod.find.telescope.picker.files"),

  -- Link pickers
  link = require("down.mod.find.telescope.picker.link"),
  links = require("down.mod.find.telescope.picker.link"),
  backlink = require("down.mod.find.telescope.picker.link.backlink"),
  linkable = require("down.mod.find.telescope.picker.link.linkable"),

  -- Tag pickers
  tag = require("down.mod.find.telescope.picker.tag"),
  tags = require("down.mod.find.telescope.picker.tag"),

  -- Note pickers
  note = require("down.mod.find.telescope.picker.note"),

  -- Task pickers
  task = require("down.mod.find.telescope.picker.task"),
  todo = require("down.mod.find.telescope.picker.task"),
  agenda = require("down.mod.find.telescope.picker.task"),

  -- Template pickers
  template = require("down.mod.find.telescope.picker.template"),

  -- Other pickers
  header = require("down.mod.find.telescope.picker.header"),
  markdown = require("down.mod.find.telescope.picker.workspace.markdown"),
  grep = require("telescope.builtin").live_grep,
}

-- Default "down" command shows current workspace files
pickers.down = pickers.file

return {
  down = pickers,
}
