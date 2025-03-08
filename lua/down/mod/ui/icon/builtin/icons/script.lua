local super = {
  ["0"] = "⁰",
  ["1"] = "¹",
  ["2"] = "²",
  ["3"] = "³",
  ["4"] = "⁴",
  ["5"] = "⁵",
  ["6"] = "⁶",
  ["7"] = "⁷",
  ["8"] = "⁸",
  ["9"] = "⁹",
  ["-"] = "⁻",
}

local sub = {
  ["0"] = "₀",
  ["1"] = "₁",
  ["2"] = "₂",
  ["3"] = "₃",
  ["4"] = "₄",
  ["5"] = "₅",
  ["6"] = "₆",
  ["7"] = "₇",
  ["8"] = "₈",
  ["9"] = "₉",
  ["-"] = "₋",
}

local function superscript(s)
  return (s:gsub("%d", super))
end

local function subscript(s)
  return (s:gsub("%d", sub))
end

--- @type down.mod.ui.icon.Builtin.Icons
return {
  super = super,
  sub = sub,
  tosuper = superscript,
  tosub = subscript,
}
