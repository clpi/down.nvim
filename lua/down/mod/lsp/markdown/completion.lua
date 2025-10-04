local log = require("down.log")

---@class down.mod.lsp.markdown.Completion
local Completion = {}

---@type vim.lsp.Client
Completion.client = nil

---@type number
Completion.bufnr = nil

--- Setup completion provider
---@param client vim.lsp.Client
---@param bufnr number
Completion.setup = function(client, bufnr)
  Completion.client = client
  Completion.bufnr = bufnr

  log.trace("Setting up completion provider for buffer " .. bufnr)

  -- Register completion handler
  vim.lsp.handlers["textDocument/completion"] = function(err, result, ctx, config)
    if err then
      log.error("Completion error: " .. vim.inspect(err))
      return
    end

    return vim.lsp.handlers["textDocument/completion"](err, result, ctx, config)
  end
end

--- Get completion items
---@param params lsp.CompletionParams
---@return lsp.CompletionItem[]
Completion.get_items = function(params)
  local items = {}
  local bufnr = vim.api.nvim_get_current_buf()

  local line = vim.api.nvim_buf_get_lines(
    bufnr,
    params.position.line,
    params.position.line + 1,
    false
  )[1]

  if not line then
    return items
  end

  local col = params.position.character
  local before_cursor = line:sub(1, col)

  -- Tag completion
  if before_cursor:match("#%S*$") then
    vim.list_extend(items, Completion.get_tag_items(before_cursor))
  end

  -- Link completion
  if before_cursor:match("%[%[%S*$") or before_cursor:match("%]%(.*$") then
    vim.list_extend(items, Completion.get_link_items(before_cursor))
  end

  -- Date/time completion
  if before_cursor:match("@%S*$") then
    vim.list_extend(items, Completion.get_date_items(before_cursor))
  end

  -- Frontmatter/YAML completion
  if Completion.is_in_frontmatter(params.position.line) then
    vim.list_extend(items, Completion.get_frontmatter_items(before_cursor))
  end

  -- Heading/section symbols
  if before_cursor:match("##+%s*$") or before_cursor:match("^#+$") then
    vim.list_extend(items, Completion.get_heading_items(before_cursor))
  end

  -- Emoji completion
  if before_cursor:match(":%S*$") then
    vim.list_extend(items, Completion.get_emoji_items(before_cursor))
  end

  -- Reference-style links
  if before_cursor:match("%[%S*%]:%s*$") then
    vim.list_extend(items, Completion.get_reference_items(before_cursor))
  end

  -- Workspace symbols (@@workspace)
  if before_cursor:match("@@%S*$") then
    vim.list_extend(items, Completion.get_workspace_symbol_items(before_cursor))
  end

  -- Markdown syntax completion
  vim.list_extend(items, Completion.get_markdown_items(before_cursor))

  return items
end

