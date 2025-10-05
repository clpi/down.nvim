local function parse_links(bufnr)
  local links = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)

  for lnum, line in ipairs(lines) do
    -- Parse wikilinks [[link]]
    for link in line:gmatch("%[%[([^%]]+)%]%]") do
      table.insert(links, {
        text = link,
        line = lnum,
        col = line:find("%[%[" .. vim.pesc(link)),
        type = "wikilink",
        preview = line,
      })
    end

    -- Parse markdown links [text](link)
    for text, link in line:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
      table.insert(links, {
        text = link,
        display_text = text,
        line = lnum,
        col = line:find("%[" .. vim.pesc(text)),
        type = "markdown",
        preview = line,
      })
    end

    -- Parse autolinks <link>
    for link in line:gmatch("<([^>]+)>") do
      table.insert(links, {
        text = link,
        line = lnum,
        col = line:find("<" .. vim.pesc(link)),
        type = "autolink",
        preview = line,
      })
    end
  end

  return links
end

local function markdown_links_picker(opts)
  local snacks = require("snacks")
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local links = parse_links(bufnr)

  if #links == 0 then
    vim.notify("No links found in current buffer", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, link in ipairs(links) do
    table.insert(items, {
      text = string.format("[%s] %s:%s - %s", link.type, link.line, link.col, link.text),
      line = link.line,
      col = link.col,
      file = vim.api.nvim_buf_get_name(bufnr),
    })
  end

  snacks.picker({
    source = items,
    prompt = "Links in Buffer",
    format = function(item)
      return item.text
    end,
    confirm = function(item)
      if item then
        vim.api.nvim_win_set_cursor(0, { item.line, item.col - 1 })
        vim.cmd("normal! zz")
      end
    end,
  })
end

return markdown_links_picker
