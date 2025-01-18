local config = require 'down.config'
local mod = require 'down.mod'
local util = require 'down.util'
local tsu_ok, tsu = pcall(require, 'nvim-treesitter.ts_utils')
local log = util.log
local ts = vim.treesitter
local tsq = vim.treesitter.query

---@class down.mod.Link: down.Mod
local Link = mod.new 'link'

--- @return down.mod.Setup
Link.setup = function()
  return { ---@type down.mod.Setup
    loaded = tsu_ok,
    dependencies = {
      'cmd', --- For commands
      'data.history', --- For history storage
      'tool.treesitter', --- For treesitter node parsing
      'workspace', --- For checking filetype and index file names of current workspace
    },
  }
end

--- TODO: <tab> and <s-tab> for next and previous links
Link.maps = {
  {
    'n',
    '<BS>',
    '<ESC>:<C-U>edit #<CR>',
    { desc = 'Go back', silent = true, noremap = false, nowait = true },
  },
  {
    'n',
    '<CR>',
    '<ESC>:<C-U>lua require("down.mod.link").follow.link()<CR>',
    { desc = 'Follow link', silent = true, noremap = false, nowait = true },
  },
  -- {
  --   'n',
  --   '<S-TAB>',
  --   '<ESC>:<C-U>lua require("down.mod.link").goto_prev_link()<CR>',
  --   { desc = 'Previous link', silent = true, noremap = false, nowait = true },
  -- },
  -- {
  --   'n',
  --   '<TAB>',
  --   '<ESC>:<C-U>lua require("down.mod.link").goto_next_link()<CR>',
  --   { desc = 'Next link', silent = true, noremap = false, nowait = true },
  -- },
}

Link.commands = {
  link = {
    name = 'link',
    args = 1,
    condition = 'markdown',
    callback = function(e)
      local cmd = e.body[1]
      log.trace('Link.commands.link: Callback', cmd)
    end,
    subcommands = {
      next = {
        name = 'link.next',
        args = 0,
        condition = 'markdown',
        callback = Link.goto_next_link,
      },
      previous = {
        name = 'link.previous',
        args = 0,
        condition = 'markdown',
        callback = Link.goto_prev_link,
      },
      select = {
        name = 'link.select',
        args = 0,
        condition = 'markdown',
        callback = Link.select_link,
      },
    },
  },
}

Link.load = function() end

Link.parser = function() end
Link.mk = {}
Link.follow = {}
---@enum down.mod.link.Type
---@alias down.mod.link.Tyoe
---| "local"
---| "web"
---| "heading"
Link.type = {
  ['local'] = true,
  ['heading'] = true,
  ['web'] = true,
}

Link.dir = function(dir)
  dir = dir or ''
  return vim.fs.joinpath(vim.fn.expand '%:p:h', dir)
end

Link.cwd = function(path)
  return vim.fn.expand '%:p:h' .. config.pathsep .. (path or '')
end

Link.mk.dir = function(path)
  return vim.fn.mkdir(vim.fn.expand '%:p:h' .. config.pathsep .. path, 'p')
end

Link.mk.file = function(path)
  if path:sub(-3) == '.md' then
    return Link.cwd(path)
  elseif path:sub(-1) == config.pathsep then
    Link.mk.dir(path)
    io.write(path .. 'index' .. '.md', vim.fn.expand '%:p' .. 'index.md')
  else
    return Link.cwd(path .. '.md')
  end
end

---@param ln string
---@return string, "local" | "web" | "heading"
Link.resolve = function(ln)
  local ch = ln:sub(1, 1)
  if ch == config.pathsep then
    return ln, 'local'
  elseif ch == '#' then
    return ln:sub(2), 'heading'
  elseif ch == '~' then
    return os.getenv 'HOME' .. config.pathsep .. ln:sub(2), 'local'
  elseif ln:sub(1, 8) == 'https://' or ln:sub(1, 7) == 'http://' then
    return ln, 'web'
  else
    return vim.fn.expand '%:p:h' .. config.pathsep .. ln, 'local'
  end
end

Link.children = function(node)
  return tsu.get_named_children(node)
end

Link.cursor = function()
  local node = tsu.get_node_at_cursor()
  return node, node:type()
end

Link.parent = function(node)
  local parent = node:parent()
  return parent, parent:type()
end

Link.next_node = function(node)
  local next = tsu.get_next_node(node)
  return next, next:type()
end

Link.next_link = function(node)
  local next = tsu.get_next_node(node)
  if not next then
    return
  end
  if Link.destination(next) ~= nil then
    return next
  end
  return Link.next_link(next)
end

Link.prev_link = function(node)
  local prev = tsu.get_prev_node(node)
  if not prev then
    return
  end
  if Link.destination(prev) ~= nil then
    return prev
  end
  return Link.prev_link(prev)
end

Link.goto_next_link = function()
  local node, nodety = Link.cursor()
  local next = Link.next_link(node)
  if next then
    tsu.goto_node(next)
  end
end

Link.goto_prev_link = function()
  local node, nodety = Link.cursor()
  local prev = Link.prev_link(node)
  if prev then
    tsu.goto_node(prev)
  end
