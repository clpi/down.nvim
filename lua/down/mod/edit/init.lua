local down = require 'down'
local mod = require 'down.mod'
local log = require 'down.util.log'
local utils = require 'down.util'

---@type down.Editod
local Edit = mod.new('edit', { 'cursor', 'indent' })

Edit.setup = function()
  return {
    loaded = true,
    dependencies = {
      'edit.cursor',
      'edit.indent',
    },
  }
end

---@class down.mod.edit.Config
Edit.config = {
  silent = false,
  wrap = false,
  continue = true, ---@type boolean | nil
  context = 0,
  jump_patterns = { '%[.*%]%(.-%)' },
}

Edit.find_patterns = function(str, patterns, reverse, init)
  reverse = reverse or false
  patterns = type(patterns) == 'table' and patterns or { patterns }
  str = (reverse and init and str:sub(1, init)) or str
  local left, right, left_tmp, right_tmp
  for i = 1, #patterns, 1 do
    left_tmp, right_tmp = str:find(patterns[i], reverse and 1 or init)
    if reverse then
      local left_check, right_check = left_tmp, right_tmp
      while left_check do
        left_check, right_check = str:find(patterns[i], left_tmp + 1)
        if left_check then
          left_tmp, right_tmp = left_check, right_check
        end
      end
    end
    if left_tmp and (left == nil or ((reverse and left_tmp > left) or left_tmp < left)) then
      left, right = left_tmp, right_tmp
    end
  end
  return left, right
end

Edit.jump = function(pattern, reverse)
  local position = vim.api.nvim_win_get_cursor(0)
  local row, col = position[1], position[2]
  local line, line_len, left, right
  local already_wrapped = false
  line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  line_len = #line
  if Edit.config.context > 0 and line_len > 0 then
    for i = 1, Edit.config.context, 1 do
      local following_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
      line = (following_line and line .. following_line) or line
    end
  end
  left, right = Edit.find_patterns(line, pattern, reverse, col)
  local continue = true
  while continue do
    if left and right then
      if
          ((reverse and col + 1 > left) or ((not reverse) and col + 1 < left))
          and left <= line_len
      then
        vim.api.nvim_win_set_cursor(0, { row, left - 1 })
        continue = false
      else
        left, right = Edit.find_patterns(line, pattern, reverse, reverse and left or right)
      end
    else
      row = (reverse and row - 1) or row + 1
      line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
      line_len = line and #line
      col = reverse and line_len or -1
      if line and Edit.config.context > 0 and line_len > 0 then
        for i = 1, Edit.config.context, 1 do
          local following_line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
          line = (following_line and line .. following_line) or line
        end
      end
      if line then
        left, right = Edit.find_patterns(line, pattern, reverse)
      else
        if Edit.config.wrap == true then
          if not already_wrapped then
            row = (reverse and vim.api.nvim_buf_line_count(0) + 1) or 0
            already_wrapped = true
          else
            Edit.config.continue = nil
          end
        else
          Edit.config.continue = nil
        end
      end
    end
  end
end

Edit.go_to_heading = function(anchor_text, reverse)
  local position = vim.api.nvim_win_get_cursor(0)
  local starting_row, continue = position[1], true
  local in_fenced_code_block = Edit.dep['edit.cursor'].in_codeblock(starting_row, reverse)
  local row = (reverse and starting_row - 1) or starting_row + 1
  while continue do
    local line = (reverse and vim.api.nvim_buf_get_lines(0, row - 1, row, false))
        or vim.api.nvim_buf_get_lines(0, row - 1, row, false)
    if line[1] then
      if line[1]:find '^```' then
        in_fenced_code_block = not in_fenced_code_block
      end
      local has_heading = line[1]:find '^#'
      if has_heading and not in_fenced_code_block then
        if anchor_text == nil then
          vim.api.nvim_win_set_cursor(0, { row, 0 })
          continue = false
        else
          local heading_as_anchor = Edit.dep['link'].format_link(line[1], nil, 2)
          if anchor_text == heading_as_anchor then
            vim.api.nvim_buf_set_mark(0, '`', position[1], position[2], {})
            vim.api.nvim_win_set_cursor(0, { row, 0 })
            continue = false
          end
        end
      end
      row = (reverse and row - 1) or row + 1
      if row == starting_row + 1 then
        Edit.config.continue = nil
        if anchor_text == nil then
          local message = "⬇️  Couldn't find a heading to go to!"
          if not Edit.config.silent then
            vim.api.nvim_echo({ { message, 'WarningEditsg' } }, true, {})
          end
        else
          local message = "⬇️  Couldn't find a heading matching " .. anchor_text .. '!'
          if not Edit.config.silent then
            vim.api.nvim_echo({ { message, 'WarningEditsg' } }, true, {})
          end
        end
      end
    else
      if anchor_text ~= nil or wrap == true then
        row = (reverse and vim.api.nvim_buf_line_count(0)) or 1
        in_fenced_code_block = false
      else
        Edit.config.continue = nil
        local place = (reverse and 'beginning') or 'end'
        local preposition = (reverse and 'after') or 'before'
        local message = '⬇️  There are no more headings '
            .. preposition
            .. ' the '
            .. place
            .. ' of the document!'
        if not silent then
          vim.api.nvim_echo({ { message, 'WarningEditsg' } }, true, {})
        end
      end
    end
  end
