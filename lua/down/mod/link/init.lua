local config = require 'down.config'
local mod = require 'down.mod'
local util = require 'down.util'
local tsu_ok, tsu = pcall(require, 'nvim-treesitter.ts_utils')
local log = log
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
      'integration.treesitter', --- For treesitter node parsing
      'workspace', --- For checking filetype and index file names of current workspace
    },
  }
end

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
    '<ESC>:<C-U>lua require("down.mod.link").follow.link_or_create()<CR>',
    { desc = 'Follow/Create link', silent = true, noremap = false, nowait = true },
  },
  {
    'n',
    '<S-TAB>',
    '<ESC>:<C-U>lua require("down.mod.link").goto.prev()<CR>',
    { desc = 'Previous link', silent = true, noremap = false, nowait = true },
  },
  {
    'n',
    '<TAB>',
    '<ESC>:<C-U>lua require("down.mod.link").goto.next()<CR>',
    { desc = 'Next link', silent = true, noremap = false, nowait = true },
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
  ['file'] = true,
  ['heading'] = true,
  ['web'] = true,
}

Link.dir = function(dir)
  dir = dir or ''
  return vim.fs.joinpath(vim.fn.expand '%:p:h', dir)
end

Link.cwd = function(path)
  return vim.fn.expand '%:p:h' .. util.sep .. (path or '')
end

Link.mk.dir = function(path)
  return vim.fn.mkdir(vim.fn.expand '%:p:h' .. util.sep .. path, 'p')
end

Link.mk.file = function(path)
  if path:sub(-3) == '.md' then
    return Link.cwd(path)
  elseif path:sub(-1) == util.sep then
    Link.mk.dir(path)
    io.write(path .. 'index' .. '.md', vim.fn.expand '%:p' .. 'index.md')
  else
    return Link.cwd(path .. '.md')
  end
end

---@param ln string
---@return string, "file" | "web" | "heading"
Link.resolve = function(ln)
  local ch = ln:sub(1, 1)
  if ch == util.sep then
    return ln, 'file'
  elseif ch == '#' then
    return ln:sub(2), 'heading'
  elseif ch == '~' then
    return os.getenv 'HOME' .. util.sep .. ln:sub(2), 'file'
  elseif ln:sub(1, 8) == 'https://' or ln:sub(1, 7) == 'http://' then
    return ln, 'web'
  else
    return vim.fn.expand '%:p:h' .. util.sep .. ln, 'file'
  end
end

Link.children = function(node)
  return tsu.get_named_children(node)
end

Link.cursor = function()
  local node = tsu.get_node_at_cursor()
  if not node then return end
  return node, node:type()
end

Link.parent = function(node)
  local parent = node:parent()
  if not parent then return end
  return parent, parent:type()
end

Link.node = {
prev = function(node)
  local next = tsu.get_prev_node(node)
  if not next then return end
  return next, next:type()
end,
next = function(node)
  local next = tsu.get_next_node(node)
  if not next then return end
  return next, next:type()
end
}

Link.next = function(node)
  local next = tsu.get_next_node(node)
  if not next then
    return
  end
  if Link.destination(next) ~= nil then
    return next
  end
  return Link.next(next)
end

Link.prev = function(node)
  local prev = tsu.get_prev_node(node)
  if not prev then
    return
  end
  if Link.destination(prev) ~= nil then
    return prev
  end
  return Link.prev(prev)
end
Link.goto = {
prev = function()
  local node, _ = Link.cursor()
  local prev = Link.prev(node)
  if next then
    tsu.goto_node(prev)
  end
end,
next = function()
  local node, _ = Link.cursor()
  local next = Link.next(node)
  if next then
    tsu.goto_node(next)
  end
end,
}

