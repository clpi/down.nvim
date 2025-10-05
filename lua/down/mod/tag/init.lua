local mod = require('down.mod')
local log = require('down.log')
local Tag = require('down.mod.tag.tag')

---@class down.mod.tag.Tag: down.Mod
local Tag = mod.new 'tag'

---@class down.mod.tag.Commands: down.Commands
Tag.commands = {
  tag = {
    name = 'tag',
    condition = 'markdown',
    args = 0,
    max_args = 1,
    enabled = true,
    callback = function(e)
      -- Show tag picker
      local find = require('down.mod').get_mod('find')
      if find then
        find.picker('tag')({ scope = 'buffer' })
      end
    end,
    commands = {
      delete = {
        name = 'tag.delete',
        condition = 'markdown',
        args = 0,
        max_args = 1,
        enabled = true,
        callback = function(e)
          Tag.delete_tag_under_cursor()
        end,
      },
      new = {
        args = 0,
        max_args = 1,
        condition = 'markdown',
        enabled = true,
        callback = function(e)
          Tag.create_tag()
        end,
        name = 'tag.new',
      },
      list = {
        name = 'tag.list',
        args = 0,
        max_args = 1,
        condition = 'markdown',
        enabled = true,
        callback = function(e)
          local find = require('down.mod').get_mod('find')
          if find then
            find.picker('tag')({ scope = 'workspace' })
          end
        end,
      },
      goto = {
        name = 'tag.goto',
        args = 0,
        max_args = 1,
        condition = 'markdown',
        enabled = true,
        callback = function(e)
          Tag.goto_tag()
        end,
      },
    },
  },
}
---@return down.mod.Setup
Tag.setup = function()
  return {
    loaded = true,
    dependencies = { 'workspace', 'cmd', 'data' },
  }
end

---@class (exact) down.Tag.Instance: {
---  tag: string,
---  line?: string,
---  position: down.Position,
---  path: string,
---  workspace?: string,
---}

---@class (exact) down.Tag.Instances: {
---  [string]: down.Tag.Instance[],
---}

---@class down.mod.tag.Data
Tag.tags = {
  ---@type down.Tag.Instances
  global = {},
  ---@type down.Tag.Instances
  workspace = {},
  ---@type down.Tag.Instances
  document = {},
}

--- Parse a single line for tag instances
--- @param ln string
--- @param lnno number
--- @param path string
--- @return string[]
Tag.parse_ln = function(ln)
  local tags = {}
  for tag in ln:gmatch '#%S+' do
    tags:insert(tag)
  end
  return tags
end

Tag.parse_current_ln = function()
  local ln = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)
  local path = vim.fn.expand('%:p')
  local ws = Tag.dep['workspace'].get_current_workspace()
  local tags = {}
  for tag in ln:gmatch '#%S+' do
    table.insert(tags, { ---@type down.Tag.Instance
      tag = tag,
      workspace = ws,
      path = path,
      line = ln,
      position = {
        line = vim.api.nvim_get_current_line(),
        char = 0,
      },
    })
  end
  return tags
end

Tag.parse_current_doc = function()
  local tags = {}
  for i, ln in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    for tag in ln:gmatch '#%S+' do
      table.insert(tags, { ---@type down.Tag.Instance
        tag = tag,
        workspace = Tag.dep['workspace'].get_current_workspace(),
        path = vim.fn.expand('%:p'),
        line = ln,
        position = {
          line = i,
          col = 0,
        },
      })
    end
  end
  return tags
end

Tag.parse_current_workspace = function()
  local tags = {}
  for i, ln in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    for tag in ln:gmatch '#%S+' do
      table.insert(tags, { ---@type down.Tag.Instance
        tag = tag,
        workspace = Tag.dep['workspace'].get_current_workspace(),
        path = vim.fn.expand('%:p'),
        line = ln,
        position = {
          line = i,
          col = 0,
        },
      })
    end
  end
  return tags
end

Tag.parse = function(text)
  local tags = {}
  for ln in text:gmatch '[^\n]+' do
    vim.tbl_deep_extend('force', Tag.tags.document, Tag.parse_ln(ln))
  end
  return tags
