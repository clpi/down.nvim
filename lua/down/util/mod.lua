local M = {}

---@class down.mod.Mods: { [down.Mod.Id]?: down.Mod.Config }}
M.defaults = {
  lsp = {},
  mod = {},
  task = {},
  cmd = {},
  link = {},
  ['tool.telescope'] = {},
}

---@type down.Mod.Id[]
M.ids = {
  "log",
  "data",
  "workspace",
  "edit",
  "code",
  "ui",
  "export",
  "ui.calendar",
  "template",
  "note",
}

---@return boolean
M.check_id = function(mod_id)
  return vim.tbl_contains(M.ids, mod_id)
end

---@return boolean
M.check_default_id = function(mod_id)
  return vim.tbl_contains(vim.tbl_keys(M.defaults), mod_id)
end

---@return { [down.Mod.Id]?: down.Mod.Config }
M.merge_default = function(def)
  return vim.tbl_extend('force', M.defaults, def)
end

---@return boolean
M.check_not_default = function(def, defv)
  return M.check_id(def)
      and not M.check_default_id(def)
      and defv and type(defv) == 'table'
end

return M
