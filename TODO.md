# Todo

## High priority

### New features

- [x] Implement `bookmark` mod
- [x] Implement date and time completion insert

## Project Maintenance

- [ ] Implement CI/CD for the project
- [ ] Fix the `luarocks` rockspec file

## General

- [ ] remove `integration.telescope` and `integration.trouble` mods
- [ ] Re-implement the `data` metatable wrapper for modules to allow for persistent data
      synchronization for all modules.
- [ ] Fix the `link` key maps for links, make markdown file specific

## Workspace

- [ ] `workspace` Add functionality to add, delete, update workspaces from command

## Note

- [ ] `note` Fix template implementation

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

- [ ] Update the book to reflect new changes

## Long term

### Integrations

- [x] CodeCompanion support (`/down` slash command)
- [x] Avante support (`AvanteInput` prompt completion)

### AI and latent semantic analysis

- [ ] `data.semantic` Embedding models
- [ ] `data.knowledge` Knowledge graph
- [ ] `ai.chat` Chat based on fine-tuned models
- [ ] `ai.gen` Generation based on fine-tuned models

## Refactoring

- [ ] Merge `mod.load` and `mod.setup`
- [ ] Merge `mod.setup().dependencies` and `mod.dep`
