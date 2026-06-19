--- data.semantic - Embedding models and semantic search
--- Generates, stores, and queries vector embeddings for knowledge graph
--- entities, documents, and arbitrary text chunks.

local mod = require ("down.mod")
local log = require ("down.log")

---@class down.mod.data.semantic.Semantic: down.Mod
local Semantic = mod.new ("data.semantic")
Semantic.dep = { "data", "cmd" }

---@class down.mod.data.semantic.Config
Semantic.config = {
  --- Model name for embeddings
  model = "nomic-embed-text",
  --- Dimension of embedding vectors (override per model)
  dimension = nil,
  --- HTTP endpoint for external embedding API
  endpoint = nil,
  --- API key for external embedding service
  api_key = nil,
  --- Provider: "local", "ollama", "openai"
  provider = "local",
  --- Whether to use the Go LSP for embeddings
  use_lsp = false,
  --- Similarity threshold for matches (0-1)
  similarity_threshold = 0.5,
  --- Max results per query
  max_results = 10,
}

---@class down.mod.data.semantic.Embedding
---@field id string Entity or chunk identifier
---@field vector number[] The embedding vector
---@field text string The original text
---@field kind string Entity kind or "chunk"
---@field source string Source file path
---@field created number Timestamp

-- In-memory embedding store
Semantic.embeddings = {}
Semantic.vocabulary = {}
Semantic.idf = {}

---@return down.mod.Setup
Semantic.setup = function ()
  Semantic.restore ()
  return { loaded = true }
end

