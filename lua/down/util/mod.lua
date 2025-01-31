local M = {}

---@class down.mod.Mods: { [down.Mod.Id]?: down.Mod.Config }}
M.defaults = {
  mod = {},
  cmd = {},
  link = {},
  ["tool.telescope"] = {},
}

---@type down.Mod.Id[]
M.ids = {
  "log",
  "data",
  "workspace",
  "edit",
  "code",
  "lsp",
  "tag",
  "task",
  "log",
  "keymap",
  "ui",
  "export",
  "ui.calendar",
  "template",
  "note",
  "ui.calendar.week",
  "ui",
  "ui.calendar.month",
  "note",
  "cmd",
  "link",
  "tool.telescope",
  "data.history",
  "tool",
  "mod",
}

---@return boolean
M.check_id = function(mod_id)
  return vim.tbl_contains(M.ids, mod_id)
    and not (mod_id == "workspace" or mod_id == "workspaces")
end

---@return boolean
M.check_default_id = function(mod_id)
  return vim.tbl_contains(vim.tbl_keys(M.defaults), mod_id)
end

---@return { [down.Mod.Id]?: down.Mod.Config }
M.merge_default = function(def)
  return vim.tbl_extend("force", M.defaults, def)
end

---@return boolean
M.check_not_default = function(def, defv)
  return M.check_id(def)
    and not M.check_default_id(def)
    and defv
    and type(defv) == "table"
end

return M
