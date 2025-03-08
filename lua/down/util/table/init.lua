--- @class down.table: table, tablelib
---
--- @alias down.tbl down.table|tablelib|table
---
local tbl = vim.deepcopy(table)

--- Extend a table in place
--- @param self down.tbl
--- @param other down.tbl
tbl.extendinplace = function(self, other)
  for k, v in pairs(other) do
    self[k] = v
  end
end

--- Clear a table
tbl.clear = require("table.clear")

tbl.new = require("table.new")

--- Check if a table is empty
tbl.isempty = function(self)
  return next(self) == nil
end

--- Reverse a table
--- @param self table
--- @return table
tbl.reverse = function(self)
  local r = {}
  for i = 1, #self do
    r[i] = self[#self - i + 1]
  end
  return r
end

--- Get the last element of a table
--- @param self table
--- @param key any
--- @return any
tbl.orempty = function(self, key)
  if not self[key] then
    self[key] = {}
  end
  return self[key]
end
--- Get the last element of a table, or the element at a given index.
--- @param self table
--- @param index number
--- @return any
tbl.orlast = function(self, index)
  return self[index] or self[#self]
end

return tbl
