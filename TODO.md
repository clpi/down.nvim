# Todo

## High priority

### New features

- [x] Implement `bookmark` mod
- [x] Implement date and time completion insert
- [x] `data.props` Rewrite for YAML frontmatter with typed properties (text, number, date, select, multi_select, checkbox, url, email, status)
- [x] `data.database` Database module with schema definitions, CRUD on markdown tables, query/filter/sort engine
- [x] `ui.board` Board (Kanban) view with status-based column grouping
- [x] `data.database` Calendar, table, and list views for databases
- [x] `task` Add priority levels (A-E), due dates (DEADLINE), recurrence (SCHEDULED), task properties
- [x] `task.agenda` Cross-file task collection with date-grouped display (overdue, today, this week, etc.)
- [x] `bookmark` Add list, search, import, export, JSON store persistence

## Project Maintenance

- [x] Implement CI/CD for the project
- [x] Fix the `luarocks` rockspec file

## General

- [x] remove `integration.telescope` and `integration.trouble` mods
- [x] Re-implement the `data` metatable wrapper for modules to allow for persistent data
      synchronization for all modules.
- [x] Fix the `link` key maps for links, make markdown file specific

## Workspace

- [x] `workspace` Add functionality to add, delete, update workspaces from command

## Note

- [x] `note` Fix template implementation

## LSP and completion

- [x] `lsp` Implement automatic installation and setup and autocmd
- [x] `lsp` Implement tag completion in `down.lsp`

## Finder

- [x] `find` Implement existing telescope finders in the `find` module

### blink.cmp

- [x] Implement code completions for languages of markdown code blocks in `blink.cmp` integration
      like the following:

```lua
sources.default = function(ctx)
  local success, node = pcall(vim.treesitter.get_node)
  if vim.bo.filetype == 'lua' then
    return { 'lsp', 'path' }
  elseif success and node and vim.tbl_contains({ 'comment', 'line_comment', 'block_comment' }, node:type()) then
    return { 'buffer' }
  else
    return { 'lsp', 'path', 'snippets', 'buffer' }
  end
end
```

## Documentation

- [x] Update the book to reflect new changes

## Long term

### Integrations

- [x] CodeCompanion support (`/down` slash command)
- [x] Avante support (`AvanteInput` prompt completion)

### AI and latent semantic analysis

- [x] `data.semantic` Embedding models
- [x] `data.knowledge` Knowledge graph
- [x] `ai.chat` Chat based on fine-tuned models
- [x] `ai.gen` Generation based on fine-tuned models

## Refactoring

- [x] Merge `mod.load` and `mod.setup`
- [x] Merge `mod.setup().dependencies` and `mod.dep`

## CLI & Plugin Commands

- [x] `init` - Initialize .down/ workspace directory with index.md, down.json
- [x] `workspace add/remove/list/switch` - Manage workspaces via CLI and plugin
- [x] `profile add/remove/list/switch` - Manage profiles via CLI and plugin
- [x] `add <source>` - Add file/dir/URL/word to .down/data/ as repomix-style markdown
- [x] `rm <pattern>` - Append patterns to .downignore
- [x] `completion <shell>` - Generate shell completions (bash/zsh/fish)
- [x] Plugin auto-init - Create workspace in Neovim config dir if none exists
- [x] Profile-aware workspace switching in plugin (make :Down profile switch update workspace data)
- [x] `add` command: streaming URL fetch with proper HTML-to-markdown conversion (currently basic)
- [x] `add` command: binary file detection and exclusion
- [x] `.downignore` pattern matching for compact/add to respect ignore rules
- [x] Auto-install Go CLI binary on first-time plugin load
- [x] `memory` subcommand — persistent AI memory store (add/list/show/search/delete)
- [x] `context` subcommand — AI project context generation
- [x] Global data dir at ~/.local/share/down/ with memory/data/cache
- [x] Plugin: `:Down memory add/list/show/search/delete`
- [x] Plugin: `:Down context`
- [x] GitHub release CI — auto-build Go binaries for linux/macos/windows on tag push
- [x] Plugin: implement add command via Go CLI instead of Lua when binary is available
- [x] CLI: memory export/import for sharing context across projects
- [x] Plugin: context command should embed compact output when Go binary available
- [x] Export command: HTML, CSV, PDF, markdown export from workspace
- [x] Database formulas: computed fields, rollups (count/sum/avg/min/max/join)
- [x] Static site publish: generate navigable HTML site from workspace with dark mode
- [x] Automations: file watchers with trigger/action rules (index, tag, notify, compact, run)
- [x] MCP server: 12 real tools replacing stubs (workspace, knowledge, memory, tasks, notes)
- [x] LSP: enabled signatureHelp handler
- [x] Notion feature parity: databases, views, AI, export, publish, automations, MCP, profiles
- [x] Document workspace philosophy: .down/ dir as markdown context inside codebases
- [x] `sync` subcommand with sub-commands: data, knowledge, memory, context, vector, web
- [x] `vector` subcommand — manage embeddings in .down/vector/ (index, search, list, delete)
- [x] `todo` subcommand — manage todos across workspace/global with priority/tag/done filters
- [x] Workspace wiki config — `down init --wiki` for markdown-first workspaces
- [x] LSP: knowledge graph entity tokens in semantic highlighting
- [x] LSP: monikers, rename, linked edits, document links, document highlights

## Future
- [ ] Collaborative sync via git auto-commit on change
- [ ] Mobile companion app (read-only notes browser)
- [ ] Web UI for workspace browsing
- [ ] AI-powered auto-tagging and relationship discovery
- [ ] Calendar integration (sync with external calendars)
- [ ] PDF/EPUB export with pandoc templates