end

Tag.parse_doc = function(path)
  local tags = {}
  local buf = assert(io.open(path, 'r'))
  for i, ln in ipairs(buf:lines()) do
  end
end

Tag.document_source = function(path) end

Tag.workspace_source = function(path) end

--- Get tag under cursor
---@return string|nil
Tag.get_tag_under_cursor = function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Check if we're on a tag
  local before = line:sub(1, col)
  local after = line:sub(col)

  -- Find tag boundaries
  local tag_start = before:reverse():find('[^%w%-_]')
  local tag_end = after:find('[^%w%-_]')

  if tag_start then
    tag_start = col - tag_start + 1
  else
    tag_start = 1
  end

  if tag_end then
    tag_end = col + tag_end - 2
  else
    tag_end = #line
  end

  local word = line:sub(tag_start, tag_end)

  -- Check if it starts with #
  if word:sub(1, 1) == '#' then
    return word
  end

  -- Check if character before is #
  if tag_start > 1 and line:sub(tag_start - 1, tag_start - 1) == '#' then
    return '#' .. word
  end

  return nil
end

--- Create a new tag at cursor or convert word to tag
Tag.create_tag = function()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Get word under cursor
  local word_start = col
  local word_end = col

  while word_start > 1 and line:sub(word_start - 1, word_start - 1):match('[%w%-_]') do
    word_start = word_start - 1
  end

  while word_end <= #line and line:sub(word_end, word_end):match('[%w%-_]') do
    word_end = word_end + 1
  end

  local word = line:sub(word_start, word_end - 1)

  if word and word ~= '' then
    -- Check if already a tag
    if word_start > 1 and line:sub(word_start - 1, word_start - 1) == '#' then
      vim.notify('Already a tag: ' .. word, vim.log.levels.INFO)
      return
    end

    -- Convert to tag
    local before = line:sub(1, word_start - 1)
    local after = line:sub(word_end)
    local new_line = before .. '#' .. word .. after

    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], word_start })
  else
    -- No word, prompt for tag name
    vim.ui.input({ prompt = 'Enter tag name: ' }, function(input)
      if input and input ~= '' then
        local new_line = line:sub(1, col - 1) .. '#' .. input .. line:sub(col)
        vim.api.nvim_set_current_line(new_line)
        vim.api.nvim_win_set_cursor(0, { vim.api.nvim_win_get_cursor(0)[1], col })
      end
    end)
  end
end

--- Delete tag under cursor
Tag.delete_tag_under_cursor = function()
  local tag = Tag.get_tag_under_cursor()

  if not tag then
    vim.notify('No tag under cursor', vim.log.levels.WARN)
    return
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  -- Find tag in line
  local tag_start, tag_end = line:find(vim.pesc(tag))

  if tag_start and tag_end then
    local before = line:sub(1, tag_start - 1)
    local after = line:sub(tag_end + 1)
    local new_line = before .. tag:sub(2) .. after -- Remove the # but keep the word

    vim.api.nvim_set_current_line(new_line)
    vim.notify('Removed tag: ' .. tag, vim.log.levels.INFO)
  end
end

--- Go to tag definition or search for tag
Tag.goto_tag = function()
  local tag = Tag.get_tag_under_cursor()

  if not tag then
    vim.notify('No tag under cursor', vim.log.levels.WARN)
    return
  end

  -- Use find module to search for this specific tag
  local find = require('down.mod').get_mod('find')
  if find then
    find.picker('tag')({ scope = 'workspace', default_text = tag })
  end
end

---@class down.mod.tag.Config
Tag.config = {}

--- Maps for tag operations
Tag.maps = {
  {
    'n',
    ',dt',
    '<cmd>Down tag<CR>',
    { desc = 'Show tags in buffer', silent = true },
  },
  {
    'n',
    ',dT',
    '<cmd>Down tag list<CR>',
    { desc = 'Show all tags in workspace', silent = true },
  },
}

return Tag
