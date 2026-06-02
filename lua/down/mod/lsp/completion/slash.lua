--- Slash command (/) completion source for down.nvim
--- Provides Notion-like slash commands for inserting markdown blocks
---@class down.mod.lsp.completion.Slash
local Slash = {}

--- All available slash commands, organized by category
---@type table<string, table[]>
Slash.commands = {
  --- Basic blocks
  basic = {
    {
      label = "/text",
      icon = "󰦨",
      detail = "Plain text",
      documentation = "Insert a plain text paragraph",
      insert_text = "",
      kind = "Text",
      category = "Basic",
    },
    {
      label = "/heading1",
      icon = "󰉫",
      detail = "Heading 1",
      documentation = "Insert a level 1 heading",
      insert_text = "# ",
      kind = "Heading",
      category = "Basic",
    },
    {
      label = "/heading2",
      icon = "󰉬",
      detail = "Heading 2",
      documentation = "Insert a level 2 heading",
      insert_text = "## ",
      kind = "Heading",
      category = "Basic",
    },
    {
      label = "/heading3",
      icon = "󰉭",
      detail = "Heading 3",
      documentation = "Insert a level 3 heading",
      insert_text = "### ",
      kind = "Heading",
      category = "Basic",
    },
    {
      label = "/heading4",
      icon = "󰉮",
      detail = "Heading 4",
      documentation = "Insert a level 4 heading",
      insert_text = "#### ",
      kind = "Heading",
      category = "Basic",
    },
    {
      label = "/bullet",
      icon = "",
      detail = "Bullet list",
      documentation = "Insert a bullet list item",
      insert_text = "- ",
      kind = "List",
      category = "Basic",
    },
    {
      label = "/numbered",
      icon = "",
      detail = "Numbered list",
      documentation = "Insert a numbered list item",
      insert_text = "1. ",
      kind = "List",
      category = "Basic",
    },
    {
      label = "/checklist",
      icon = "󰄲",
      detail = "To-do / Checklist",
      documentation = "Insert a checkbox item",
      insert_text = "- [ ] ",
      kind = "List",
      category = "Basic",
    },
    {
      label = "/toggle",
      icon = "󰅀",
      detail = "Toggle list",
      documentation = "Insert a collapsible toggle section",
      insert_text = "<details>\n<summary>Toggle title</summary>\n\nContent here...\n\n</details>\n",
      kind = "Block",
      category = "Basic",
    },
    {
      label = "/quote",
      icon = "󰝗",
      detail = "Quote block",
      documentation = "Insert a blockquote",
      insert_text = "> ",
      kind = "Block",
      category = "Basic",
    },
    {
      label = "/divider",
      icon = "󰇘",
      detail = "Horizontal divider",
      documentation = "Insert a horizontal rule",
      insert_text = "\n---\n\n",
      kind = "Block",
      category = "Basic",
    },
    {
      label = "/link",
      icon = "󰌹",
      detail = "Link",
      documentation = "Insert a markdown link",
      insert_text = "[${1:text}](${2:url})",
      kind = "Inline",
      category = "Basic",
      snippet = true,
    },
    {
      label = "/page",
      icon = "󰎞",
      detail = "Link to page",
      documentation = "Create a link to another page in workspace",
      insert_text = "[[${1:page}]]",
      kind = "Inline",
      category = "Basic",
      snippet = true,
    },
  },

  --- Media & embeds
  media = {
    {
      label = "/image",
      icon = "󰋩",
      detail = "Image",
      documentation = "Insert an image",
      insert_text = "![${1:alt text}](${2:url})",
      kind = "Media",
      category = "Media",
      snippet = true,
    },
    {
      label = "/video",
      icon = "󰕧",
      detail = "Video embed",
      documentation = "Insert a video embed",
      insert_text = "[![${1:Video}](${2:thumbnail_url})](${3:video_url})",
      kind = "Media",
      category = "Media",
      snippet = true,
    },
    {
      label = "/embed",
      icon = "󰅱",
      detail = "Embed / iframe",
      documentation = "Insert an embedded content block",
      insert_text = '<iframe src="${1:url}" width="100%" height="400"></iframe>\n',
      kind = "Media",
      category = "Media",
      snippet = true,
    },
    {
      label = "/file",
      icon = "󰈔",
      detail = "File attachment",
      documentation = "Insert a file link",
      insert_text = "[📎 ${1:filename}](${2:path})",
      kind = "Media",
      category = "Media",
      snippet = true,
    },
  },

  --- Code & technical
  code = {
    {
      label = "/code",
      icon = "",
      detail = "Code block",
      documentation = "Insert a fenced code block",
      insert_text = "```${1:language}\n${2:code}\n```\n",
      kind = "Code",
      category = "Code",
      snippet = true,
    },
    {
      label = "/inline",
      icon = "",
      detail = "Inline code",
      documentation = "Insert inline code",
      insert_text = "`${1:code}`",
      kind = "Code",
      category = "Code",
      snippet = true,
    },
    {
      label = "/math",
      icon = "󰍘",
      detail = "Math block (LaTeX)",
      documentation = "Insert a LaTeX math block",
      insert_text = "$$\n${1:equation}\n$$\n",
      kind = "Code",
      category = "Code",
      snippet = true,
    },
    {
      label = "/inlinemath",
      icon = "󰍘",
      detail = "Inline math",
      documentation = "Insert inline LaTeX math",
      insert_text = "$${1:expr}$",
      kind = "Code",
      category = "Code",
      snippet = true,
    },
    {
      label = "/mermaid",
      icon = "󱁉",
      detail = "Mermaid diagram",
      documentation = "Insert a Mermaid diagram block",
      insert_text = "```mermaid\n${1:graph TD}\n    ${2:A --> B}\n```\n",
      kind = "Code",
      category = "Code",
      snippet = true,
    },
  },

  --- Tables & data
  data = {
    {
      label = "/table",
      icon = "󰓫",
      detail = "Table",
      documentation = "Insert a markdown table",
      insert_text = "| ${1:Header 1} | ${2:Header 2} | ${3:Header 3} |\n| --- | --- | --- |\n| ${4:Cell} | ${5:Cell} | ${6:Cell} |\n",
      kind = "Data",
      category = "Data",
      snippet = true,
    },
    {
      label = "/table2",
      icon = "󰓫",
      detail = "2-column table",
      documentation = "Insert a 2-column table",
      insert_text = "| ${1:Column 1} | ${2:Column 2} |\n| --- | --- |\n| ${3:} | ${4:} |\n",
      kind = "Data",
      category = "Data",
      snippet = true,
    },
    {
      label = "/table3",
      icon = "󰓫",
      detail = "3-column table",
      documentation = "Insert a 3-column table",
      insert_text = "| ${1:Col 1} | ${2:Col 2} | ${3:Col 3} |\n| --- | --- | --- |\n| ${4:} | ${5:} | ${6:} |\n",
      kind = "Data",
      category = "Data",
      snippet = true,
    },
  },

  --- Callouts & admonitions
  callout = {
    {
      label = "/callout",
      icon = "󰋼",
      detail = "Callout / Admonition",
      documentation = "Insert a callout block (info)",
      insert_text = "> [!NOTE]\n> ${1:Note content}\n",
      kind = "Callout",
      category = "Callout",
      snippet = true,
    },
    {
      label = "/tip",
      icon = "󰌵",
      detail = "Tip callout",
      documentation = "Insert a tip callout block",
      insert_text = "> [!TIP]\n> ${1:Tip content}\n",
      kind = "Callout",
      category = "Callout",
      snippet = true,
    },
    {
      label = "/warning",
      icon = "",
      detail = "Warning callout",
      documentation = "Insert a warning callout block",
      insert_text = "> [!WARNING]\n> ${1:Warning content}\n",
      kind = "Callout",
      category = "Callout",
      snippet = true,
    },
    {
      label = "/important",
      icon = "󰀦",
      detail = "Important callout",
      documentation = "Insert an important callout block",
      insert_text = "> [!IMPORTANT]\n> ${1:Important content}\n",
      kind = "Callout",
      category = "Callout",
      snippet = true,
    },
    {
      label = "/caution",
      icon = "󱈸",
      detail = "Caution callout",
      documentation = "Insert a caution callout block",
      insert_text = "> [!CAUTION]\n> ${1:Caution content}\n",
      kind = "Callout",
      category = "Callout",
      snippet = true,
    },
    {
      label = "/success",
      icon = "󰄬",
      detail = "Success callout",
      documentation = "Insert a success note",
      insert_text = "> [!NOTE] ✅ Success\n> ${1:Success content}\n",
      kind = "Callout",
      category = "Callout",
      snippet = true,
    },
  },

  --- Organization & structure
  structure = {
    {
      label = "/toc",
      icon = "󰠶",
      detail = "Table of Contents",
      documentation = "Insert a table of contents marker",
      insert_text = "## Table of Contents\n\n<!-- toc -->\n\n",
      kind = "Structure",
      category = "Structure",
    },
    {
      label = "/frontmatter",
      icon = "󰿟",
      detail = "YAML Frontmatter",
      documentation = "Insert YAML frontmatter block",
      insert_text = "---\ntitle: ${1:Title}\ndate: ${2:" .. os.date("%Y-%m-%d") .. "}\ntags: [${3:}]\n---\n\n",
      kind = "Structure",
      category = "Structure",
      snippet = true,
    },
    {
      label = "/footnote",
      icon = "󰆒",
      detail = "Footnote",
      documentation = "Insert a footnote reference and definition",
      insert_text = "[^${1:note}]\n\n[^${1:note}]: ${2:Footnote text}\n",
      kind = "Structure",
      category = "Structure",
      snippet = true,
    },
    {
      label = "/comment",
      icon = "󰅺",
      detail = "Comment (hidden)",
      documentation = "Insert an HTML comment (not rendered)",
      insert_text = "<!-- ${1:comment} -->\n",
      kind = "Structure",
      category = "Structure",
      snippet = true,
    },
  },

  --- Task & productivity
  productivity = {
    {
      label = "/task",
      icon = "󰄱",
      detail = "Task item",
      documentation = "Insert a task checkbox",
      insert_text = "- [ ] ",
      kind = "Task",
      category = "Productivity",
    },
    {
      label = "/done",
      icon = "󰄲",
      detail = "Completed task",
      documentation = "Insert a completed task",
      insert_text = "- [x] ",
      kind = "Task",
      category = "Productivity",
    },
    {
      label = "/progress",
      icon = "󰦖",
      detail = "In-progress task",
      documentation = "Insert an in-progress task",
      insert_text = "- [-] ",
      kind = "Task",
      category = "Productivity",
    },
    {
      label = "/date",
      icon = "󰃭",
      detail = "Today's date",
      documentation = "Insert today's date",
      insert_text = os.date("%Y-%m-%d"),
      kind = "Date",
      category = "Productivity",
    },
    {
      label = "/time",
      icon = "󰅐",
      detail = "Current time",
      documentation = "Insert current time",
      insert_text = os.date("%H:%M"),
      kind = "Date",
      category = "Productivity",
    },
    {
      label = "/datetime",
      icon = "󰃰",
      detail = "Date and time",
      documentation = "Insert current date and time",
      insert_text = os.date("%Y-%m-%d %H:%M"),
      kind = "Date",
      category = "Productivity",
    },
    {
      label = "/tag",
      icon = "󰓹",
      detail = "Insert tag",
      documentation = "Insert a hashtag",
      insert_text = "#${1:tag}",
      kind = "Tag",
      category = "Productivity",
      snippet = true,
    },
  },

  --- Templates
  template = {
    {
      label = "/meeting",
      icon = "󰤙",
      detail = "Meeting notes template",
      documentation = "Insert a meeting notes template",
      insert_text = table.concat({
        "## Meeting Notes - " .. os.date("%Y-%m-%d"),
        "",
        "### Attendees",
        "- ",
        "",
        "### Agenda",
        "1. ",
        "",
        "### Discussion",
        "",
        "",
        "### Action Items",
        "- [ ] ",
        "",
      }, "\n"),
      kind = "Template",
      category = "Template",
    },
    {
      label = "/daily",
      icon = "󰃭",
      detail = "Daily note template",
      documentation = "Insert a daily note template",
      insert_text = table.concat({
        "## " .. os.date("%A, %B %d, %Y"),
        "",
        "### Goals for Today",
        "- [ ] ",
        "",
        "### Notes",
        "",
        "",
        "### End of Day Review",
        "- What went well: ",
        "- What to improve: ",
        "",
      }, "\n"),
      kind = "Template",
      category = "Template",
    },
    {
      label = "/weekly",
      icon = "󰨜",
      detail = "Weekly review template",
      documentation = "Insert a weekly review template",
      insert_text = table.concat({
        "## Weekly Review - Week of " .. os.date("%Y-%m-%d"),
        "",
        "### Accomplishments",
        "- ",
        "",
        "### In Progress",
        "- ",
        "",
        "### Blockers",
        "- ",
        "",
        "### Goals for Next Week",
        "- [ ] ",
        "",
      }, "\n"),
      kind = "Template",
      category = "Template",
    },
    {
      label = "/project",
      icon = "󰳐",
      detail = "Project page template",
      documentation = "Insert a project documentation template",
      insert_text = table.concat({
        "# ${1:Project Name}",
        "",
        "## Overview",
        "${2:Brief description}",
        "",
        "## Status",
        "- **Status:** 🟡 In Progress",
        "- **Priority:** Medium",
        "- **Due:** ${3:YYYY-MM-DD}",
        "",
        "## Goals",
        "- [ ] ",
        "",
        "## Resources",
        "- ",
        "",
        "## Notes",
        "",
        "",
      }, "\n"),
      kind = "Template",
      category = "Template",
      snippet = true,
    },
  },
}

