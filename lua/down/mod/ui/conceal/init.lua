local down = require('down')
local mod, config = down.mod, down.cfg
local M = mod.new('ui.conceal')
local fn, a, madd = vim.fn, vim.api, vim.fn.matchadd
-- M.chars = require("down.mod.ui.conceal.chars")
-- M.math = require("down.mod.ui.conceal.math")
-- M.border = require("down.mod.ui.conceal.border")

M.setup = function()
  return {
    loaded = true,
    dependencies = {},
  }
end

M.math = M.math
M.border = M.border
M.chars = M.chars
---@class down.edit.conceal.Config
M.config = {
  link_style = 'markdown',
}
M.start_link_concealing = function()
  if M.config.link_style == 'markdown' then
    madd('Conceal', '\\[[^[]\\{-}\\]\\zs([^(]\\{-})\\ze', 0, -1, { conceal = '' })
    madd('Conceal', '\\zs\\[\\ze[^[]\\{-}\\]([^(]\\{-})', 0, -1, { conceal = '' })
    madd('Conceal', '\\[[^[]\\{-}\\zs\\]\\ze([^(]\\{-})', 0, -1, { conceal = '' })
    madd(
      'Conceal',
      '\\[[^[]\\{-}\\]\\zs\\%[ ]\\[[^[]\\{-}\\]\\ze\\%[ ]\\v([^(]|$)',
      0,
      -1,
      { conceal = '' }
    )
    madd(
      'Conceal',
      '\\zs\\[\\ze[^[]\\{-}\\]\\%[ ]\\[[^[]\\{-}\\]\\%[ ]\\v([^(]|$)',
      0,
      -1,
      { conceal = '' }
    )
    madd(
      'Conceal',
      '\\[[^[]\\{-}\\zs\\]\\ze\\%[ ]\\[[^[]\\{-}\\]\\%[ ]\\v([^(]|$)',
      0,
      -1,
      { conceal = '' }
    )
    madd('Conceal', '\\[[^[]\\{-}\\]\\zs\\%[ ]\\[[^[]\\{-}\\]\\ze\\n', 0, -1, { conceal = '' })
    madd('Conceal', '\\zs\\[\\ze[^[]\\{-}\\]\\%[ ]\\[[^[]\\{-}\\]\\n', 0, -1, { conceal = '' })
    madd('Conceal', '\\[[^[]\\{-}\\zs\\]\\ze\\%[ ]\\[[^[]\\{-}\\]\\n', 0, -1, { conceal = '' })
  elseif M.config.link_style == 'wiki' then
    madd('Conceal', '\\zs\\[\\[[^[]\\{-}[|]\\ze[^[]\\{-}\\]\\]', 0, -1, { conceal = '' })
    madd('Conceal', '\\[\\[[^[\\{-}[|][^[]\\{-}\\zs\\]\\]\\ze', 0, -1, { conceal = '' })
    madd('Conceal', '\\zs\\[\\[\\ze[^[]\\{-}\\]\\]', 0, -1, { conceal = '' })
    madd('Conceal', '\\[\\[[^[]\\{-}\\zs\\]\\]\\ze', 0, -1, { conceal = '' })
  end

  -- Set conceal level
  vim.wo.conceallevel = 2

  -- Don't change the highlighting of concealed characters
  a.nvim_exec([[highlight Conceal ctermbg=NONE ctermfg=NONE guibg=NONE guifg=NONE]], false)
end

-- Set up autocommands to trigger the link concealing setup in Markdown files

M.ft_patterns = function()
  -- Create ft pattern
  local filetypes = config.ft
  local ft_pattern = ''

  for ext, _ in pairs(filetypes) do
    ft_pattern = ft_pattern .. '*.' .. ext .. ','
  end
  return ft_pattern
end

a.nvim_create_autocmd({ 'FileType', 'BufRead', 'BufEnter' }, {
  pattern = M.ft_patterns(),
  callback = function()
    M.start_link_concealing()
  end,
})

return M
