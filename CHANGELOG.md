# Changelog

## Unreleased

### Fixed
- Neovim LSP: reuse a single `down` client, skip duplicate buffer attaches, and reindex on workspace switch
- Neovim LSP: resolve plugin `ext/down` path via runtime files for CLI build/install
- Workspace: broadcast `wschanged` when switching workspaces
- Completion: `InsertCharPre` triggers on markdown filetypes (not broken `*.md` autocmd patterns)
- Plugin: lazy-load `down.nvim` when opening markdown buffers
- nvim-cmp: fix `[[wiki]]` file source workspace lookup
- Mention completion: insert `[[wiki]]` links for workspace pages
- blink: fix undefined `completion` variable in LSP source adapter

## 0.1.2-alpha (2024-12-15)

## 0.1.1-alpha

## 0.1.0-alpha.1