end

Edit.go_to_id = function(id, starting_row)
  starting_row = starting_row or vim.api.nvim_win_get_cursor(0)[1]
  local continue = true
  local row, line_count = starting_row, vim.api.nvim_buf_line_count(0)
  local start, finish
  while continue and row <= line_count do
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    start, finish = line:find '%b[]%b{}'
    if not start and not finish then
      start, finish = line:find '%s*#+.*%b{}%s*$'
    end
    if start then
      local substring = line:sub(start, finish)
      if substring:match('{[^%}]*' .. utils.luaEscape(id) .. '[^%}]*}') then
        continue = false
      else
        local continue_line = true
        while continue_line do
          start, finish = line:find('%b[]%b{}', finish)
          if start then
            substring = line:sub(start, finish)
            if substring:match('{[^%}]*' .. utils.luaEscape(id) .. '[^%}]*}') then
              continue_line = false
              continue = false
            end
          else
            continue_line = false
            row = row + 1
          end
        end
      end
    else
      row = row + 1
    end
  end
  if start and finish then
    vim.api.nvim_win_set_cursor(0, { row, start - 1 })
    return true
  else
    return false
  end
end

Edit.changeHeadingLevel = function(change)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
  local is_heading = line[1]:find '^#'
  if is_heading then
    if change == 'decrease' then
      vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, 0, { '#' })
    else
      if not line[1]:find '^##' then
        local message = "⬇️  Can't increase this heading any more!"
        if not Edit.config.silent then
          vim.api.nvim_echo({ { message, 'WarningEditsg' } }, true, {})
        end
      else
        vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, 1, { '' })
      end
    end
  end
end

Edit.toNextLink = function(pattern)
  Edit.jump(Edit.jump_patterns[pattern])
end

Edit.toPrevLink = function(pattern)
  Edit.jump(Edit.jump_patterns[pattern], true)
end

Edit.toHeading = function(anchor_text, reverse)
  Edit.go_to_heading(anchor_text, reverse)
end

Edit.toId = function(id, starting_row)
  return Edit.go_to_id(id, starting_row)
end

Edit.yankAsAnchorLink = function(full_path)
  full_path = full_path or false
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
  local is_heading = line[1]:find '^#'
  local is_bracketed_span = Edit.dep.link.destination()
  if is_heading then
    local anchor_link = Edit.dep.link.format_link(line[1])
    anchor_link = anchor_link[1]:gsub('"', '\\"')
    if full_path then
      local buffer = vim.api.nvim_buf_get_name(0)
      local left = anchor_link:match '(%b[]%()#'
      local right = anchor_link:match '%b[]%((#.*)$'
      anchor_link = left .. buffer .. right
      vim.cmd('let @"="' .. anchor_link .. '"')
    else
      vim.cmd('let @"="' .. anchor_link .. '"')
    end
  elseif is_bracketed_span then
    local name = Edit.dep['link'].destination 'text'
    local attr = is_bracketed_span
    local anchor_link
    if name and attr then
      if full_path then
        local buffer = vim.api.nvim_buf_get_name(0)
        anchor_link = '[' .. name .. ']' .. '(' .. buffer .. attr .. ')'
      else
        anchor_link = '[' .. name .. ']' .. '(' .. attr .. ')'
      end
      vim.cmd('let @"="' .. anchor_link .. '"')
    end
  else
    local message = '⬇️  The current line is not a heading or bracketed span!'
    if not Edit.config.silent then
      vim.api.nvim_echo({ { message, 'WarningEditsg' } }, true, {})
    end
  end
end

return Edit
