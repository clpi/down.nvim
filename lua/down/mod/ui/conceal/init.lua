local down = require('down')
local mod, config = down.mod, down.cfg
local Conceal = mod.new('ui.conceal')
local fn, a, madd = vim.fn, vim.api, vim.fn.matchadd
-- Conceal.chars = require("down.mod.ui.conceal.chars")
-- Conceal.math = require("down.mod.ui.conceal.math")
-- Conceal.border = require("down.mod.ui.conceal.border")

Conceal.setup = function()
  return {
    loaded = true,
    dependencies = {},
  }
end

Conceal.math = Conceal.math
Conceal.border = Conceal.border
Conceal.chars = Conceal.chars
---@class down.edit.conceal.Config
Conceal.config = {
  link_style = 'markdown',
}
Conceal.start_link_concealing = function()
  if Conceal.config.link_style == 'markdown' then
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
  elseif Conceal.config.link_style == 'wiki' then
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

-- Set up autocommands to trigger the link concealing setup in Concealarkdown files

Conceal.ft_patterns = function()
  -- Create ft pattern
  local filetypes = config.ft
  local ft_pattern = ''

  for ext, _ in pairs(filetypes) do
    ft_pattern = ft_pattern .. '*.' .. ext .. ','
  end
  return ft_pattern
end

a.nvim_create_autocmd({ 'FileType', 'BufRead', 'BufEnter' }, {
  pattern = Conceal.ft_patterns(),
  callback = function()
    Conceal.start_link_concealing()
  end,
})

return Conceal
