--- @class (exact) down.Tag
---   @field tag string
---   @field ln number
---   @field col number
---   @field uri string
---   @field workspace string

---@type down.Tag
local Tag = setmetatable({
  tag = '',
  uri = '',
  time = 0,
  pos = {
    ln = 0,
    col = 0,
  },
}, {
})

function Tag.new(tag, uri, ln, col)
  return {
    tag = tag,
    uri = uri or vim.fn.expand("%:p"),
    time = os.time(),
    pos = {
      ln = ln or vim.api.nvim_win_get_cursor(0)[1],
      col = col or vim.api.nvim_win_get_cursor(0)[2],
    }
  }
end

function Tag:save()
end

return Tag
