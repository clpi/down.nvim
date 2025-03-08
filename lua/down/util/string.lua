--- @version JIT
--- @type stringlib

string = require("string")
string.buffer = require("string.buffer")

local tbl = {
  clear = require("table.clear"),
  new = require("table.new"),
}

string.encode = string.buffer.encode

string.decode = string.buffer.decode

string.buf = string.buffer.new

--- Check if a string is a wikilink, if so, return the link destination.
--- @param self string
--- @return string|nil
function string.iswikilink(self)
  if self:startswith("[[") and self:endswith("]]") then
    return self:sub(3, -3)
  end
  return nil
end

--- @param self string
--- @param start string
--- @return boolean
function string.startswith(self, start)
  return self:sub(1, #start) == start
end

--- Split self at `sep` and return the fields
--- @param self string
--- @param sep? string
--- @return tablelib<integer, string>
function string.splitsep(self, sep)
  local f = {}
  local p = ("([%s]+)"):format(sep or ".")
  self:gsub(p, function(c)
    f[#f + 1] = c
  end)
  return f
end

--- @param self string
--- @param ending string
--- @return boolean
function string.endswith(self, ending)
  return self:sub(-#ending) == ending
end

--- Split self at `at`th occurrence of `patt`
--- @param self string
--- @param patt string: The pattern to split on
--- @return tablelib<integer, string>
function string.split(self, patt)
  local a, b = string.find(self, patt or "%.")
  if a == nil or b == nil then
    return { [1] = self }
  end
  return {
    [1] = string.sub(self, 0, a or #self - 1),
    [2] = string.sub(self, b + 1),
  }
end

--- Returns true if string is 'true', or false if string is 'false'
--- Returns nil if string is neither
--- @param self string
--- @return boolean|nil
function string.isbool(self)
  if self ~= nil and self ~= "" then
    if self == "true" then
      return true
    elseif self == "false" then
      return false
    end
  end
  return nil
end

--- @param n number
function string.numtolower(n)
  local t = {} ---@type tablelib<integer, string>
  while n > 0 do
    t[#t + 1] = string.char(0x61 + (n - 1) % 26)
    n = math.floor((n - 1) / 26)
  end
  return table.concat(t):reverse()
end

string.link = {
  --- Check if a string is a wikilink, if so, return the link destination.
  --- @param self string
  --- @return string?
  iswiki = function(self)
    if self:startswith("[[") and self:endswith("]]") then
      return self:sub(3, -3)
    end
  end,
  --- Check if a string is a markdown link, if so, return the link destination.
  --- @param self string
  --- @return string?
  islink = function(self)
    if self:startswith("[") and self:endswith("]") then
      return self:sub(2, -2)
    end
  end,
}

return string
