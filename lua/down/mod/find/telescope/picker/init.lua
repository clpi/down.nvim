return {
  down = {
    grep = require("telescope.builtin").live_grep,
    header = require("down.mod.find.telescope.picker.header"),
    file = require("down.mod.find.telescope.picker.workspace.file"),
    markdown = require("down.mod.find.telescope.picker.workspace.markdown"),
    backlink = require("down.mod.find.telescope.picker.link.backlink"),
    note = require("down.mod.find.telescope.picker.note"),
    task = require("down.mod.find.telescope.picker.task"),
    agenda = require("down.mod.find.telescope.picker.task"),
    lsp = require("down.mod.find.telescope.picker.lsp"),
    tags = require("down.mod.find.telescope.picker.tag"),
    links = require("down.mod.find.telescope.picker.link"),
    linkable = require("down.mod.find.telescope.picker.link.linkable"),
    workspace = require("down.mod.find.telescope.picker.workspace"),
  },
}
