local hl = require("down.mod.ui.icon.builtin.hl")
local icons = require("down.mod.ui.icon.builtin.icons")
local tbl = require("down.util.table")

--- The builtin icon provider
--- @class (exact) down.mod.ui.icon.Builtin
return {

  --- The icons
  --- @type down.mod.ui.icon.Provider.Icons
  icons = icons,

  --- The highlights
  --- @type down.mod.ui.icon.Provider.Hl
  hl = hl,

  --- The name of the provider
  --- @type down.mod.ui.icon.Provider.Name
  name = "down",

  --- The available categories
  --- @type down.mod.ui.icon.Provider.Category[]
  categories = vim.tbl_keys(icons),

  --- The available highlights
  --- @type down.mod.ui.icon.Provider.Highlight.Name[]|down.mod.ui.icon.Provider.Highlight.Info[]
  highlights = vim.tbl_values(hl),

  --- The available icon types
  --- @type down.mod.ui.icon.Provider.Type[]
  types = vim.tbl_keys(hl),

  --- The list of icons for a category
  --- @param category down.mod.ui.icon.Provider.Category?
  --- @return string[]
  list = function(category)
    return icons[category or "file"]
  end,

  --- The icon for a category and name
  --- @param category down.mod.ui.icon.Provider.Category
  --- @param name string
  --- @return string|down.mod.ui.icon.Builtin.Icon, down.mod.ui.icon.Provider.Highlight.Name, boolean
  get = function(category, name)
    return icons[category or "file"][name or "default"],
      hl[name or "default"],
      true
  end,

  --- Set the provider to use `down`
  set_provider = function() end,

  setup = function() end,
}
