local U = {}

---@class down.mod.Mods: { [down.Mod.Id]?: down.Mod.Config }}
U.defaults = {
  mod = {},
  cmd = {},
  link = {},
  find = {},
}

---@type down.Mod.Id[]
U.ids = {
  "log",
  "data",
  "find",
  "find.telescope",
  "find.fzflua",
  "find.mini",
  "find.builtin",
  "find.snacks",
  "workspace",
  "edit",
  "tag",
  "task",
  "log",
  "keymap",
  "ui",
  "ui.calendar",
  "template",
  "note",
  "ui.calendar.week",
  "ui.calendar.month",
  "cmd",
  "link",
  "integration.telescope",
  "data.history",
  "integration",
}

---@return boolean
U.check_id = function(mod_id)
  return vim.tbl_contains(U.ids, mod_id)
    and not (mod_id == "workspace" or mod_id == "workspaces")
end

---@return boolean
U.check_default_id = function(mod_id)
  return vim.tbl_contains(vim.tbl_keys(U.defaults), mod_id)
end

---@return { [down.Mod.Id]?: down.Mod.Config }
U.merge_default = function(def)
  return vim.tbl_extend("force", U.defaults, def)
end

---@return boolean
U.check_not_default = function(def, defv)
  return U.check_id(def)
    and not U.check_default_id(def)
    and defv
    and type(defv) == "table"
end

return U
