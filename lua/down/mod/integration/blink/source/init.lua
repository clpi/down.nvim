---@type blink.cmp.Source
local Src = {}

local Resp = {}

function Src.init()
  local self = setmetatable(Src, { __index = Src })
  self.cache = {}
  return self
end

function Resp.completions(ctx, items)
  return {
    context = ctx,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
    items = items,
  }
end

function Resp.default(ctx)
  return {
    context = ctx,
    is_incomplete_backward = true,
    is_incomplete_forward = true,
    items = {},
  }
end

function Src:get_completiosn(ctx, cb)
  local ccb = function(err, resp)
    if resp == nil then
      return cb(Resp.default(ctx))
    end
    local items = {}
    local data = resp.completions
    if data == nil then
      print("data nil")
      return cb(Resp.default(ctx))
    end
    for _, cmp in ipairs(data) do
      -- completion = require("bcp.format").format_item(completion)
      ---@type blink.cmp.CompletionItem
      completion = completion
      local item = {
        kind = require("blink.cmp.ids").CompletionItemKind.Lsp,
        -- label = "cmp",
        label = completion.displayText,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
        insertText = completion.text,
        description = "down suggestion",
        textEdit = completion.textEdit,
        filterText = completion.filterText,
        cursor_column = completion.cursor_column,
        source_name = "down",
        documentation = completion.text,
        blink_render = {
          render_icon = "",
          render_name = "down",
        },
        documentation = completion.text,
      }
      table.insert(items, item)
    end
    return cb(Resp.completions(ctx, items))
  end
  -- copilot_api.get_completions(client, util.get_doc_params(), copilot_callback)
end

return Src
