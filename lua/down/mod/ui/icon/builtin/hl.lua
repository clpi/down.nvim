--- @type down.mod.ui.icon.Provider.Hl
local highlights = {
  [1] = {
    fg = "fg",
    bg = "bg",
    icon = "icon",
    default = "default",
  },
  [2] = {
    fg = "fg",
    bg = "bg",
    icon = "icon",
    default = "default",
  },
}

--- @type down.mod.ui.icon.Provider.Hl
local hl = {
  file = "File",
  type = "Typedef",
  directory = "Directory",
  struct = "Struct",
  class = "Class",
  default = "Text",
  identifier = "Identifier",
  definition = "Definition",
  color = "Color",
  variable = "Variable",
  method = "Method",
}

return hl
