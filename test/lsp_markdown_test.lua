-- Test file for LSP markdown module
-- Run with: nvim -u ./test/config/init.lua test/lsp_markdown_test.lua

local mod = require("down.mod")

-- Test workspace setup
local workspace = mod.get_mod("workspace")
if not workspace then
  print("Error: workspace module not loaded")
  return
end

-- Test LSP markdown module loading
local lsp_md = mod.load_mod("lsp.markdown", {
  completion = true,
  semantic_tokens = true,
  inlay_hints = true,
})

if not lsp_md then
  print("Error: Failed to load lsp.markdown module")
  return
end

print("✓ LSP markdown module loaded successfully")

-- Test workspace file detection
local test_file = vim.fn.tempname() .. ".md"
vim.cmd("edit " .. test_file)

local is_ws_file = lsp_md.is_workspace_file(0)
print(string.format("✓ Workspace file detection: %s", is_ws_file and "true" or "false"))

-- Test cache update
lsp_md.update_cache()
print(string.format("✓ Cache updated: %d files, %d tags",
  #lsp_md.data.files,
  vim.tbl_count(lsp_md.data.tags)))

-- Test completion provider
local completion = require("down.mod.lsp.markdown.completion")
print("✓ Completion provider loaded")

-- Test semantic token provider
local semantic = require("down.mod.lsp.markdown.semantic")
print("✓ Semantic token provider loaded")

-- Test inlay hints provider
local hints = require("down.mod.lsp.markdown.hints")
print("✓ Inlay hints provider loaded")

-- Test tag completion
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "# Test Document",
  "",
  "This is a test with #test-tag and #another-tag",
  "",
  "[[linked-document]]",
  "",
  "Some text with @today placeholder",
})

-- Simulate completion request
local params = {
  position = { line = 2, character = 25 }
}

local items = completion.get_items(params)
print(string.format("✓ Completion items generated: %d items", #items))

-- Test semantic tokens
local tokens = semantic.get_tokens(0)
print(string.format("✓ Semantic tokens generated: %d tokens", #tokens.data / 5))

-- Test inlay hints
local hint_items = hints.get_hints(0)
print(string.format("✓ Inlay hints generated: %d hints", #hint_items))

-- Test tag hints specifically
local tag_hints = hints.get_tag_hints("Some text with #test-tag", 1, lsp_md)
print(string.format("✓ Tag hints: %d hints for tags", #tag_hints))

-- Test link hints
local link_hints = hints.get_link_hints("[[test-link]] and [text](file.md)", 1, lsp_md)
print(string.format("✓ Link hints: %d hints for links", #link_hints))

print("\n=== All tests completed ===")
print("\nTo use the LSP markdown module:")
print("1. Open a markdown file in a workspace")
print("2. Start typing # for tag completion")
print("3. Start typing [[ for link completion")
print("4. Start typing @ for date/time snippets")
print("5. Enable inlay hints to see backlinks and metadata")