end

Link.select_link = function()
  local node, nodety = Link.cursor()
  local dest = Link.destination(node)
  if dest then
    vim.fn.setreg('*', dest)
  end
end

Link.text = function(node)
  return vim.split(ts.get_node_text(node, 0), '\n')[1]
end

Link.ref = function(node)
  local link_label = Link.text(node)
  for _, captures, _ in
    Link.dep['tool.treesitter'].query([[
    (link_reference_definition
      (link_label) @label (#eq? @label "]] .. link_label .. [[")
      (link_destination) @link_destination
    )]]),
    'markdown'
  do
    local capture = ts.get_node_text(captures[2], 0)
    return capture:gsub('[<>]', '')
  end
end

Link.format_link = function(ln)
  return ln
end

Link.query = function(n, lang)
  lang = lang or vim.bo.filetype
  local lt = ts.get_parser(0, lang):parse()[1]:root()
  local pq = tsq.parse(lang, n)
  return pq:iter_matches(lt, 0)
end

--- Checks whether a node is a wikilink, and if not, checks if parent is a wikilink
--- If either are, then returns the link destination, otherwise nil
--- @return string|nil
Link.iswikilink = function(node, parent)
  if node and parent then
    return ts.get_node_text(parent, 0):iswikilink()
  elseif node and not parent then
    return ts.get_node_text(node, 0):iswikilink()
  else
    return nil
  end
end

Link.destination = function(nd)
  local node, nodety
  if not nd then
    node, nodety = Link.cursor()
  else
    node, nodety = node, node:type()
  end
  local parent = node:parent()
  local wikilink = Link.iswikilink(node, parent)
  if wikilink then
    return wikilink
  end
  if not parent then
    if not node then
      return
    end
    return
  end
  local parentty = parent:type()
  if nodety == 'link_destination' then
    return Link.text(node)
  elseif nodety == 'link_label' or nodety == 'shortcut_link' then
    return Link.ref(node)
  elseif nodety == 'link_text' then
    if parentty == 'shortcut_link' then -- Could be wikilink
      local ref = Link.ref(parent)
      if ref then
        return ref
      end
      return Link.text(node)
    end
    local next, nextty = Link.next_node(node)
    if nextty == 'link_destination' then
      return Link.text(next)
    elseif nextty == 'link_label' then
      return Link.ref(next)
    end
  elseif nodety == 'link_reference_definition' or nodety == 'inline_link' then
    for _, nc in pairs(Link.children(node)) do
      if nc:type() == 'link_destination' then
        return Link.text(nc)
      end
    end
  elseif nodety == 'full_reference_link' then
    for _, nc in pairs(Link.children(node)) do
      if nc:type() == 'link_label' then
        return Link.ref(nc)
      end
    end
  end
  return
end

---@class down.mod.link.Config
Link.config = {}

Link.follow.loc = function(ln)
  local mod_ln, path_ln = nil, vim.split(ln, ':')
  local path, line = path_ln[1], path_ln[2]
  if path:sub(-1) == config.pathsep then
    local ix = path .. 'index' .. '.md'
    path = path:sub(1, -2)
    if vim.fn.glob(path) == '' then
      local dir, file = vim.fn.fnameescape(path), vim.fn.fnameescape(ix)
      vim.fn.mkdir(dir, 'p')
      Link.dep['data.history'].push(file)
      return vim.cmd(('edit %s'):format(file))
    else
      return vim.cmd(('edit %s'):format(vim.fn.fnameescape(ix)))
    end
  end
  if path:sub(-3) ~= '.md' then
    if vim.fn.glob(path) == '' then
      mod_ln = path .. '.md'
    end
    mod_ln = path .. '.md'
  else
    mod_ln = path
  end
  if mod_ln and line then
    vim.cmd(('silent! %s +%s %s'):format('e', line, vim.fn.fnameescape(mod_ln)))
  elseif mod_ln and not line then
    vim.cmd(('silent! %s %s'):format('e', vim.fn.fnameescape(mod_ln)))
  end
end
Link.follow.heading = function(ln)
  ln = ln:gsub('-', '[- ]*')
  ln = ln:gsub('-', '[- ]*')
  vim.fn.search('\\c^#\\+ *' .. ln, 'ew')
end
Link.follow.web = function(ln)
  ---TODO: vim.fn.open
  if config.os == 'linux' then
    vim.fn.system('xdg-open ' .. vim.fn.shellescape(ln))
  elseif config.os == 'mac' then
    vim.fn.system('open ' .. vim.fn.shellesscape(ln))
  elseif config.os == 'windows' then
    vim.fn.system('cmd.exe /c start "" ' .. vim.fn.shellescape(ln))
  else
    vim.fn.system('xdg-open ' .. vim.fn.shellescape(ln))
  end
end
Link.follow.link = function()
  local ld = Link.destination()
  if ld then
    local res, lty = Link.resolve(ld)
    if lty == 'local' then
      Link.follow.loc(res)
    elseif lty == 'heading' then
      Link.follow.heading(res)
    elseif lty == 'web' then
      Link.follow.web(res)
    end
  end
end
return Link