Link.select = function()
  local node, _ = Link.cursor()
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
    Link.dep['integration.treesitter'].query([[
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

---@param node TSNode
Link.query = function(node, lang)

  lang = lang or vim.bo.filetype
  local lt = ts.get_parser(0, lang):parse()[1]:root()
  local pq = tsq.parse(lang, node)
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

--- Returns the destination of a link node
--- @param nd TSNode|nil
Link.destination = function(nd)
  local node, nodety
  if not nd then
    node, nodety = Link.cursor()
  else
    node, nodety = node, node:type()
  end
  if not node then
    return
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
    local next, nextty = Link.node.next(node)
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
end

---@class down.mod.link.Config
Link.config = {}

Link.follow.file = function(ln)
  local mod_ln, path_ln = nil, vim.split(ln, ':')
  local path, line = path_ln[1], path_ln[2]
  if path:sub(-1) == util.sep then
    local ix = path .. 'index' .. '.md'
    path = path:sub(1, -2)
    if vim.fn.glob(path) == '' then
      local dir, file = vim.fn.fnameescape(path), vim.fn.fnameescape(ix)
      vim.fn.mkdir(dir, 'p')
      Link.dep['data.history'].add.file(file)
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

Link.follow.link = function()
  local ld = Link.destination()
  if ld then
    local res, lty = Link.resolve(ld)
    if lty == 'file' then
      Link.follow.file(res)
    elseif lty == 'heading' then
      Link.follow.heading(res)
    elseif lty == 'web' then
      vim.ui.open(res)
    end
  end
end

--- Get word under cursor
---@return string, number, number
Link.get_word_under_cursor = function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- If cursor is on whitespace, return empty
  if line:sub(col, col):match('%s') then
    return '', 0, 0
  end

  -- Find word boundaries - support alphanumeric, underscore, hyphen, dot, and slash for paths
  local word_start = col
  local word_end = col

  -- Move backwards to find word start
  while word_start > 1 do
    local char = line:sub(word_start - 1, word_start - 1)
    if char:match('[%w_%-/.]') then
      word_start = word_start - 1
    else
      break
    end
  end

  -- Move forwards to find word end
  while word_end <= #line do
    local char = line:sub(word_end, word_end)
    if char:match('[%w_%-/.]') then
      word_end = word_end + 1
    else
      break
    end
  end

  local word = line:sub(word_start, word_end - 1)
  return word, word_start, word_end
end

--- Convert word under cursor to a wikilink
---@param word string
---@param word_start number
---@param word_end number
Link.linkify_word = function(word, word_start, word_end)
  if not word or word == '' then
    return false
  end

  local line = vim.api.nvim_get_current_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]

  -- Check if we're already inside a wikilink
  local before_cursor = line:sub(1, word_start - 1)
  local after_cursor = line:sub(word_end)

  -- Don't linkify if already inside [[...]]
  if before_cursor:match('%[%[[^%]]*$') or after_cursor:match('^[^%[]*%]%]') then
    return false
  end

  -- Create wikilink
  local before = line:sub(1, word_start - 1)
  local after = line:sub(word_end)
  local new_line = before .. '[[' .. word .. ']]' .. after

  vim.api.nvim_set_current_line(new_line)

  -- Move cursor to inside the link (after the opening [[)
  vim.api.nvim_win_set_cursor(0, { row, word_start + 1 })

  return true
end

--- Check if we're actually on a link (not just text)
---@return boolean
Link.is_on_link = function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Check for wikilink [[...]]
  local before = line:sub(1, col)
  local after = line:sub(col)

  -- We're in a wikilink if we have [[ before and ]] after without closing/opening in between
  local in_wikilink = before:match('%[%[[^%]]*$') and after:match('^[^%[]*%]%]')
  if in_wikilink then
    return true
  end

  -- Check for markdown link [text](url)
  -- We're in a markdown link if we have [text]( before and ) after
  local in_md_link = before:match('%[[^%]]*%]%([^%)]*$') and after:match('^[^%(]*%)')
  if in_md_link then
    return true
  end

  -- Check for autolink <url>
  local in_autolink = before:match('<[^>]*$') and after:match('^[^<]*>')
  if in_autolink then
    return true
  end

  return false
end

--- Main function: Follow link if on link, linkify word if on word
Link.follow.link_or_create = function()
  -- First check if we're actually on a link using simple text matching
  local is_on_link = Link.is_on_link()

  if is_on_link then
    -- We're on a link, try to follow it
    local ld = Link.destination()
    if ld then
      local res, lty = Link.resolve(ld)
      if lty == 'file' then
        Link.dep['data.history'].add.file(vim.fn.expand('%:p'))
        Link.follow.file(res)
      elseif lty == 'heading' then
        Link.follow.heading(res)
      elseif lty == 'web' then
        vim.ui.open(res)
      end
      return
    end
  end

  -- Not on a link, get word under cursor and linkify it
  local word, word_start, word_end = Link.get_word_under_cursor()

  if not word or word == '' then
    return
  end

  -- Just linkify the word, don't navigate
  local success = Link.linkify_word(word, word_start, word_end)

  if not success then
    -- Already in a link or failed to linkify
    return
  end
end

Link.commands = {
  link = {
    name = "link",
    enabled = true,
    min_args = 0,
    max_args = 1,
    condition = "markdown",
    callback = function(e)
      Link.follow.link_or_create()
    end,
    commands = {
      linkify = {
        name = "link.linkify",
        enabled = true,
        args = 0,
        min_args = 0,
        max_args = 1,
        condition = "markdown",
        callback = function(e)
          local word, word_start, word_end = Link.get_word_under_cursor()
          if word and word ~= '' then
            Link.linkify_word(word, word_start, word_end)
          end
        end,
      },
      follow = {
        name = "link.follow",
        enabled = true,
        args = 0,
        min_args = 0,
        max_args = 1,
        condition = "markdown",
        callback = function(e)
          Link.follow.link_or_create()
        end,
      },
      backlink = {
        enabled = true,
        name = "backlink",
        args = 0,
        min_args = 0,
        max_args = 1,
        condition = "markdown",
        callback = function(e)
          log.trace("Link.commands.backlink: Callback", e.body[1])
        end,
        commands = {
          list = {
            name = "backlink.list",
            enabled = true,
            args = 0,
            condition = "markdown",
            callback = function()
              local hg = Link.dep['data.history'].get()
              if hg then
                for _, hi in ipairs(hg.get) do
                  print(hi, hg)
                end
              end
            end,
          },
        },
      },
      next = {
        name = "link.next",
        enabled = true,
        min_args = 0,
        max_args = 1,
        condition = "markdown",
        commands = {},
        callback = Link.goto.next,
      },
      previous = {
        enabled = true,
        name = "link.previous",
        min_args = 0,
        max_args = 1,
        condition = "markdown",
        callback = Link.goto.prev,
        commands = {},
      },
      select = {
        name = "link.select",
        min_args = 0,
        max_args = 1,
        enabled = true,
        condition = "markdown",
        commands = {},
        callback = Link.select,
      },
    },
  },
}
return Link