--- Get all slash command items, optionally filtered by query
---@param parent table The parent completion module
---@param query? string Optional filter query
---@return table[]
Slash.get_items = function(parent, query)
  local items = {}

  for _, category in pairs(Slash.commands) do
    for _, cmd in ipairs(category) do
      local item = {
        label = (cmd.icon or "") .. " " .. cmd.label,
        detail = cmd.detail,
        documentation = cmd.documentation,
        insert_text = cmd.insert_text,
        kind = cmd.kind or "Snippet",
        category = cmd.category,
        snippet = cmd.snippet,
        filter_text = cmd.label:lower(),
      }
      -- Filter by query if provided
      if query and query ~= "" then
        local q = query:lower()
        if item.filter_text:find(q, 1, true)
          or (cmd.detail and cmd.detail:lower():find(q, 1, true))
          or (cmd.category and cmd.category:lower():find(q, 1, true)) then
          table.insert(items, item)
        end
      else
        table.insert(items, item)
      end
    end
  end

  -- Sort: exact prefix matches first, then alphabetical
  table.sort(items, function(a, b)
    if query and query ~= "" then
      local q = query:lower()
      local a_starts = a.filter_text:find("/" .. q, 1, true) == 1
      local b_starts = b.filter_text:find("/" .. q, 1, true) == 1
      if a_starts and not b_starts then
        return true
      elseif b_starts and not a_starts then
        return false
      end
    end
    return a.filter_text < b.filter_text
  end)

  -- Limit results
  local max = (parent and parent.config and parent.config.max_items) or 20
  if #items > max then
    local limited = {}
    for i = 1, max do
      limited[i] = items[i]
    end
    return limited
  end

  return items
end

return Slash
