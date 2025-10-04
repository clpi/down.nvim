local log = require("down.log")

---@class down.mod.lsp.markdown.Hints
local Hints = {}

---@type number
Hints.bufnr = nil

---@type number
Hints.namespace = nil

--- Setup inlay hints provider
---@param bufnr number
Hints.setup = function(bufnr)
  Hints.bufnr = bufnr
  Hints.namespace = vim.api.nvim_create_namespace("down.lsp.markdown.hints")

  log.trace("Setting up inlay hints provider for buffer " .. bufnr)

  -- Set up autocommand to refresh hints
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      Hints.refresh(bufnr)
    end,
  })
end

--- Apply inlay hints to buffer using extmarks
---@param bufnr number
Hints.apply_hints = function(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear existing hints
  vim.api.nvim_buf_clear_namespace(bufnr, Hints.namespace, 0, -1)

  local mod = require("down.mod")
  local markdown_mod = mod.get_mod("lsp.markdown")

  if not markdown_mod then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_file = vim.api.nvim_buf_get_name(bufnr)

  for line_num, line in ipairs(lines) do
    -- Backlink hints
    Hints.apply_backlink_hints(bufnr, line, line_num, current_file, markdown_mod)

    -- Tag metadata hints
    Hints.apply_tag_hints(bufnr, line, line_num, markdown_mod)

    -- Link preview hints
    Hints.apply_link_hints(bufnr, line, line_num, markdown_mod)
  end
end

--- Apply backlink hints for a line
---@param bufnr number
---@param line string
---@param line_num number
---@param current_file string
---@param markdown_mod down.mod.lsp.markdown.Markdown
Hints.apply_backlink_hints = function(bufnr, line, line_num, current_file, markdown_mod)
  -- Check for headings to show backlinks
  local heading = line:match("^(#+)%s+(.+)$")
  if not heading then
    return
  end

  local backlinks = markdown_mod.data.backlinks
  local backlink_count = 0

  for file, _ in pairs(backlinks) do
    backlink_count = backlink_count + 1
  end

  if backlink_count > 0 then
    vim.api.nvim_buf_set_extmark(bufnr, Hints.namespace, line_num - 1, #line, {
      virt_text = { { string.format(" ← %d backlink%s", backlink_count, backlink_count == 1 and "" or "s"), "Comment" } },
      virt_text_pos = "eol",
    })
  end
end

--- Apply tag metadata hints
---@param bufnr number
---@param line string
---@param line_num number
---@param markdown_mod down.mod.lsp.markdown.Markdown
Hints.apply_tag_hints = function(bufnr, line, line_num, markdown_mod)
  for start_col, tag in line:gmatch("()#(%S+)") do
    local tag_data = markdown_mod.data.tags["#" .. tag]
    if tag_data and #tag_data > 1 then -- More than current occurrence
      local count = #tag_data - 1 -- Exclude current

      -- Place hint after the tag
      local col = start_col + #tag
      vim.api.nvim_buf_set_extmark(bufnr, Hints.namespace, line_num - 1, col, {
        virt_text = { { string.format(" (%d)", count), "Comment" } },
        virt_text_pos = "inline",
      })
    end
  end
end

--- Apply link preview hints
---@param bufnr number
---@param line string
---@param line_num number
---@param markdown_mod down.mod.lsp.markdown.Markdown
Hints.apply_link_hints = function(bufnr, line, line_num, markdown_mod)
  -- Wiki links [[page]]
  for start_col, link in line:gmatch("()%[%[([^%]]+)%]%]") do
    local link_file = Hints.find_link_file(link, markdown_mod)
    if link_file then
      local col = start_col + #link + 3 -- After ]]
      vim.api.nvim_buf_set_extmark(bufnr, Hints.namespace, line_num - 1, col, {
        virt_text = { { " →", "Special" } },
        virt_text_pos = "inline",
      })
    end
  end

  -- Markdown links [text](url)
  for start_col, text, url in line:gmatch("()%[([^%]]+)%]%(([^%)]+)%)") do
    if not url:match("^https?://") then
      local link_file = Hints.find_link_file(url, markdown_mod)
      if link_file then
        local col = start_col + #text + #url + 4 -- After )
        vim.api.nvim_buf_set_extmark(bufnr, Hints.namespace, line_num - 1, col, {
          virt_text = { { " →", "Special" } },
          virt_text_pos = "inline",
        })
      end
    end
  end
end

--- Find file path for link
---@param link string
---@param markdown_mod down.mod.lsp.markdown.Markdown
---@return string?
Hints.find_link_file = function(link, markdown_mod)
  local current_dir = vim.fn.expand("%:p:h")

  for _, file in ipairs(markdown_mod.data.files) do
    local filename = vim.fn.fnamemodify(file, ":t:r")
    if filename == link or file:match(link .. "%.md$") then
      return file
    end
  end

  -- Try relative path
  local rel_path = vim.fn.resolve(vim.fs.joinpath(current_dir, link))
  if vim.fn.filereadable(rel_path) == 1 then
    return rel_path
  end

  if vim.fn.filereadable(rel_path .. ".md") == 1 then
    return rel_path .. ".md"
  end

  return nil
end

--- Refresh inlay hints
---@param bufnr number
Hints.refresh = function(bufnr)
  vim.schedule(function()
    Hints.apply_hints(bufnr)
  end)
end

return Hints
