local down = require('down')

local M = down.mod.new('ui.icon.basic')

---@class down.ui.icon.basic.Config
M.config = {
  icon_basic = {},
}

---@class down.ui.icon.basic.Data
M.icons = {
  default = { glyph = '󰟢', hl = 'MiniIconsGrey' },
  directory = { glyph = '󰉋', hl = 'MiniIconsAzure' },
  extension = { glyph = '󰈔', hl = 'MiniIconsGrey' },
  file = { glyph = '󰈔', hl = 'MiniIconsGrey' },
  filetype = { glyph = '󰈔', hl = 'MiniIconsGrey' },
  lsp = { glyph = '󰞋', hl = 'MiniIconsRed' },
  os = { glyph = '󰟀', hl = 'MiniIconsPurple' },
}

-- Directory icons. Keys are some popular *language-agnostic* directory
-- basenames. Use only "folder-shaped" glyphs while prefering `nf-md-folder-*`
-- classes (unless glyph is designed specifically for the directory name)
--stylua: ignore
M.icons.fs = {
  ['.cache']    = { glyph = '󰪺', hl = 'MiniIconsCyan' },
  ['.config']   = { glyph = '󱁿', hl = 'MiniIconsCyan' },
  ['.git']      = { glyph = '', hl = 'MiniIconsOrange' },
  ['.github']   = { glyph = '', hl = 'MiniIconsAzure' },
  ['.local']    = { glyph = '󰉌', hl = 'MiniIconsCyan' },
  ['.vim']      = { glyph = '󰉋', hl = 'MiniIconsGreen' },
  AppData       = { glyph = '󰉌', hl = 'MiniIconsOrange' },
  Applications  = { glyph = '󱧺', hl = 'MiniIconsOrange' },
  Desktop       = { glyph = '󰚝', hl = 'MiniIconsOrange' },
  Documents     = { glyph = '󱧶', hl = 'MiniIconsOrange' },
  Downloads     = { glyph = '󰉍', hl = 'MiniIconsOrange' },
  Favorites     = { glyph = '󱃪', hl = 'MiniIconsOrange' },
  Library       = { glyph = '󰲂', hl = 'MiniIconsOrange' },
  Music         = { glyph = '󱍙', hl = 'MiniIconsOrange' },
  Network       = { glyph = '󰡰', hl = 'MiniIconsOrange' },
  Pictures      = { glyph = '󰉏', hl = 'MiniIconsOrange' },
  ProgramData   = { glyph = '󰉌', hl = 'MiniIconsOrange' },
  Public        = { glyph = '󱧰', hl = 'MiniIconsOrange' },
  System        = { glyph = '󱧼', hl = 'MiniIconsOrange' },
  Templates     = { glyph = '󱋣', hl = 'MiniIconsOrange' },
  Trash         = { glyph = '󱧴', hl = 'MiniIconsOrange' },
  Users         = { glyph = '󰉌', hl = 'MiniIconsOrange' },
  Videos        = { glyph = '󱞊', hl = 'MiniIconsOrange' },
  Volumes       = { glyph = '󰉓', hl = 'MiniIconsOrange' },
  bin           = { glyph = '󱧺', hl = 'MiniIconsYellow' },
  build         = { glyph = '󱧼', hl = 'MiniIconsGrey' },
  boot          = { glyph = '󰴋', hl = 'MiniIconsYellow' },
  dev           = { glyph = '󱧼', hl = 'MiniIconsYellow' },
  doc           = { glyph = '󱂷', hl = 'MiniIconsPurple' },
  docs          = { glyph = '󱂷', hl = 'MiniIconsPurple' },
  etc           = { glyph = '󱁿', hl = 'MiniIconsYellow' },
  home          = { glyph = '󱂵', hl = 'MiniIconsYellow' },
  lib           = { glyph = '󰲂', hl = 'MiniIconsYellow' },
  media         = { glyph = '󱧺', hl = 'MiniIconsYellow' },
  mnt           = { glyph = '󰉓', hl = 'MiniIconsYellow' },
  ['mini.nvim'] = { glyph = '󰚝', hl = 'MiniIconsRed' },
  node_modules  = { glyph = '', hl = 'MiniIconsGreen' },
  nvim          = { glyph = '󰉋', hl = 'MiniIconsGreen' },
  opt           = { glyph = '󰉗', hl = 'MiniIconsYellow' },
  proc          = { glyph = '󰢬', hl = 'MiniIconsYellow' },
  root          = { glyph = '󰷌', hl = 'MiniIconsYellow' },
  sbin          = { glyph = '󱧺', hl = 'MiniIconsYellow' },
  src           = { glyph = '󰴉', hl = 'MiniIconsPurple' },
  srv           = { glyph = '󱋣', hl = 'MiniIconsYellow' },
  tmp           = { glyph = '󰪺', hl = 'MiniIconsYellow' },
  test          = { glyph = '󱞊', hl = 'MiniIconsBlue' },
  tests         = { glyph = '󱞊', hl = 'MiniIconsBlue' },
  usr           = { glyph = '󰉌', hl = 'MiniIconsYellow' },
  var           = { glyph = '󱋣', hl = 'MiniIconsYellow' },
}
-- LSP kind values (completion item, symbol, etc.) icons.
-- Use only `nf-cod-*` classes with "outline" look. Balance colors.
--stylua: ignore
M.icons.lsp = {
  array         = { glyph = '', hl = 'MiniIconsOrange' },
  boolean       = { glyph = '', hl = 'MiniIconsOrange' },
  class         = { glyph = '', hl = 'MiniIconsPurple' },
  color         = { glyph = '', hl = 'MiniIconsRed' },
  constant      = { glyph = '', hl = 'MiniIconsOrange' },
  constructor   = { glyph = '', hl = 'MiniIconsAzure' },
  enum          = { glyph = '', hl = 'MiniIconsPurple' },
  enummember    = { glyph = '', hl = 'MiniIconsYellow' },
  event         = { glyph = '', hl = 'MiniIconsRed' },
  field         = { glyph = '', hl = 'MiniIconsYellow' },
  file          = { glyph = '', hl = 'MiniIconsBlue' },
  folder        = { glyph = '', hl = 'MiniIconsBlue' },
  ['function']  = { glyph = '', hl = 'MiniIconsAzure' },
  interface     = { glyph = '', hl = 'MiniIconsPurple' },
  key           = { glyph = '', hl = 'MiniIconsYellow' },
  keydown       = { glyph = '', hl = 'MiniIconsCyan' },
  method        = { glyph = '', hl = 'MiniIconsAzure' },
  module        = { glyph = '', hl = 'MiniIconsPurple' },
  namespace     = { glyph = '', hl = 'MiniIconsRed' },
  null          = { glyph = '', hl = 'MiniIconsGrey' },
  number        = { glyph = '', hl = 'MiniIconsOrange' },
  object        = { glyph = '', hl = 'MiniIconsGrey' },
  operator      = { glyph = '', hl = 'MiniIconsCyan' },
  package       = { glyph = '', hl = 'MiniIconsPurple' },
  property      = { glyph = '', hl = 'MiniIconsYellow' },
  reference     = { glyph = '', hl = 'MiniIconsCyan' },
  snippet       = { glyph = '', hl = 'MiniIconsGreen' },
  string        = { glyph = '', hl = 'MiniIconsGreen' },
  struct        = { glyph = '', hl = 'MiniIconsPurple' },
  text          = { glyph = '', hl = 'MiniIconsGreen' },
  typeparameter = { glyph = '', hl = 'MiniIconsCyan' },
  unit          = { glyph = '', hl = 'MiniIconsCyan' },
  value         = { glyph = '', hl = 'MiniIconsBlue' },
  variable      = { glyph = '', hl = 'MiniIconsCyan' },
}

return M
