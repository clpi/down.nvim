local log = require("down.log")

---@class down.mod.lsp.markdown.Semantic
local Semantic = {}

---@type vim.lsp.Client
Semantic.client = nil

---@type number
Semantic.bufnr = nil

--- Semantic token types
---@enum down.mod.lsp.markdown.TokenType
Semantic.token_types = {
  namespace = 0,
  type = 1,
  class = 2,
  enum = 3,
  interface = 4,
  struct = 5,
  typeParameter = 6,
  parameter = 7,
  variable = 8,
  property = 9,
  enumMember = 10,
  event = 11,
  ['function'] = 12,
  method = 13,
  macro = 14,
  keyword = 15,
  modifier = 16,
  comment = 17,
  string = 18,
  number = 19,
  regexp = 20,
  operator = 21,
}

--- Semantic token modifiers
---@enum down.mod.lsp.markdown.TokenModifier
Semantic.token_modifiers = {
  declaration = 0,
  definition = 1,
  readonly = 2,
  static = 3,
  deprecated = 4,
  abstract = 5,
  async = 6,
  modification = 7,
  documentation = 8,
  defaultLibrary = 9,
}

--- Setup semantic token provider
---@param client vim.lsp.Client
---@param bufnr number
Semantic.setup = function(client, bufnr)
  Semantic.client = client
  Semantic.bufnr = bufnr

  log.trace("Setting up semantic token provider for buffer " .. bufnr)

  -- Register semantic tokens handler
  vim.lsp.handlers["textDocument/semanticTokens/full"] = function(err, result, ctx, config)
    if err then
      log.error("Semantic tokens error: " .. vim.inspect(err))
      return
    end

    return vim.lsp.handlers["textDocument/semanticTokens/full"](err, result, ctx, config)
  end
end

--- Get semantic tokens for buffer
---@param bufnr number
---@return lsp.SemanticTokens
Semantic.get_tokens = function(bufnr)
  local tokens = { data = {} }
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local prev_line = 0
  local prev_start = 0

  for line_num, line in ipairs(lines) do
    -- Tags
    for start_col, tag in line:gmatch("()#(%S+)") do
      local delta_line = line_num - 1 - prev_line
      local delta_start = delta_line == 0 and (start_col - 1 - prev_start) or (start_col - 1)

      table.insert(tokens.data, delta_line)
      table.insert(tokens.data, delta_start)
      table.insert(tokens.data, #tag + 1) -- length including #
      table.insert(tokens.data, Semantic.token_types.keyword)
      table.insert(tokens.data, 0) -- no modifiers

      prev_line = line_num - 1
      prev_start = start_col - 1
    end

    -- Links - [[wiki]]
    for start_col, link in line:gmatch("()%[%[([^%]]+)%]%]") do
      local delta_line = line_num - 1 - prev_line
      local delta_start = delta_line == 0 and (start_col - 1 - prev_start) or (start_col - 1)

      table.insert(tokens.data, delta_line)
      table.insert(tokens.data, delta_start)
      table.insert(tokens.data, #link + 4) -- length including [[]]
      table.insert(tokens.data, Semantic.token_types.namespace)
      table.insert(tokens.data, 0)

      prev_line = line_num - 1
      prev_start = start_col - 1
    end

    -- Markdown links - [text](url)
    for start_col, text, url in line:gmatch("()%[([^%]]+)%]%(([^%)]+)%)") do
      -- Highlight the URL part
      local url_start = start_col + #text + 2
      local delta_line = line_num - 1 - prev_line
      local delta_start = delta_line == 0 and (url_start - 1 - prev_start) or (url_start - 1)

      table.insert(tokens.data, delta_line)
      table.insert(tokens.data, delta_start)
      table.insert(tokens.data, #url)
      table.insert(tokens.data, Semantic.token_types.string)
      table.insert(tokens.data, 0)

      prev_line = line_num - 1
      prev_start = url_start - 1
    end

    -- Bold **text**
    for start_col, text in line:gmatch("()%*%*([^%*]+)%*%*") do
      local delta_line = line_num - 1 - prev_line
      local delta_start = delta_line == 0 and (start_col - 1 - prev_start) or (start_col - 1)

      table.insert(tokens.data, delta_line)
      table.insert(tokens.data, delta_start)
      table.insert(tokens.data, #text + 4)
      table.insert(tokens.data, Semantic.token_types.keyword)
      table.insert(tokens.data, bit.lshift(1, Semantic.token_modifiers.readonly))

      prev_line = line_num - 1
      prev_start = start_col - 1
    end

    -- Italic *text*
    for start_col, text in line:gmatch("()%*([^%*]+)%*") do
      if not line:sub(start_col - 1, start_col - 1):match("%*") then
        local delta_line = line_num - 1 - prev_line
        local delta_start = delta_line == 0 and (start_col - 1 - prev_start) or (start_col - 1)

        table.insert(tokens.data, delta_line)
        table.insert(tokens.data, delta_start)
        table.insert(tokens.data, #text + 2)
        table.insert(tokens.data, Semantic.token_types.keyword)
        table.insert(tokens.data, bit.lshift(1, Semantic.token_modifiers.modification))

        prev_line = line_num - 1
        prev_start = start_col - 1
      end
    end

    -- Inline code `code`
    for start_col, code in line:gmatch("()`([^`]+)`") do
      local delta_line = line_num - 1 - prev_line
      local delta_start = delta_line == 0 and (start_col - 1 - prev_start) or (start_col - 1)

      table.insert(tokens.data, delta_line)
      table.insert(tokens.data, delta_start)
      table.insert(tokens.data, #code + 2)
      table.insert(tokens.data, Semantic.token_types.string)
      table.insert(tokens.data, 0)

      prev_line = line_num - 1
      prev_start = start_col - 1
    end

    -- Headings
    local heading = line:match("^(#+)%s")
    if heading then
      local delta_line = line_num - 1 - prev_line
      local delta_start = delta_line == 0 and (0 - prev_start) or 0

      table.insert(tokens.data, delta_line)
      table.insert(tokens.data, delta_start)
      table.insert(tokens.data, #line)
      table.insert(tokens.data, Semantic.token_types.class)
      table.insert(tokens.data, bit.lshift(1, Semantic.token_modifiers.declaration))

      prev_line = line_num - 1
      prev_start = 0
    end

    -- Tasks
    local task = line:match("^%s*%- %[[ xX]%]")
    if task then
      local delta_line = line_num - 1 - prev_line
      local delta_start = delta_line == 0 and (0 - prev_start) or 0

      table.insert(tokens.data, delta_line)
      table.insert(tokens.data, delta_start)
      table.insert(tokens.data, #task)
      table.insert(tokens.data, Semantic.token_types.enumMember)
      table.insert(tokens.data, 0)

      prev_line = line_num - 1
      prev_start = 0
    end
  end

  return tokens
end

--- Refresh semantic tokens
---@param bufnr number
Semantic.refresh = function(bufnr)
  if not Semantic.client then
    return
  end

  local tokens = Semantic.get_tokens(bufnr)
  vim.lsp.util.buf_highlight_references(bufnr, tokens, "utf-8")
end

return Semantic
