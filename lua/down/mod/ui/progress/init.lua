-- TODO: code cleanup
local Spinner = require('down.mod').new('ui.progress')
--> from fidget.nvim
local list = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

Spinner.setup = function()
  return {
    loaded = true,
  }
end

---@class down.ui.progress.Config
Spinner.config = {}

function Spinner.start(s, ns)
  local block = s.code_block
  local r, c = block['start'].row, block['start'].column
  local t = vim.loop.new_timer()

  local idx = 0
  local id = vim.api.nvim_buf_set_extmark(s.buf, ns, r, c, {
    virt_text_pos = 'eol',
    virt_text = { { list[idx + 1], 'Function' } },
  })

  t:start(
    0,
    100,
    vim.schedule_wrap(function()
      idx = (idx + 1) % #list
      vim.api.nvim_buf_set_extmark(
        s.buf,
        ns,
        r,
        c,
        { virt_text = { { list[idx + 1], 'Function' } }, id = id }
      )
    end)
  )

  return {
    id = id,
    buf = s.buf,
    ns = ns,
    r = r,
    c = c,
    t = t,
  }
end

function Spinner.shut(s, ns)
  -- local s = Spinner.state
  vim.api.nvim_buf_del_extmark(s.buf, ns, s.id)
  s.t:stop()
end

return Spinner
