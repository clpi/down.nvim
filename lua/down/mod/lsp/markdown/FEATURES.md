# Markdown LSP - Complete Feature List

## Completion Features

### 1. Tag Completion (`#`)
- **Trigger**: Type `#` then `<C-x><C-o>`
- **Shows**: All existing tags in workspace with usage count
- **Example**: `#proj` → `#project (5 uses)`, `#programming (3 uses)`

### 2. Link Completion (`[[`)
- **Trigger**: Type `[[` then `<C-x><C-o>`
- **Shows**: All markdown files in current workspace
- **Features**:
  - File preview in documentation
  - Relative path shown
  - Workspace-aware

### 3. Date/Time Snippets (`@`)
- **Trigger**: Type `@` then `<C-x><C-o>`
- **Available**:
  - `@today` → Current date (YYYY-MM-DD)
  - `@now` → Current date and time
  - `@yesterday` → Previous day
  - `@tomorrow` → Next day
  - `@week` → Week number (YYYY-WXX)
  - `@month` → Year-month (YYYY-MM)
  - `@year` → Current year

### 4. Frontmatter/YAML (in `---` blocks)
- **Trigger**: Inside frontmatter, `<C-x><C-o>`
- **Fields**:
  - `title` - Document title
  - `author` - Author name
  - `date` - Auto-filled with current date
  - `tags` - Tags array
  - `categories` - Categories
  - `draft` - Draft status (true/false)
  - `description` - SEO description
  - `keywords` - SEO keywords
  - `toc` - Table of contents (true/false)
  - `math` - Enable math rendering
  - `mermaid` - Enable mermaid diagrams

### 5. Heading Symbols (`##`)
- **Trigger**: Type `##` then `<C-x><C-o>`
- **Shows**: All headings in current document
- **Details**: Shows heading level and line number

### 6. Emoji Completion (`:`)
- **Trigger**: Type `:emoji_name` then `<C-x><C-o>`
- **Examples**:
  - `:smile:` → 😊
  - `:heart:` → ❤️
  - `:fire:` → 🔥
  - `:rocket:` → 🚀
  - `:check:` → ✅
  - `:warning:` → ⚠️
  - And 14 more!

### 7. Workspace Symbols (`@@`)
- **Trigger**: Type `@@` then `<C-x><C-o>`
- **Shows**:
  - All configured workspaces
  - Common workspace symbols (index, notes, journal, etc.)
- **Example**: `@@notes` → Reference to notes workspace

### 8. Reference Links (`[ref]:`)
- **Trigger**: Type `[text][` then `<C-x><C-o>`
- **Shows**: All existing reference-style link definitions
- **Example**: `[link][ref]` where `[ref]: https://...` is defined

### 9. Markdown Syntax Snippets
- **Trigger**: Type snippet name then `<C-x><C-o>`
- **Available**:
  - `heading` → `# ${1:Heading}`
  - `bold` → `**${1:text}**`
  - `italic` → `*${1:text}*`
  - `code` → `` `${1:code}` ``
  - `codeblock` → ` ```${1:lang}\n${2:code}\n``` `
  - `link` → `[${1:text}](${2:url})`
  - `wikilink` → `[[${1:page}]]`
  - `image` → `![${1:alt}](${2:url})`
  - `table` → Table template
  - `task` → `- [ ] ${1:task}`
  - `list` → `- ${1:item}`
  - `ordered` → `1. ${1:item}`
  - `quote` → `> ${1:quote}`

### 10. Workspace File Completion (in links)
- **Trigger**: Type `](` then `<C-x><C-o>` (in markdown link)
- **Shows**: Workspace files with previews
- **Context**: Works in `[text](file)` syntax

## Semantic Features

### 1. Syntax Highlighting
- **Tags**: `#tag` highlighted as `Keyword`
- **Wiki Links**: `[[page]]` highlighted as `Identifier`
- **Auto-refresh**: On text change, buffer enter

### 2. Inlay Hints
- **Backlinks**: Virtual text showing link count
  - Example: `# Document  ← 3 backlinks`
- **Tag Metadata**: Usage count for tags
  - Example: `#project (5)`
- **Hover tooltips**: Show backlink details and tag locations

## Configuration Options

```lua
{
  enabled = true,           -- Master switch
  completion = true,        -- All completion features
  semantic_tokens = true,   -- Syntax highlighting
  inlay_hints = true,       -- Virtual text hints
  workspace_symbols = true, -- @@ completion
  frontmatter = true,       -- YAML frontmatter
  hover = false,            -- (Future) Hover documentation
  diagnostics = false,      -- (Future) Broken link detection
}
```

## Performance

- **Cache**: Workspace data cached and refreshed on:
  - `BufEnter` (markdown files)
  - `BufWritePost` (after save)
- **Lazy Loading**: Module only loads for workspace files
- **Incremental**: Highlights update on text change

## Workspace Integration

All features are **workspace-aware**:
- Only activates in configured workspaces
- File completion limited to current workspace
- Tag completion across entire workspace
- Backlinks calculated per workspace

## Future Features

- [ ] Hover documentation for tags and links
- [ ] Diagnostics for broken links
- [ ] Code actions for link refactoring
- [ ] Go to definition for links
- [ ] Find all references for tags
- [ ] Document symbols (outline)
- [ ] Signature help for frontmatter
