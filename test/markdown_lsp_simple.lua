-- Simple test for markdown LSP module
-- Usage: nvim -u test/config/init.lua test/markdown_lsp_simple.lua

vim.schedule(function()
  print("=== Testing Markdown LSP Module ===\n")

  -- Load down
  local ok, down = pcall(require, "down")
  if not ok then
    print("❌ Failed to load down module")
    return
  end

  -- Setup down with workspace
  down.setup({
    workspace = {
      default = "test",
      workspaces = {
        test = vim.fn.getcwd() .. "/test",
      },
    },
    lsp = {},
  })

  print("✓ Down module loaded")

  -- Load the markdown LSP module
  local mod = require("down.mod")
  local lsp_md = mod.load_mod("lsp.markdown")

  if not lsp_md then
    print("❌ Failed to load lsp.markdown module")
    return
  end

  print("✓ LSP markdown module loaded")

  -- Create a test file in workspace
  local test_dir = vim.fn.getcwd() .. "/test"
  vim.fn.mkdir(test_dir, "p")

  local test_file = test_dir .. "/test_note.md"
  vim.cmd("edit " .. test_file)

  -- Add test content
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "# Test Note",
    "",
    "This has #test-tag and #another-tag",
    "",
    "Link to [[other-note]]",
    "",
    "Date: @today",
  })

  vim.cmd("write")

  print("✓ Test file created: " .. test_file)

  -- Wait a moment for autocmds to fire
  vim.defer_fn(function()
    -- Check if features are attached
    local omnifunc = vim.api.nvim_buf_get_option(0, "omnifunc")
    print(string.format("✓ Omnifunc set: %s", omnifunc))

    -- Test cache
    print(string.format("✓ Files in cache: %d", #lsp_md.data.files))
    print(string.format("✓ Tags in cache: %d", vim.tbl_count(lsp_md.data.tags)))

    -- Trigger completion
    print("\n=== Completion Test ===")
    print("Type Ctrl-X Ctrl-O after # to test tag completion")
    print("Type Ctrl-X Ctrl-O after [[ to test link completion")
    print("Type Ctrl-X Ctrl-O after @ to test date completion")

    print("\n=== All tests completed ===")
    print("Module is active. Try the completions!")
  end, 500)
end)
