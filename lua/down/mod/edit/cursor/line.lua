return setmetatable({
  range = {
    visible = function(winid)
      local row_start_1b = vim.fn.line("w0", winid)
      local row_end_1b = vim.fn.line("w$", winid)
      return (row_start_1b - 1), row_end_1b
    end,
  },
}, {
  __len = function()
    local ln = vim.api.nvim_get_current_line()
    return #ln
  end,
})
