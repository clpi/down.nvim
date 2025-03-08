local str = require("down.util.string")

local memoized_ordered_icon_generator = {}
local mt = require("down.util.table.mt")
local tbl = require("down.util.table.table")

--- Roman numerals
local roman = {
  { "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix" },
  { "x", "xx", "xxx", "xl", "l", "lx", "lxx", "lxxx", "xc" },
  { "c", "cc", "ccc", "cd", "d", "dc", "dcc", "dccc", "cm" },
  { "m", "mm", "mmm" },
}
--- @param n number
roman.tolower = function(n)
  if n >= 4000 then
    -- too large to render
    return
  end

  local result = {}
  local i = 1
  while n > 0 do
    result[#result + 1] = roman[i][n % 10]
    n = math.floor(n / 10)
    i = i + 1
  end
  return tbl.concat(tbl.reverse(result))
end

local ord = {
  ["0"] = function(i)
    return tostring(i - 1)
  end,
  ["1"] = function(i)
    return tostring(i)
  end,
  ["a"] = function(i)
    return str.numtolower(i)
  end,
  ["A"] = function(i)
    return str.numtolower(i):upper()
  end,
  ["i"] = function(i)
    return roman.tolower(i)
  end,
  ["I"] = function(i)
    return roman.tolower(i):upper()
  end,
  ["Ⅰ"] = {
    "Ⅰ",
    "Ⅱ",
    "Ⅲ",
    "Ⅳ",
    "Ⅴ",
    "Ⅵ",
    "Ⅶ",
    "Ⅷ",
    "Ⅸ",
    "Ⅹ",
    "Ⅺ",
    "Ⅻ",
  },
  ["ⅰ"] = {
    "ⅰ",
    "ⅱ",
    "ⅲ",
    "ⅳ",
    "ⅴ",
    "ⅵ",
    "ⅶ",
    "ⅷ",
    "ⅸ",
    "ⅹ",
    "ⅺ",
    "ⅻ",
  },
  ["⒈"] = {
    "⒈",
    "⒉",
    "⒊",
    "⒋",
    "⒌",
    "⒍",
    "⒎",
    "⒏",
    "⒐",
    "⒑",
    "⒒",
    "⒓",
    "⒔",
    "⒕",
    "⒖",
    "⒗",
    "⒘",
    "⒙",
    "⒚",
    "⒛",
  },
  ["⑴"] = {
    "⑴",
    "⑵",
    "⑶",
    "⑷",
    "⑸",
    "⑹",
    "⑺",
    "⑻",
    "⑼",
    "⑽",
    "⑾",
    "⑿",
    "⒀",
    "⒁",
    "⒂",
    "⒃",
    "⒄",
    "⒅",
    "⒆",
    "⒇",
  },
  ["①"] = {
    "①",
    "②",
    "③",
    "④",
    "⑤",
    "⑥",
    "⑦",
    "⑧",
    "⑨",
    "⑩",
    "⑪",
    "⑫",
    "⑬",
    "⑭",
    "⑮",
    "⑯",
    "⑰",
    "⑱",
    "⑲",
    "⑳",
  },
  ["⒜"] = {
    "⒜",
    "⒝",
    "⒞",
    "⒟",
    "⒠",
    "⒡",
    "⒢",
    "⒣",
    "⒤",
    "⒥",
    "⒦",
    "⒧",
    "⒨",
    "⒩",
    "⒪",
    "⒫",
    "⒬",
    "⒭",
    "⒮",
    "⒯",
    "⒰",
    "⒱",
    "⒲",
    "⒳",
    "⒴",
    "⒵",
  },
  ["Ⓐ"] = {
    "Ⓐ",
    "Ⓑ",
    "Ⓒ",
    "Ⓓ",
    "Ⓔ",
    "Ⓕ",
    "Ⓖ",
    "Ⓗ",
    "Ⓘ",
    "Ⓙ",
    "Ⓚ",
    "Ⓛ",
    "Ⓜ",
    "Ⓝ",
    "Ⓞ",
    "Ⓟ",
    "Ⓠ",
    "Ⓡ",
    "Ⓢ",
    "Ⓣ",
    "Ⓤ",
    "Ⓥ",
    "Ⓦ",
    "Ⓧ",
    "Ⓨ",
    "Ⓩ",
  },
  ["ⓐ"] = {
    "ⓐ",
    "ⓑ",
    "ⓒ",
    "ⓓ",
    "ⓔ",
    "ⓕ",
    "ⓖ",
    "ⓗ",
    "ⓘ",
    "ⓙ",
    "ⓚ",
    "ⓛ",
    "ⓜ",
    "ⓝ",
    "ⓞ",
    "ⓟ",
    "ⓠ",
    "ⓡ",
    "ⓢ",
    "ⓣ",
    "ⓤ",
    "ⓥ",
    "ⓦ",
    "ⓧ",
    "ⓨ",
    "ⓩ",
  },
}
return {
  ord = ord,
  fmt = function(pattern, index)
    if type(pattern) == "function" then
      return pattern(index)
    end

    local gen = memoized_ordered_icon_generator[pattern]
    if gen then
      return gen(index)
    end

    for char_one, number_table in pairs(ord) do
      local l, r = pattern:find(
        char_one:find("%w") and "%f[%w]" .. char_one .. "%f[%W]" or char_one
      )
      if l then
        gen = function(index_)
          local icon = type(number_table) == "function" and number_table(index_)
            or number_table[index_]
          return icon and pattern:sub(1, l - 1) .. icon .. pattern:sub(r + 1)
        end
        break
      end
    end

    gen = gen or function(_) end

    memoized_ordered_icon_generator[pattern] = gen
    return gen(index)
  end,
}
