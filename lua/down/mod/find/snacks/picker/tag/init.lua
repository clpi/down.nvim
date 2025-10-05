local function parse_tags(bufnr)
  local tags = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
  local filepath = vim.api.nvim_buf_get_name(bufnr or 0)

  for lnum, line in ipairs(lines) do
    -- Parse tags: #tag or #tag-with-dashes
    for tag in line:gmatch("#([%w%-_]+)") do
      table.insert(tags, {
        tag = "#" .. tag,
        line = lnum,
        col = line:find("#" .. vim.pesc(tag)),
        text = line:match("^%s*(.-)%s*$"), -- trim whitespace
        file = filepath,
      })
    end
  end

  return tags
end

local function parse_workspace_tags()
  local mod = require("down.mod")
  local workspace_mod = mod.get_mod("workspace")

  if not workspace_mod then
    return {}
  end

  local ws_path = workspace_mod.get_current_workspace_path()
  if not ws_path then
    return {}
  end

  -- Find all markdown files in workspace
  local files = vim.fn.globpath(ws_path, "**/*.md", false, true)
  local all_tags = {}

  for _, file in ipairs(files) do
    local bufnr = vim.fn.bufadd(file)
    vim.fn.bufload(bufnr)
    local tags = parse_tags(bufnr)

    for _, tag_info in ipairs(tags) do
      table.insert(all_tags, tag_info)
    end
  end

  return all_tags
end

local function tag_picker(opts)
  local snacks = require("snacks")
  opts = opts or {}
  opts.scope = opts.scope or "buffer" -- buffer, workspace, or all

  local tags = {}

  if opts.scope == "buffer" then
    tags = parse_tags(0)
  elseif opts.scope == "workspace" then
    tags = parse_workspace_tags()
  end

  if #tags == 0 then
    vim.notify("No tags found", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, tag in ipairs(tags) do
    local filename = vim.fn.fnamemodify(tag.file, ":t")
    table.insert(items, {
      text = string.format("%s %s:%s - %s", tag.tag, tag.line, tag.col, filename),
      line = tag.line,
      col = tag.col,
      file = tag.file,
      tag = tag.tag,
    })
  end

  snacks.picker({
    source = items,
    prompt = "Tags (" .. opts.scope .. ")",
    format = function(item)
      return item.text
    end,
    confirm = function(item)
      if item then
        vim.cmd("edit " .. item.file)
        vim.api.nvim_win_set_cursor(0, { item.line, item.col - 1 })
        vim.cmd("normal! zz")
      end
    end,
  })
end

return tag_picker