--- Get tag completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_tag_items = function(before_cursor)
  local items = {}
  local mod = require("down.mod")
  local markdown_mod = mod.get_mod("lsp.markdown")

  if not markdown_mod then
    return items
  end

  local prefix = before_cursor:match("#(%S*)$") or ""

  for tag, instances in pairs(markdown_mod.data.tags) do
    if vim.startswith(tag, "#" .. prefix) then
      table.insert(items, {
        label = tag,
        kind = vim.lsp.protocol.CompletionItemKind.Keyword,
        detail = string.format("Used in %d places", #instances),
        documentation = {
          kind = vim.lsp.protocol.MarkupKind.Markdown,
          value = string.format(
            "Tag `%s`\n\n**Occurrences:** %d",
            tag,
            #instances
          ),
        },
        insertText = tag:sub(2), -- Remove the # since it's already typed
      })
    end
  end

  return items
end

--- Get link completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_link_items = function(before_cursor)
  local items = {}
  local mod = require("down.mod")
  local markdown_mod = mod.get_mod("lsp.markdown")

  if not markdown_mod then
    return items
  end

  local workspace = markdown_mod.dep.workspace
  local current_file = vim.fn.expand("%:p")

  for _, file in ipairs(markdown_mod.data.files) do
    if file ~= current_file then
      local filename = vim.fn.fnamemodify(file, ":t:r")
      local rel_path = vim.fn.fnamemodify(file, ":~:.")

      -- Read first few lines for preview
      local ok, lines = pcall(vim.fn.readfile, file, "", 5)
      local preview = ok and table.concat(lines, "\n") or ""

      table.insert(items, {
        label = filename,
        kind = vim.lsp.protocol.CompletionItemKind.File,
        detail = rel_path,
        documentation = {
          kind = vim.lsp.protocol.MarkupKind.Markdown,
          value = string.format("**%s**\n\n```markdown\n%s\n```", rel_path, preview),
        },
        insertText = filename,
        filterText = filename .. " " .. rel_path,
      })
    end
  end

  -- Add workspace completion
  for name, path in pairs(workspace.workspaces()) do
    table.insert(items, {
      label = "@" .. name,
      kind = vim.lsp.protocol.CompletionItemKind.Folder,
      detail = "Workspace: " .. path,
      documentation = {
        kind = vim.lsp.protocol.MarkupKind.Markdown,
        value = string.format("**Workspace:** %s\n\n**Path:** `%s`", name, path),
      },
      insertText = "@" .. name,
    })
  end

  return items
end

--- Get date/time completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_date_items = function(before_cursor)
  local items = {}
  local date = os.date("*t")

  local snippets = {
    {
      label = "@today",
      insertText = os.date("%Y-%m-%d"),
      detail = "Insert today's date",
    },
    {
      label = "@now",
      insertText = os.date("%Y-%m-%d %H:%M:%S"),
      detail = "Insert current date and time",
    },
    {
      label = "@time",
      insertText = os.date("%H:%M:%S"),
      detail = "Insert current time",
    },
    {
      label = "@yesterday",
      insertText = os.date("%Y-%m-%d", os.time(date) - 86400),
      detail = "Insert yesterday's date",
    },
    {
      label = "@tomorrow",
      insertText = os.date("%Y-%m-%d", os.time(date) + 86400),
      detail = "Insert tomorrow's date",
    },
    {
      label = "@week",
      insertText = os.date("%Y-W%V"),
      detail = "Insert week number",
    },
    {
      label = "@month",
      insertText = os.date("%Y-%m"),
      detail = "Insert year-month",
    },
    {
      label = "@year",
      insertText = os.date("%Y"),
      detail = "Insert year",
    },
  }

  for _, snippet in ipairs(snippets) do
    table.insert(items, {
      label = snippet.label,
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
      detail = snippet.detail,
      documentation = {
        kind = vim.lsp.protocol.MarkupKind.Markdown,
        value = string.format("**%s**\n\nInserts: `%s`", snippet.detail, snippet.insertText),
      },
      insertText = snippet.insertText,
    })
  end

  return items
end

--- Get markdown syntax completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_markdown_items = function(before_cursor)
  local items = {}

  local syntax_items = {
    {
      label = "heading",
      insertText = "# ${1:Heading}",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Insert heading",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "bold",
      insertText = "**${1:text}**",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Bold text",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "italic",
      insertText = "*${1:text}*",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Italic text",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "code",
      insertText = "`${1:code}`",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Inline code",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "codeblock",
      insertText = "```${1:language}\n${2:code}\n```",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Code block",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "link",
      insertText = "[${1:text}](${2:url})",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Markdown link",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "wikilink",
      insertText = "[[${1:page}]]",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Wiki-style link",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "image",
      insertText = "![${1:alt}](${2:url})",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Image",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "table",
      insertText = "| ${1:Header} | ${2:Header} |\n| --- | --- |\n| ${3:Cell} | ${4:Cell} |",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Table",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "task",
      insertText = "- [ ] ${1:task}",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Task checkbox",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "list",
      insertText = "- ${1:item}",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Unordered list",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "ordered",
      insertText = "1. ${1:item}",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Ordered list",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
    {
      label = "quote",
      insertText = "> ${1:quote}",
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      detail = "Blockquote",
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
    },
  }

  for _, item in ipairs(syntax_items) do
    table.insert(items, item)
  end

  return items
end

--- Check if position is in frontmatter
---@param line_num number
---@return boolean
Completion.is_in_frontmatter = function(line_num)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if line_num == 0 or not lines[1] or not lines[1]:match("^---") then
    return false
  end

  for i = 2, line_num + 1 do
    if lines[i] and lines[i]:match("^---") then
      return i > line_num + 1
    end
  end

  return true
end

--- Get frontmatter/YAML completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_frontmatter_items = function(before_cursor)
  local items = {}

  local frontmatter_keys = {
    { label = "title", insertText = "title: ", detail = "Document title" },
    { label = "author", insertText = "author: ", detail = "Author name" },
    { label = "date", insertText = "date: " .. os.date("%Y-%m-%d"), detail = "Document date" },
    { label = "tags", insertText = "tags: []", detail = "Tags array" },
    { label = "categories", insertText = "categories: []", detail = "Categories" },
    { label = "draft", insertText = "draft: false", detail = "Draft status" },
    { label = "description", insertText = "description: ", detail = "Document description" },
    { label = "keywords", insertText = "keywords: []", detail = "SEO keywords" },
    { label = "toc", insertText = "toc: true", detail = "Table of contents" },
    { label = "math", insertText = "math: true", detail = "Enable math rendering" },
    { label = "mermaid", insertText = "mermaid: true", detail = "Enable mermaid diagrams" },
  }

  for _, key in ipairs(frontmatter_keys) do
    table.insert(items, {
      label = key.label,
      kind = vim.lsp.protocol.CompletionItemKind.Property,
      detail = key.detail,
      insertText = key.insertText,
      documentation = {
        kind = vim.lsp.protocol.MarkupKind.Markdown,
        value = string.format("**Frontmatter:** %s\n\n%s", key.label, key.detail),
      },
    })
  end

  return items
end

--- Get heading/section completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_heading_items = function(before_cursor)
  local items = {}
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Extract existing headings
  for i, line in ipairs(lines) do
    local heading = line:match("^(#+%s+.+)$")
    if heading then
      local level = select(2, heading:gsub("#", ""))
      local text = heading:match("^#+%s+(.+)$")

      table.insert(items, {
        label = text,
        kind = vim.lsp.protocol.CompletionItemKind.Class,
        detail = string.format("Heading Level %d (Line %d)", level, i),
        insertText = text,
        documentation = {
          kind = vim.lsp.protocol.MarkupKind.Markdown,
          value = string.format("Jump to heading:\n\n%s", heading),
        },
      })
    end
  end

  return items
end

--- Get emoji completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_emoji_items = function(before_cursor)
  local items = {}

  local emojis = {
    { name = "smile", emoji = "😊", desc = "Smiling face" },
    { name = "heart", emoji = "❤️", desc = "Red heart" },
    { name = "thumbsup", emoji = "👍", desc = "Thumbs up" },
    { name = "fire", emoji = "🔥", desc = "Fire" },
    { name = "star", emoji = "⭐", desc = "Star" },
    { name = "check", emoji = "✅", desc = "Check mark" },
    { name = "cross", emoji = "❌", desc = "Cross mark" },
    { name = "warning", emoji = "⚠️", desc = "Warning" },
    { name = "info", emoji = "ℹ️", desc = "Information" },
    { name = "question", emoji = "❓", desc = "Question mark" },
    { name = "bulb", emoji = "💡", desc = "Light bulb" },
    { name = "rocket", emoji = "🚀", desc = "Rocket" },
    { name = "tada", emoji = "🎉", desc = "Party popper" },
    { name = "book", emoji = "📚", desc = "Books" },
    { name = "pencil", emoji = "✏️", desc = "Pencil" },
    { name = "computer", emoji = "💻", desc = "Laptop" },
    { name = "phone", emoji = "📱", desc = "Mobile phone" },
    { name = "email", emoji = "📧", desc = "Email" },
    { name = "calendar", emoji = "📅", desc = "Calendar" },
    { name = "clock", emoji = "🕐", desc = "Clock" },
  }

  local prefix = before_cursor:match(":(%S*)$") or ""

  for _, emoji in ipairs(emojis) do
    if vim.startswith(emoji.name, prefix) then
      table.insert(items, {
        label = ":" .. emoji.name .. ":",
        kind = vim.lsp.protocol.CompletionItemKind.Text,
        detail = emoji.emoji .. " " .. emoji.desc,
        insertText = emoji.emoji,
        documentation = {
          kind = vim.lsp.protocol.MarkupKind.Markdown,
          value = string.format("%s **%s**\n\n%s", emoji.emoji, emoji.name, emoji.desc),
        },
      })
    end
  end

  return items
end

--- Get reference-style link completion items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_reference_items = function(before_cursor)
  local items = {}
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Extract existing references
  for _, line in ipairs(lines) do
    local ref, url = line:match("^%[([^%]]+)%]:%s*(.+)$")
    if ref and url then
      table.insert(items, {
        label = ref,
        kind = vim.lsp.protocol.CompletionItemKind.Reference,
        detail = url,
        insertText = ref,
        documentation = {
          kind = vim.lsp.protocol.MarkupKind.Markdown,
          value = string.format("**Reference:** `[%s]`\n\n**URL:** %s", ref, url),
        },
      })
    end
  end

  return items
end

--- Get workspace symbol items
---@param before_cursor string
---@return lsp.CompletionItem[]
Completion.get_workspace_symbol_items = function(before_cursor)
  local items = {}
  local mod = require("down.mod")
  local markdown_mod = mod.get_mod("lsp.markdown")

  if not markdown_mod then
    return items
  end

  local workspace = markdown_mod.dep.workspace

  -- Workspace names
  for name, path in pairs(workspace.workspaces()) do
    table.insert(items, {
      label = "@@" .. name,
      kind = vim.lsp.protocol.CompletionItemKind.Module,
      detail = "Workspace: " .. path,
      insertText = name,
      documentation = {
        kind = vim.lsp.protocol.MarkupKind.Markdown,
        value = string.format("**Workspace Symbol**\n\n**Name:** %s\n**Path:** `%s`", name, path),
      },
    })
  end

  -- Add common symbols
  local symbols = {
    { name = "index", desc = "Workspace index file" },
    { name = "notes", desc = "Notes directory" },
    { name = "journal", desc = "Journal directory" },
    { name = "archive", desc = "Archive directory" },
    { name = "templates", desc = "Templates directory" },
  }

  for _, sym in ipairs(symbols) do
    table.insert(items, {
      label = "@@" .. sym.name,
      kind = vim.lsp.protocol.CompletionItemKind.Folder,
      detail = sym.desc,
      insertText = sym.name,
      documentation = {
        kind = vim.lsp.protocol.MarkupKind.Markdown,
        value = string.format("**Symbol:** `@@%s`\n\n%s", sym.name, sym.desc),
      },
    })
  end

  return items
end

return Completion
