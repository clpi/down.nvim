--- ai - AI integration module
--- Provides chat, generation, and AI-powered features for down.nvim.
--- Uses HTTP APIs directly or delegates to the Go LSP engine.

local mod = require ("down.mod")

---@class down.mod.ai.Ai: down.Mod
local Ai = mod.new ("ai")

Ai.config = {
  --- Provider: "ollama", "openai", "anthropic", "gemini", "xai", "cloudflare"
  provider = "ollama",
  --- API endpoint (auto-set per provider)
  endpoint = nil,
  --- API key
  api_key = nil,
  --- Model name
  model = nil,
  --- Temperature for generation
  temperature = 0.7,
  --- Max tokens in response
  max_tokens = 2048,
  --- System prompt override
  system_prompt = nil,
  --- Whether to include knowledge graph context
  use_knowledge = true,
  --- Whether to include semantic search context
  use_semantic = false,
}

Ai.dep = { "cmd" }

Ai.setup = function ()
  -- Set defaults based on provider
  local defaults = {
    ollama = { endpoint = "http://localhost:11434/v1/chat/completions", model = "llama3.2" },
    openai = { endpoint = "https://api.openai.com/v1/chat/completions", model = "gpt-4o-mini" },
    anthropic = { endpoint = "https://api.anthropic.com/v1/messages", model = "claude-3-haiku-20240307" },
    gemini = { endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent", model = "gemini-pro" },
    xai = { endpoint = "https://api.x.ai/v1/chat/completions", model = "grok-3-mini-fast" },
    cloudflare = { endpoint = "https://api.cloudflare.com/client/v4/accounts/ACCOUNT/ai/run/@cf/meta/llama-3.1-8b-instruct", model = "@cf/meta/llama-3.1-8b-instruct" },
  }
  local d = defaults[Ai.config.provider]
  if d then
    if not Ai.config.endpoint then Ai.config.endpoint = d.endpoint end
    if not Ai.config.model then Ai.config.model = d.model end
  end
  return { loaded = true }
end

--- Make an HTTP request to an AI provider
---@param messages table[] Array of {role, content}
---@param opts? table
---@return string|nil, string|nil
function Ai.complete (messages, opts)
  opts = vim.tbl_extend ("keep", opts or {}, {
    temperature = Ai.config.temperature,
    max_tokens = Ai.config.max_tokens,
    model = Ai.config.model,
  })

  local body = vim.json.encode ({
    model = opts.model,
    messages = messages,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens,
    stream = false,
  })

  local auth = ""
  if Ai.config.api_key then
    auth = " -H 'Authorization: Bearer " .. Ai.config.api_key .. "'"
  end

  local cmd = string.format (
    "curl -s -X POST '%s' -H 'Content-Type: application/json'%s -d '%s' 2>/dev/null",
    Ai.config.endpoint,
    auth,
    body:gsub ("'", "'\\''")
  )

  local handle = io.popen (cmd)
  if not handle then return nil, "curl failed" end
  local result = handle:read ("*a")
  handle:close ()

  if not result or result == "" then return nil, "empty response" end
  local ok, parsed = pcall (vim.json.decode, result)
  if not ok then return nil, "invalid JSON: " .. result:sub (1, 200) end

  -- OpenAI-compatible format
  if parsed.choices and parsed.choices[1] then
    local msg = parsed.choices[1].message
    if msg then return msg.content, nil end
    if parsed.choices[1].text then return parsed.choices[1].text, nil end
  end

  -- Anthropic format
  if parsed.content and type (parsed.content) == "table" then
    for _, block in ipairs (parsed.content) do
      if block.type == "text" then return block.text, nil end
    end
  end

  -- Gemini format
  if parsed.candidates and parsed.candidates[1] then
    local parts = parsed.candidates[1].content and parsed.candidates[1].content.parts
    if parts then
      local text = ""
      for _, p in ipairs (parts) do
        if p.text then text = text .. p.text end
      end
      return text, nil
    end
  end

  return nil, "unrecognized response format"
end

--- Build a knowledge-aware system prompt
---@return string
function Ai.knowledge_context ()
  if not Ai.config.use_knowledge then return "" end
  local ok, knowledge = pcall (require, "down.mod.data.knowledge")
  if not ok then return "" end

  local ctx = {}
  local entity_count = 0
  for _, _ in pairs (knowledge.entities or {}) do entity_count = entity_count + 1 end
  if entity_count > 0 then
    ctx[#ctx + 1] = "Knowledge graph has " .. entity_count .. " indexed entities."
  end

  local rel_count = 0
  for _, _ in pairs (knowledge.relations or {}) do rel_count = rel_count + 1 end
  if rel_count > 0 then
    ctx[#ctx + 1] = "There are " .. rel_count .. " known relations between entities."
  end

  return #ctx > 0 and table.concat (ctx, " ") or ""
end

return Ai