--- Simple tokenizer: splits text into lowercase word tokens
---@param text string
---@return string[]
local function tokenize (text)
  local tokens = {}
  for word in text:gmatch ("[%w_]+") do
    local lower = word:lower ()
    if #lower > 1 then
      tokens[#tokens + 1] = lower
    end
  end
  return tokens
end

--- Hash a word to a consistent integer
---@param word string
---@return number
local function hash_word (word)
  local h = 0
  for i = 1, #word do
    h = (h * 31 + word:byte (i)) % 1000000
  end
  return h
end

--- Generate a local bag-of-words embedding vector
---@param text string
---@param dim number
---@return number[]
function Semantic.embed_local (text, dim)
  dim = dim or Semantic.config.dimension or 384
  local tokens = tokenize (text)
  if #tokens == 0 then
    local v = {}
    for i = 1, dim do v[i] = 0 end
    return v
  end

  local vector = {}
  for i = 1, dim do vector[i] = 0 end

  for _, token in ipairs (tokens) do
    local h = hash_word (token)
    local idx = (h % dim) + 1
    vector[idx] = vector[idx] + 1
  end

  -- Apply IDF weighting if vocabulary is built
  for _, token in ipairs (tokens) do
    local h = hash_word (token)
    local idx = (h % dim) + 1
    if Semantic.idf[token] then
      vector[idx] = vector[idx] * Semantic.idf[token]
    end
  end

  -- Normalize (L2)
  local norm = 0
  for _, v in ipairs (vector) do
    norm = norm + v * v
  end
  norm = math.sqrt (norm)
  if norm > 0 then
    for i = 1, dim do
      vector[i] = vector[i] / norm
    end
  end

  return vector
end

--- Call Ollama embeddings API
---@param text string
---@return number[]|nil, string|nil
function Semantic.embed_ollama (text)
  local endpoint = Semantic.config.endpoint or "http://localhost:11434/api/embeddings"
  local model = Semantic.config.model
  local body = vim.json.encode ({ model = model, prompt = text })
  local cmd = string.format (
    "curl -s -X POST '%s' -H 'Content-Type: application/json' -d '%s' 2>/dev/null",
    endpoint,
    body:gsub ("'", "'\\''")
  )
  local handle = io.popen (cmd)
  if not handle then return nil, "curl failed" end
  local result = handle:read ("*a")
  handle:close ()
  if not result or result == "" then return nil, "empty response" end
  local ok, parsed = pcall (vim.json.decode, result)
  if not ok or not parsed.embedding then return nil, "parse failed: " .. tostring (result) end
  return parsed.embedding
end

--- Call OpenAI-compatible embeddings API
---@param text string
---@return number[]|nil, string|nil
function Semantic.embed_openai (text)
  local endpoint = Semantic.config.endpoint or "https://api.openai.com/v1/embeddings"
  local model = Semantic.config.model or "text-embedding-3-small"
  local body = vim.json.encode ({
    model = model,
    input = text,
  })
  local auth = ""
  if Semantic.config.api_key then
    auth = " -H 'Authorization: Bearer " .. Semantic.config.api_key .. "'"
  end
  local cmd = string.format (
    "curl -s -X POST '%s' -H 'Content-Type: application/json'%s -d '%s' 2>/dev/null",
    endpoint,
    auth,
    body:gsub ("'", "'\\''")
  )
  local handle = io.popen (cmd)
  if not handle then return nil, "curl failed" end
  local result = handle:read ("*a")
  handle:close ()
  if not result or result == "" then return nil, "empty response" end
  local ok, parsed = pcall (vim.json.decode, result)
  if not ok or not parsed.data or not parsed.data[1] then
    return nil, "parse failed"
  end
  return parsed.data[1].embedding
end

--- Generate an embedding for text using the configured provider
---@param text string
---@return number[]|nil, string|nil
function Semantic.embed (text)
  if Semantic.config.provider == "ollama" then
    return Semantic.embed_ollama (text)
  elseif Semantic.config.provider == "openai" then
    return Semantic.embed_openai (text)
  else
    return Semantic.embed_local (text)
  end
end

--- Cosine similarity between two vectors
---@param a number[]
---@param b number[]
---@return number
function Semantic.cosine (a, b)
  if not a or not b then return 0 end
  local dot, na, nb = 0, 0, 0
  for i = 1, math.min (#a, #b) do
    dot = dot + a[i] * b[i]
    na = na + a[i] * a[i]
    nb = nb + b[i] * b[i]
  end
  na, nb = math.sqrt (na), math.sqrt (nb)
  if na == 0 or nb == 0 then return 0 end
  return dot / (na * nb)
end

--- Index a document chunk, generating and storing its embedding
---@param id string
---@param text string
---@param opts? { kind?: string, source?: string }
---@return down.mod.data.semantic.Embedding|nil
function Semantic.index (id, text, opts)
  opts = opts or {}
  local vector, err = Semantic.embed (text)
  if not vector then
    log.warn ("Semantic.index: failed to embed '" .. id .. "': " .. (err or "unknown"))
    return nil
  end
  local embedding = {
    id = id,
    vector = vector,
    text = text,
    kind = opts.kind or "chunk",
    source = opts.source or "",
    created = os.time (),
  }
  Semantic.embeddings[id] = embedding
  Semantic.save ()
  return embedding
end

--- Remove an embedding by ID
---@param id string
function Semantic.remove (id)
  Semantic.embeddings[id] = nil
  Semantic.save ()
end

--- Search for the most similar embeddings to a query
---@param query string
---@param opts? { kind?: string, limit?: number, threshold?: number }
---@return { id: string, score: number, text: string, kind: string }[]
function Semantic.search (query, opts)
  opts = opts or {}
  local query_vec = Semantic.embed (query)
  if not query_vec then return {} end

  local results = {}
  local threshold = opts.threshold or Semantic.config.similarity_threshold
  local limit = opts.limit or Semantic.config.max_results

  for id, emb in pairs (Semantic.embeddings) do
    if not opts.kind or emb.kind == opts.kind then
      local score = Semantic.cosine (query_vec, emb.vector)
      if score >= threshold then
        results[#results + 1] = {
          id = id,
          score = score,
          text = emb.text,
          kind = emb.kind,
          source = emb.source,
        }
      end
    end
  end

  table.sort (results, function (a, b) return a.score > b.score end)

  if #results > limit then
    local trimmed = {}
    for i = 1, limit do trimmed[i] = results[i] end
    return trimmed
  end
  return results
end

--- Find similar items to a given text
---@param text string
---@param opts? { kind?: string, limit?: number }
---@return { id: string, score: number, text: string }[]
function Semantic.similar (text, opts)
  return Semantic.search (text, opts)
end

--- Build IDF vocabulary from all indexed embeddings
function Semantic.build_idf ()
  local df = {}
  local total = 0
  for _, emb in pairs (Semantic.embeddings) do
    total = total + 1
    local seen = {}
    for raw_token in emb.text:gmatch ("[%w_]+") do
      local t = raw_token:lower ()
      if not seen[t] then
        seen[t] = true
        df[t] = (df[t] or 0) + 1
      end
    end
  end
  Semantic.idf = {}
  for token, count in pairs (df) do
    Semantic.idf[token] = math.log (total / (1 + count))
  end
end

--- Index all entities from the knowledge graph
function Semantic.index_knowledge ()
  local knowledge = require ("down.mod.data.knowledge")
  for id, entity in pairs (knowledge.entities or {}) do
    local text = entity.name or id
    Semantic.index ("entity:" .. id, text, { kind = "entity", source = entity.file or "" })
  end
  Semantic.build_idf ()
end

--- Index a full markdown file by splitting into heading-level chunks
---@param path string
---@param content string
function Semantic.index_file (path, content)
  local heading = ""
  local chunk = ""
  local chunk_idx = 0

  for line in content:gmatch ("[^\n]+") do
    if line:match ("^#+%s") then
      if chunk ~= "" then
        chunk_idx = chunk_idx + 1
        local id = path .. "#" .. chunk_idx
        Semantic.index (id, chunk, { kind = "chunk", source = path })
      end
      heading = line
      chunk = line .. "\n"
    else
      chunk = chunk .. line .. "\n"
    end
  end
  if chunk ~= "" then
    chunk_idx = chunk_idx + 1
    local id = path .. "#" .. chunk_idx
    Semantic.index (id, chunk, { kind = "chunk", source = path })
  end
  Semantic.build_idf ()
end

--- Persist embeddings to the data store
function Semantic.save ()
  local data = {
    config = {
      model = Semantic.config.model,
      dimension = Semantic.config.dimension,
      provider = Semantic.config.provider,
    },
    idf = Semantic.idf,
    count = 0,
  }
  for id, emb in pairs (Semantic.embeddings) do
    data[id] = { text = emb.text, kind = emb.kind, source = emb.source, created = emb.created }
    data.count = data.count + 1
  end
  Semantic.dep["data"].set ("semantic.store", data)
  Semantic.dep["data"].flush ()
end

--- Restore embeddings from the data store
function Semantic.restore ()
  local data = Semantic.dep["data"].get ("semantic.store")
  if not data or not data.count then return end
  Semantic.idf = data.idf or {}
  for k, v in pairs (data) do
    if k ~= "config" and k ~= "idf" and k ~= "count" and type (v) == "table" and v.text then
      Semantic.embeddings[k] = {
        id = k,
        vector = Semantic.embed (v.text) or {},
        text = v.text,
        kind = v.kind or "chunk",
        source = v.source or "",
        created = v.created or 0,
      }
    end
  end
  log.info ("Semantic: restored " .. (data.count or 0) .. " embeddings")
end

--- Command handlers
Semantic.commands = {
  semantic = {
    enabled = true,
    args = 0,
    name = "semantic",
    callback = function (_)
      local count = 0
      for _ in pairs (Semantic.embeddings) do count = count + 1 end
      vim.notify ("Semantic: " .. count .. " embeddings indexed", vim.log.levels.INFO)
    end,
    commands = {
      index = {
        enabled = true,
        args = 0,
        name = "semantic.index",
        callback = function ()
          Semantic.index_knowledge ()
          vim.notify ("Semantic: indexed knowledge graph entities", vim.log.levels.INFO)
        end,
      },
      search = {
        enabled = true,
        args = 1,
        name = "semantic.search",
        complete = function () return {} end,
        callback = function (e)
          local query = e.body and e.body[1] or ""
          local results = Semantic.search (query)
          if #results == 0 then
            vim.notify ("Semantic: no results for '" .. query .. "'", vim.log.levels.WARN)
            return
          end
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = { "# Semantic Search: " .. query, "" }
          for i, r in ipairs (results) do
            lines[#lines + 1] = string.format ("## %d. %s (%.2f)", i, r.id, r.score)
            lines[#lines + 1] = "```"
            local preview = r.text:sub (1, 300)
            for _, l in ipairs (vim.split (preview, "\n")) do
              lines[#lines + 1] = l
            end
            lines[#lines + 1] = "```"
            lines[#lines + 1] = ""
          end
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.api.nvim_set_current_buf (buf)
          vim.bo[buf].filetype = "markdown"
        end,
      },
      classify = {
        enabled = true,
        args = 1,
        name = "semantic.classify",
        callback = function (e)
          local text = e.body and e.body[1] or ""
          local hits = {}
          for id, emb in pairs (Semantic.embeddings) do
            local score = Semantic.cosine (Semantic.embed (text) or {}, emb.vector)
            if score > 0.3 and emb.kind == "entity" then
              hits[#hits + 1] = string.format ("%s (%.2f)", id:gsub ("^entity:", ""), score)
            end
          end
          if #hits == 0 then
            vim.notify ("Semantic: no classification matches", vim.log.levels.INFO)
          else
            vim.notify ("Related: " .. table.concat (hits, ", "), vim.log.levels.INFO)
          end
        end,
      },
      idf = {
        enabled = true,
        args = 0,
        name = "semantic.idf",
        callback = function ()
          Semantic.build_idf ()
          local count = 0
          for _ in pairs (Semantic.idf) do count = count + 1 end
          vim.notify ("Semantic: built IDF vocabulary (" .. count .. " terms)", vim.log.levels.INFO)
        end,
      },
    },
  },
}

return Semantic
