# Markdown LSP Module - Usage Guide

## Quick Start

1. **Enable the module** in your down.nvim configuration:

```lua
require("down").setup({
  workspace = {
    default = "notes",
    workspaces = {
      notes = "~/notes",
    },
  },
  lsp = {}, -- This loads the LSP module (enabled by default)
})
```

**To disable:**
```lua
require("down").setup({
  ["lsp.markdown"] = {
    config = { enabled = false }
  }
})
```

2. **Open a markdown file** in your workspace:

```bash
nvim ~/notes/my-note.md
```

3. **The module automatically activates** - you'll see in `:messages`:
   ```
   Loading lsp.markdown module
   Attaching markdown features to buffer X
   Markdown LSP features attached to buffer X
   ```

## Features

### 1. Tag Completion

Type `#` followed by `<C-x><C-o>` to see existing tags:

```markdown
#proj<C-x><C-o>
```

Shows:
- `#project` (Used in 5 places)
- `#programming` (Used in 3 places)
- `#productivity` (Used in 2 places)

### 2. Link Completion

Type `[[` followed by `<C-x><C-o>` to see workspace files:

```markdown
[[doc<C-x><C-o>
```

Shows:
- `documentation` (./docs/documentation.md)
- `docker-notes` (./tech/docker-notes.md)

### 3. Date/Time Snippets

Type `@` followed by `<C-x><C-o>` for date shortcuts:

```markdown
Created: @tod<C-x><C-o>
```

Shows:
- `@today` → `2025-10-03`
- `@now` → `2025-10-03 19:45:30`
- `@yesterday` → `2025-10-02`
- `@tomorrow` → `2025-10-04`
- `@week` → `2025-W40`
- `@month` → `2025-10`
- `@year` → `2025`

### 4. Markdown Syntax Snippets

Type any snippet name followed by `<C-x><C-o>`:

```markdown
head<C-x><C-o>  → # Heading
bold<C-x><C-o>  → **text**
code<C-x><C-o>  → `code`
link<C-x><C-o>  → [text](url)
table<C-x><C-o> → Table template
```

### 5. Frontmatter/YAML Completion

Inside frontmatter (between `---`), get field completions:

```yaml
---
title<C-x><C-o>  → title:
date<C-x><C-o>   → date: 2025-10-03
tags<C-x><C-o>   → tags: []
---
```

Available fields:
- `title`, `author`, `date`, `tags`, `categories`
- `draft`, `description`, `keywords`
- `toc`, `math`, `mermaid`

### 6. Heading/Section Symbols

Jump to existing headings in the document:

```markdown
## <C-x><C-o>
```

Shows list of all headings in the current document.

### 7. Emoji Completion

Type `:` followed by emoji name:

```markdown
Great work :fire<C-x><C-o>  → Great work 🔥
```

Available emojis:
- `:smile:` 😊, `:heart:` ❤️, `:thumbsup:` 👍
- `:fire:` 🔥, `:star:` ⭐, `:check:` ✅
- `:rocket:` 🚀, `:tada:` 🎉, `:bulb:` 💡
- And many more!

### 8. Workspace Symbols

Reference workspace elements with `@@`:

```markdown
See @@notes<C-x><C-o>  → Lists all workspaces
Link to @@index<C-x><C-o>  → Workspace index
```

### 9. Reference-Style Links

Auto-complete existing reference definitions:

```markdown
[link][ref<C-x><C-o>]

[ref]: https://example.com
```

### 10. Semantic Highlighting

Automatic syntax highlighting for:
- **Tags**: `#tag` highlighted as Keyword
- **Wiki Links**: `[[page]]` highlighted as Identifier

### 11. Inlay Hints

Virtual text showing metadata:

```markdown
# My Document  ← 3 backlinks
Some text with #project (5) tag
```

Where:
- `← 3 backlinks` shows how many files link to this document
- `(5)` shows the tag is used 5 times across the workspace

## Configuration

### Enable/Disable Features

```lua
require("down").setup({
  ["lsp.markdown"] = {
    config = {
      enabled = true,          -- Enable/disable the entire module
      completion = true,       -- All completion features
      semantic_tokens = true,  -- Syntax highlighting
      inlay_hints = true,      -- Virtual text hints
      workspace_symbols = true,-- Workspace symbol completion
      frontmatter = true,      -- YAML frontmatter completion
      hover = false,           -- (Not yet implemented)
      diagnostics = false,     -- (Not yet implemented)
    }
  }
})
```

### Keybindings

Add custom keybindings for quick completion:

```lua
vim.keymap.set("i", "<C-Space>", "<C-x><C-o>", {
  desc = "Trigger completion",
  buffer = true,
})
```

## Troubleshooting

### Completion not working

1. **Check omnifunc is set**:
   ```vim
   :set omnifunc?
   ```
   Should show: `omnifunc=v:lua.down_markdown_complete`

2. **Verify you're in a workspace**:
   ```vim
   :lua print(vim.inspect(require("down.mod").get_mod("workspace").workspaces()))
   ```

3. **Check module is loaded**:
   ```vim
   :lua print(require("down.mod").get_mod("lsp.markdown") and "loaded" or "not loaded")
   ```

### No highlights appearing

1. **Check semantic tokens are enabled**:
   ```vim
   :lua print(require("down.mod").get_mod("lsp.markdown").config.semantic_tokens)
   ```

2. **Try manually refreshing**:
   ```vim
   :e!
   ```

### Inlay hints not showing

1. **Verify hints are enabled**:
   ```vim
   :lua print(require("down.mod").get_mod("lsp.markdown").config.inlay_hints)
   ```

2. **Update the cache**:
   ```vim
   :lua require("down.mod").get_mod("lsp.markdown").update_cache()
   ```

## Performance

The module caches workspace data to maintain performance:

- **File list**: Updated on `BufEnter` and `BufWritePost`
- **Tags**: Parsed from all markdown files in workspace
- **Backlinks**: Calculated by searching for links to current file

For large workspaces (1000+ files), you may notice a brief delay when:
- Opening the first markdown file (initial cache build)
- Saving files (cache refresh)

## Advanced Usage

### Programmatic Access

```lua
local md_lsp = require("down.mod").get_mod("lsp.markdown")

-- Get all tags in workspace
local tags = md_lsp.data.tags
for tag, instances in pairs(tags) do
  print(tag, #instances)
end

-- Get backlinks for current file
local backlinks = md_lsp.data.backlinks
for file, lines in pairs(backlinks) do
  print(file)
end

-- Manually update cache
md_lsp.update_cache()
```

### Custom Completion Sources

Extend the completion system:

```lua
-- In your config
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.md",
  callback = function()
    -- Add custom completion logic
  end,
})
```

## Examples

### Complete Workflow

1. Create a new note:
   ```vim
   :Down note today
   ```

2. Add tags and links:
   ```markdown
   # Daily Note

   Tags: #daily #work
   Link to [[project-plan]]
   Created: @today
   ```

3. Use completion for tags:
   - Type `#` then `<C-x><C-o>` to see existing tags

4. Use completion for links:
   - Type `[[` then `<C-x><C-o>` to see workspace files

5. Date shortcuts:
   - Type `@today` then `<C-x><C-o>` to insert current date

## See Also

- [README.md](./README.md) - Module overview and architecture
- [CLAUDE.md](../../../../CLAUDE.md) - Development guide for the codebase
