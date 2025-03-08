---
--- @class down.Pos
local Pos = {

  x = 0,
  z = 0,
  y = 0,
}

---@param self down.Pos
---@param p down.Pos
---@return boolean
Pos.le = function(self, p)
  return self.x < p.x or (self.x == p.x and self.y <= p.y)
end

---@param self down.Pos
---@param p down.Pos
---@return boolean
Pos.ge = function(self, p)
  return self.x > p.x or (self.x == p.x and self.y >= p.y)
end

Pos.add = function(self, p)
  return { x = self.x + p.x, y = self.y + p.y }
end

Pos.sub = function(self, p)
  return { x = self.x - p.x, y = self.y - p.y }
end

---@param self down.Pos
---@param p down.Pos
---@return boolean
Pos.eq = function(self, p)
  return (self.x == p.x) and (self.y == p.y)
end

---@param self down.Pos
---@param p down.Pos
---@return boolean
Pos.lt = function(self, p)
  return self.x < p.x or (self.x == p.x and self.y < p.y)
end

---@param self down.Pos
---@param p down.Pos
---@return boolean
Pos.gt = function(self, p)
  return self.x > p.x or (self.x == p.x and self.y > p.y)
end

Pos.check = {
  ---@param xy down.Pos
  ---@param x_new number
  ---@param y_new number
  min = function(xy, x_new, y_new)
    if (x_new < xy.x) or (x_new == xy.x and y_new < xy.y) then
      xy.x = x_new
      xy.y = y_new
    end
  end,

  ---@param xy down.Pos
  ---@param x_new number
  ---@param y_new number
  max = function(xy, x_new, y_new)
    if (x_new > xy.x) or (x_new == xy.x and y_new > xy.y) then
      xy.x = x_new
      xy.y = y_new
    end
  end,
}

Pos = setmetatable(Pos, {
  __eq = Pos.eq,
  __lt = Pos.lt,
  __gt = Pos.gt,
  __add = Pos.add,
  __sub = Pos.sub,
  __le = Pos.le,
  __ge = Pos.ge,
})

return Pos
