# Markdown LSP Module

An in-process markdown enhancement module for down.nvim workspaces, providing intelligent completions, semantic highlighting, and contextual hints directly in Lua without an external LSP server.

## Features

### Completion Providers (13 types!)

1. **Tag Completion** (`#`): Auto-complete existing tags with usage statistics
2. **Link Completion** (`[[`): Complete file links with workspace awareness and file previews
3. **Date/Time Snippets** (`@`): Quick date insertion - `@today`, `@now`, `@yesterday`, etc.
4. **Frontmatter/YAML**: Auto-complete YAML frontmatter fields (title, author, tags, etc.)
5. **Heading Symbols** (`##`): Jump to existing headings in document
6. **Emoji Completion** (`:`): Insert emojis with `:emoji_name:` syntax
7. **Workspace Symbols** (`@@`): Reference workspace elements
8. **Reference Links**: Auto-complete existing reference-style link definitions
9. **Markdown Syntax**: Snippets for headings, bold, italic, code blocks, tables, tasks, etc.

### Semantic Tokens

Provides syntax highlighting for:
- Tags (`#tag`)
- Wiki-style links (`[[page]]`)
- Markdown links (`[text](url)`)
- Bold text (`**text**`)
- Italic text (`*text*`)
- Inline code (`` `code` ``)
- Headings
- Task checkboxes

### Inlay Hints

- **Backlink Hints**: Shows count of files linking to current document
- **Tag Metadata**: Displays usage count for tags with preview on hover
- **Link Previews**: Preview linked documents on hover

## Usage

The module automatically activates when you open a markdown file within a configured workspace. No external LSP server required - everything runs in Neovim's Lua runtime.

**Completion**: Use `<C-x><C-o>` (omnifunc) to trigger completions.

**Quick Reference**:
- `#` → Tags
- `[[` → Links
- `@` → Dates
- `:` → Emojis
- `@@` → Workspace symbols
- Inside `---` → Frontmatter fields

### Configuration

```lua
require("down").setup({
  lsp = {}, -- Automatically loads markdown LSP (enabled by default)
})

-- Or customize:
require("down").setup({
  ["lsp.markdown"] = {
    config = {
      enabled = true,           -- Master switch (set to false to disable)
      completion = true,        -- All completion features
      semantic_tokens = true,   -- Syntax highlighting
      inlay_hints = true,       -- Virtual text hints
      workspace_symbols = true, -- @@ completion
      frontmatter = true,       -- YAML frontmatter
      hover = false,            -- (Future) Hover documentation
      diagnostics = false,      -- (Future) Broken link detection
    }
  }
})
```

### Completion Examples

**Tags:**
```markdown
#pro<C-x><C-o> → #project, #programming, #productivity
```

**Links:**
```markdown
[[doc<C-x><C-o> → [[documentation]], [[docker-notes]]
```

**Dates:**
```markdown
@tod<C-x><C-o> → 2025-10-03
@now<C-x><C-o> → 2025-10-03 19:45:30
```

**Emojis:**
```markdown
:fire<C-x><C-o> → 🔥
:rocket<C-x><C-o> → 🚀
```

**Frontmatter:**
```yaml
---
title<C-x><C-o> → title:
tags<C-x><C-o> → tags: []
---
```

**Workspace Symbols:**
```markdown
@@notes<C-x><C-o> → Lists workspaces
```

## Architecture

### Module Structure

```
lsp/markdown/
├── init.lua        # Main module with LSP client setup
├── completion.lua  # Completion provider
├── semantic.lua    # Semantic token provider
├── hints.lua       # Inlay hints provider
└── README.md       # This file
```

### Dependencies

- `workspace`: Access to workspace files and paths
- `tag`: Tag parsing and management
- `link`: Link resolution and navigation
- `time`: Date/time utilities
- `integration.treesitter`: AST parsing

### Implementation

The module uses Neovim's native features instead of LSP protocol:

1. **Completion**: vim.api omnifunc (`<C-x><C-o>`)
2. **Semantic Highlighting**: nvim_buf_add_highlight with autocmds
3. **Inlay Hints**: nvim_buf_set_extmark with virtual text

## Implementation Notes

- **Workspace-aware**: Only activates for files within configured workspaces
- **Cached data**: Maintains cache of workspace files, tags, and backlinks
- **Auto-refresh**: Updates cache on buffer enter and write events
- **Performance**: Uses incremental parsing and caching for large workspaces

## Future Enhancements

- [ ] Document symbols (outline)
- [ ] Go to definition for links
- [ ] Find references for tags
- [ ] Diagnostics for broken links
- [ ] Code actions for link refactoring
- [ ] Hover documentation for tags and links
- [ ] Signature help for frontmatter
