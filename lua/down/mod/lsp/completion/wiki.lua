--- [[ wiki link completion source for down.nvim
---@class down.mod.lsp.completion.Wiki
local Wiki = {}

---@param parent table
---@param query? string
---@return table[]
Wiki.get_items = function(parent, query)
  local items = {}
  local mod = require("down.mod")
  local ws = mod.get_mod("workspace")
  if not ws then
    return items
  end
  local current_ws = ws.current()
  local ws_path = ws.get(current_ws)
  if not ws_path then
    return items
  end
  query = (query or ""):lower()
  local ext = ws.config.ext or ".md"
  local files = vim.fn.glob(ws_path .. "/**" .. ext, true, true)
  for _, filepath in ipairs(files) do
    local rel = filepath:sub(#ws_path + 2)
    local name = rel:match("(.+)" .. ext:gsub("%.", "%%.") .. "$") or rel
    local basename = name:match("[^/\\]+$") or name
    if query == "" or basename:lower():find(query, 1, true) or name:lower():find(query, 1, true) then
      items[#items + 1] = {
        label = "󰎞 " .. basename,
        detail = rel,
        insert_text = basename .. "]]",
        filter_text = basename:lower(),
        sort_text = basename:lower(),
        documentation = "Link to: " .. rel,
        kind = "file",
      }
    end
    if #items >= 20 then
      break
    end
  end
  table.sort(items, function(a, b)
    return (a.sort_text or "") < (b.sort_text or "")
  end)
  return items
end

return Wiki
