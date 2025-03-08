local builtin = require("down.mod.ui.icon.builtin")

---@class down.mod.ui.icon.Util
local U = {}

---Get the icons provider
---@param choice? down.mod.ui.icon.Provider.Name The choice of provider (default: "mini.icons")
---@return down.mod.ui.icon.Provider.Result provider and provider name
U.provider = function(choice)
  local hasm, m = pcall(require, "mini.icons")
  local hasw, w = pcall(require, "nvim-web-devicons")
  if hasm and choice == "mini.icons" then
    m.mock_nvim_web_devicons()
  end
  return {
    icons = hasm and m or hasw and w or require("down.mod.ui.icon.builtin"),
    provider = choice
      or (hasm and "mini.icons" or hasw and "nvim-web-devicons")
      or "down",
  }
end

---Get the icons provider
---@param c down.mod.ui.icon.Provider.Name? The choice of provider (default: "mini.icons")
---@return table? The provider
U.icons = function(c)
  return U.provider(c).icons
end

---List the icon categories
---@param category? down.mod.ui.icon.Provider.Category The category of the icons
---@param provider? down.mod.ui.icon.Provider.Name The choice of provider (default: "mini.icons")
---@return down.mod.ui.icon.Provider.Category[] categories The categories of the icons
U.list = function(category, provider)
  return U.get_provider(provider or "down").list(category or "file") ---@diagnostic disable-line
end

---List the file icons
---@param dir? string The directory of the file
---@param provider? down.mod.ui.icon.Provider.Name The choice of provider (default: "mini.icons")
---@return down.mod.ui.icon.Provider.Icon?
U.directory = function(dir, provider)
  return U.get("directory", dir or vim.fn.expand("%:t"), provider)
end

---Get the icon for a category and name (and optional provider)
---@param name? string The name of the icon
---@param category? string The category of the icon
---@param provider? down.mod.ui.icon.Provider.Name The choice of provider (default: "mini.icons")
---@return down.mod.ui.icon.Provider.Icon? icon The icon
U.get = function(category, name, provider)
  local icons = U.icons(provider)
  if not icons then
    return
  end
  local r = {
    category = category or "extension",
    provider = provider or "mini.icons",
    name = name or "file",
  }
  if r.provider == "nvim-web-devicons" then
    r["icon"], r["hl"], r["default"] = icons.get_icon(cat, iname) ---@diagnostic disable-line
  elseif r.provider == "mini.icons" then
    icons.mock_nvim_web_devicons() ---@diagnostic disable-line
    r["icon"], r["hl"], r["default"] = icons.get(cat, iname) ---@diagnostic disable-line
  else
    r["icon"], r["hl"], r["default"] = icons.get(cat, iname) ---@diagnostic disable-line
  end
  return r
end

---Check if the icons provider is available
---@param choice? down.mod.ui.icon.Provider.Name The choice of provider (default: "mini.icons")
U.has_provider = function(choice)
  return U.provider(choice) ~= nil
end

U.icon = U.get

function U.in_range(k, l, r_ex)
  return l <= k and k < r_ex
end

function U.is_concealing_on_row_range(
  mode,
  conceallevel,
  concealcursor,
  current_row_0b,
  row_start_0b,
  row_end_0bex
)
  if conceallevel < 1 then
    return false
  elseif not U.in_range(current_row_0b, row_start_0b, row_end_0bex) then
    return true
  else
    return (concealcursor:find(mode) ~= nil)
  end
end

function U.get_node_position_and_text_length(bufid, node)
  local row_start_0b, col_start_0b = node:range()

  -- FIXME parser: multi_definition_suffix, weak_paragraph_delimiter should not span across lines
  -- assert(row_start_0b == row_end_0bin, row_start_0b..","..row_end_0bin)
  local text = vim.treesitter.get_node_text(node, bufid)
  local past_end_offset_1b = text:find("%s") or text:len() + 1
  return row_start_0b, col_start_0b, (past_end_offset_1b - 1)
end

function U.get_header_prefix_node(header_node)
  local first_child = header_node:child(0)
  -- assert(first_child:type() == header_node:type() .. "_prefix")
  return first_child
end

function U.get_line_length(bufid, row_0b)
  return vim.api.nvim_strwidth(
    vim.api.nvim_buf_get_lines(bufid, row_0b, row_0b + 1, true)[1]
  )
end

return U
