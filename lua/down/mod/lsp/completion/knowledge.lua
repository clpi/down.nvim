--- Knowledge-graph and semantic completion source for down.nvim
---@class down.mod.lsp.completion.Knowledge
local Knowledge = {}

---@param parent table
---@param query? string
---@return table[]
Knowledge.get_items = function(parent, query)
  local items = {}
  query = (query or ""):lower()
  local max_items = (parent.config and parent.config.max_items) or 20

  local ok, kg = pcall(require, "down.mod.data.knowledge")
  if ok and kg and kg.entities then
    for id, ent in pairs(kg.entities) do
      local name = ent.name or id
      local kind = ent.kind or "concept"
      if query == "" or name:lower():find(query, 1, true) or kind:lower():find(query, 1, true) then
        local icon = "󰧑"
        if kind == "tag" then icon = "󰌷"
        elseif kind == "person" then icon = "󰀄"
        elseif kind == "document" then icon = "󰈙"
        elseif kind == "action" then icon = "󰄴"
        end
        local insert = name
        if kind == "tag" then insert = "#" .. name
        elseif kind == "person" then insert = "@" .. name
        elseif kind == "document" or kind == "concept" then insert = "[[" .. name .. "]]"
        end
        items[#items + 1] = {
          label = icon .. " " .. name,
          detail = kind,
          insert_text = insert,
          filter_text = name:lower(),
          sort_text = ("0" .. name):lower(),
          documentation = "Knowledge: " .. kind,
          kind = "reference",
        }
      end
      if #items >= max_items then break end
    end
  end

  if query ~= "" and #query >= 2 then
    local ok_sem, semantic = pcall(require, "down.mod.data.semantic")
    if ok_sem and semantic and semantic.search then
      for _, hit in ipairs(semantic.search(query, { limit = 5, threshold = 0.35 })) do
        local preview = (hit.text or ""):gsub("\n", " "):sub(1, 80)
        items[#items + 1] = {
          label = "󰚩 " .. (hit.id or "chunk"),
          detail = string.format("%.0f%% match", (hit.score or 0) * 100),
          insert_text = preview,
          filter_text = query,
          sort_text = "1" .. (hit.id or ""),
          documentation = preview,
          kind = "snippet",
        }
      end
    end
  end

  table.sort(items, function(a, b) return (a.sort_text or "") < (b.sort_text or "") end)
  return items
end

return Knowledge
