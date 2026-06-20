--- data.semantic - Embedding models and semantic search
--- Generates, stores, and queries vector embeddings for knowledge graph
--- entities, documents, and arbitrary text chunks — all on-device.

local log = require ("down.log")
local mod = require ("down.mod")

---@class down.mod.data.semantic.Semantic: down.Mod
local Semantic = mod.new ("data.semantic")
Semantic.dep = { "data", "cmd", "workspace" }

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
  --- Use n-grams (bigrams, trigrams) for local embeddings
  use_ngrams = true,
  --- Number of hash seeds for multi-hash embeddings
  hash_seeds = 4,
  --- Use sublinear TF scaling (1 + log(tf))
  sublinear_tf = true,
  --- Clustering: number of clusters for k-means
  cluster_k = 5,
  --- Clustering: max iterations
  cluster_max_iter = 20,
  --- Dedup: similarity threshold for near-duplicates
  dedup_threshold = 0.92,
}

-- Stop words for filtering common terms
local stop_list = {
  "the",
  "a",
  "an",
  "and",
  "or",
  "but",
  "in",
  "on",
  "at",
  "to",
  "for",
  "of",
  "with",
  "by",
  "from",
  "up",
  "about",
  "into",
  "through",
  "during",
  "before",
  "after",
  "above",
  "below",
  "between",
  "out",
  "off",
  "over",
  "under",
  "again",
  "further",
  "then",
  "once",
  "here",
  "there",
  "when",
  "where",
  "why",
  "how",
  "all",
  "both",
  "each",
  "few",
  "more",
  "most",
  "other",
  "some",
  "such",
  "no",
  "nor",
  "not",
  "only",
  "own",
  "same",
  "so",
  "than",
  "too",
  "very",
  "s",
  "t",
  "can",
  "will",
  "just",
  "should",
  "now",
  "is",
  "are",
  "was",
  "were",
  "be",
  "been",
  "being",
  "have",
  "has",
  "had",
  "having",
  "do",
  "does",
  "did",
  "doing",
  "would",
  "could",
  "shall",
  "may",
  "might",
  "must",
  "it",
  "its",
  "itself",
  "they",
  "them",
  "their",
  "theirs",
  "themselves",
  "what",
  "which",
  "who",
  "whom",
  "this",
  "that",
  "these",
  "those",
  "am",
  "i",
  "me",
  "my",
  "myself",
  "we",
  "our",
  "ours",
  "ourselves",
  "you",
  "your",
  "yours",
  "yourself",
  "yourselves",
  "he",
  "him",
  "his",
  "himself",
  "she",
  "her",
  "hers",
  "herself",
  "as",
  "if",
  "because",
  "until",
  "while",
  "also",
}
Semantic.stop_words = {}
for _, w in ipairs (stop_list) do
  Semantic.stop_words[w] = true
end

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
Semantic.centroids = {}
Semantic.clusters = {}
Semantic.cluster_labels = {}

---@return down.mod.Setup
Semantic.setup = function ()
  Semantic.restore ()
  return { loaded = true }
end

--- Enhanced tokenizer with n-grams, stop-word filtering, and punctuation handling.
---@param text string
---@param opts? { ngrams?: boolean, filter_stops?: boolean }
---@return string[]
function Semantic.tokenize (text, opts)
  opts = opts or {}
  local use_ngrams = opts.ngrams
  if use_ngrams == nil then
    use_ngrams = Semantic.config.use_ngrams
  end
  local filter_stops = opts.filter_stops
  if filter_stops == nil then
    filter_stops = true
  end

  local unigrams = {}
  for word in text:gmatch ("[%w_]+") do
    local lower = word:lower ()
    if #lower > 1 and (not filter_stops or not Semantic.stop_words[lower]) then
      unigrams[#unigrams + 1] = lower
    end
  end

  if not use_ngrams then
    return unigrams
  end

  local tokens = {}
  for _, t in ipairs (unigrams) do
    tokens[#tokens + 1] = t
  end
  for i = 1, #unigrams - 1 do
    tokens[#tokens + 1] = unigrams[i] .. "_" .. unigrams[i + 1]
  end
  for i = 1, #unigrams - 2 do
    tokens[#tokens + 1] = unigrams[i]
      .. "_"
      .. unigrams[i + 1]
      .. "_"
      .. unigrams[i + 2]
  end

  return tokens
end

--- Multi-hash: returns multiple bucket indices for a token using different seeds.
---@param word string
---@param dim number
---@param seeds? number
---@return number[]
local function multi_hash (word, dim, seeds)
  seeds = seeds or Semantic.config.hash_seeds
  local indices = {}
  for s = 0, seeds - 1 do
    local h = s
    for i = 1, #word do
      h = (h * 31 + word:byte (i)) % 1000003
    end
    indices[#indices + 1] = (h % dim) + 1
  end
  return indices
end

--- Generate a local bag-of-words embedding vector with multi-hash and sublinear TF.
---@param text string
---@param dim number
---@return number[]
function Semantic.embed_local (text, dim)
  dim = dim or Semantic.config.dimension or 384
  local tokens = Semantic.tokenize (text)
  if #tokens == 0 then
    local v = {}
    for i = 1, dim do
      v[i] = 0
    end
    return v
  end

  local tf = {}
  for _, token in ipairs (tokens) do
    tf[token] = (tf[token] or 0) + 1
  end

  local vector = {}
  for i = 1, dim do
    vector[i] = 0
  end

  for token, count in pairs (tf) do
    local weight = Semantic.config.sublinear_tf and math.log (1 + count)
      or count
    if Semantic.idf[token] then
      weight = weight * Semantic.idf[token]
    end
    local indices = multi_hash (token, dim)
    for _, idx in ipairs (indices) do
      vector[idx] = vector[idx] + weight
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
  local endpoint = Semantic.config.endpoint
    or "http://localhost:11434/api/embeddings"
  local model = Semantic.config.model
  local body = vim.json.encode ({ model = model, prompt = text })
  local cmd = string.format (
    "curl -s -X POST '%s' -H 'Content-Type: application/json' -d '%s' 2>/dev/null",
    endpoint,
    body:gsub ("'", "'\\''")
  )
  local handle = io.popen (cmd)
  if not handle then
    return nil, "curl failed"
  end
  local result = handle:read ("*a")
  handle:close ()
  if not result or result == "" then
    return nil, "empty response"
  end
  local ok, parsed = pcall (vim.json.decode, result)
  if not ok or not parsed.embedding then
    return nil, "parse failed: " .. tostring (result)
  end
  return parsed.embedding
end

--- Call OpenAI-compatible embeddings API
---@param text string
---@return number[]|nil, string|nil
function Semantic.embed_openai (text)
  local endpoint = Semantic.config.endpoint
    or "https://api.openai.com/v1/embeddings"
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
  if not handle then
    return nil, "curl failed"
  end
  local result = handle:read ("*a")
  handle:close ()
  if not result or result == "" then
    return nil, "empty response"
  end
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
  if not a or not b then
    return 0
  end
  local dot, na, nb = 0, 0, 0
  for i = 1, math.min (#a, #b) do
    dot = dot + a[i] * b[i]
    na = na + a[i] * a[i]
    nb = nb + b[i] * b[i]
  end
  na, nb = math.sqrt (na), math.sqrt (nb)
  if na == 0 or nb == 0 then
    return 0
  end
  return dot / (na * nb)
end

--- Euclidean distance (normalized 0-1, where 1 = identical)
---@param a number[]
---@param b number[]
---@return number
function Semantic.euclidean (a, b)
  if not a or not b then
    return 0
  end
  local sum = 0
  for i = 1, math.min (#a, #b) do
    local diff = a[i] - b[i]
    sum = sum + diff * diff
  end
  return 1 / (1 + math.sqrt (sum))
end

--- Dot product (unnormalized)
---@param a number[]
---@param b number[]
---@return number
function Semantic.dot (a, b)
  if not a or not b then
    return 0
  end
  local d = 0
  for i = 1, math.min (#a, #b) do
    d = d + a[i] * b[i]
  end
  return d
end

--- Manhattan distance normalized (0-1, 1 = identical)
---@param a number[]
---@param b number[]
---@return number
function Semantic.manhattan (a, b)
  if not a or not b then
    return 0
  end
  local sum = 0
  local m = math.min (#a, #b)
  for i = 1, m do
    sum = sum + math.abs (a[i] - b[i])
  end
  return 1 / (1 + sum / m)
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
    log.warn (
      "Semantic.index: failed to embed '" .. id .. "': " .. (err or "unknown")
    )
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
  if not query_vec then
    return {}
  end

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

  table.sort (results, function (a, b)
    return a.score > b.score
  end)

  if #results > limit then
    local trimmed = {}
    for i = 1, limit do
      trimmed[i] = results[i]
    end
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
    Semantic.index (
      "entity:" .. id,
      text,
      { kind = "entity", source = entity.file or "" }
    )
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

--- Compute a document centroid by averaging all chunk embeddings from a source file.
---@param source string
---@return number[]|nil
function Semantic.doc_centroid (source)
  local vectors = {}
  for _, emb in pairs (Semantic.embeddings) do
    if emb.source == source then
      vectors[#vectors + 1] = emb.vector
    end
  end
  if #vectors == 0 then
    return nil
  end

  local dim = #vectors[1]
  local centroid = {}
  for i = 1, dim do
    centroid[i] = 0
  end
  for _, v in ipairs (vectors) do
    for i = 1, dim do
      centroid[i] = centroid[i] + v[i]
    end
  end
  local n = #vectors
  for i = 1, dim do
    centroid[i] = centroid[i] / n
  end

  -- L2 normalize
  local norm = 0
  for _, v in ipairs (centroid) do
    norm = norm + v * v
  end
  norm = math.sqrt (norm)
  if norm > 0 then
    for i = 1, dim do
      centroid[i] = centroid[i] / norm
    end
  end

  Semantic.centroids[source] = centroid
  return centroid
end

--- Build centroids for all indexed sources.
function Semantic.build_centroids ()
  local sources = {}
  for _, emb in pairs (Semantic.embeddings) do
    if emb.source ~= "" then
      sources[emb.source] = true
    end
  end
  Semantic.centroids = {}
  for source in pairs (sources) do
    Semantic.doc_centroid (source)
  end
end

--- K-means clustering of all embeddings into k clusters.
--- Returns cluster assignments { id -> cluster_index } and cluster centroids.
---@param k? number
---@param max_iter? number
---@return table<string, number>, number[][]
function Semantic.cluster (k, max_iter)
  k = k or Semantic.config.cluster_k
  max_iter = max_iter or Semantic.config.cluster_max_iter
  local ids = {}
  for id in pairs (Semantic.embeddings) do
    ids[#ids + 1] = id
  end
  if #ids == 0 then
    return {}, {}
  end
  if k > #ids then
    k = #ids
  end

  local dim = #Semantic.embeddings[ids[1]].vector
  local centroids = {}
  for c = 1, k do
    local seed = Semantic.embeddings[ids[math.random (#ids)]]
    centroids[c] = {}
    for i = 1, dim do
      centroids[c][i] = seed.vector[i]
    end
  end

  for iter = 1, max_iter do
    local assignments = {}
    for _, id in ipairs (ids) do
      local best_c, best_sim = 1, -2
      for c = 1, k do
        local sim =
          Semantic.cosine (Semantic.embeddings[id].vector, centroids[c])
        if sim > best_sim then
          best_sim = sim
          best_c = c
        end
      end
      assignments[id] = best_c
    end

    local new_centroids = {}
    local counts = {}
    for c = 1, k do
      new_centroids[c] = {}
      for i = 1, dim do
        new_centroids[c][i] = 0
      end
      counts[c] = 0
    end
    for _, id in ipairs (ids) do
      local c = assignments[id]
      counts[c] = counts[c] + 1
      local v = Semantic.embeddings[id].vector
      for i = 1, dim do
        new_centroids[c][i] = new_centroids[c][i] + v[i]
      end
    end
    for c = 1, k do
      if counts[c] > 0 then
        for i = 1, dim do
          new_centroids[c][i] = new_centroids[c][i] / counts[c]
        end
      end
      local norm = 0
      for _, v in ipairs (new_centroids[c]) do
        norm = norm + v * v
      end
      norm = math.sqrt (norm)
      if norm > 0 then
        for i = 1, dim do
          new_centroids[c][i] = new_centroids[c][i] / norm
        end
      end
    end

    local moved = 0
    for c = 1, k do
      if Semantic.cosine (centroids[c], new_centroids[c]) < 0.999 then
        moved = moved + 1
      end
    end
    centroids = new_centroids
    if moved == 0 then
      break
    end
  end

  local assignments = {}
  for _, id in ipairs (ids) do
    local best_c = 1
    local best_sim =
      Semantic.cosine (Semantic.embeddings[id].vector, centroids[1])
    for c = 2, k do
      local sim = Semantic.cosine (Semantic.embeddings[id].vector, centroids[c])
      if sim > best_sim then
        best_sim = sim
        best_c = c
      end
    end
    assignments[id] = best_c
  end

  Semantic.clusters = assignments
  return assignments, centroids
end

--- Extract topic labels for each cluster using top TF-IDF terms.
---@param assignments table<string, number>
---@param topn? number
---@return table<number, string[]>
function Semantic.label_clusters (assignments, topn)
  topn = topn or 5
  local cluster_docs = {}
  for id, c in pairs (assignments) do
    if not cluster_docs[c] then
      cluster_docs[c] = {}
    end
    cluster_docs[c][#cluster_docs[c] + 1] = Semantic.embeddings[id].text
  end

  local labels = {}
  for c, docs in pairs (cluster_docs) do
    local tf = {}
    local df = {}
    local n = #docs
    for _, doc in ipairs (docs) do
      local seen = {}
      for token in doc:gmatch ("[%w_]+") do
        local t = token:lower ()
        if #t > 2 and not Semantic.stop_words[t] then
          tf[t] = (tf[t] or 0) + 1
          if not seen[t] then
            seen[t] = true
            df[t] = (df[t] or 0) + 1
          end
        end
      end
    end

    local scored = {}
    for token, freq in pairs (tf) do
      local idf = math.log ((n + 1) / ((df[token] or 0) + 1))
      scored[#scored + 1] = { token = token, score = freq * idf }
    end
    table.sort (scored, function (a, b)
      return a.score > b.score
    end)

    local top = {}
    for i = 1, math.min (topn, #scored) do
      top[#top + 1] = scored[i].token
    end
    labels[c] = top
  end

  Semantic.cluster_labels = labels
  return labels
end

--- Find near-duplicate embeddings.
---@param threshold? number
---@return { id1: string, id2: string, score: number }[]
function Semantic.dedup (threshold)
  threshold = threshold or Semantic.config.dedup_threshold
  local ids = {}
  for id in pairs (Semantic.embeddings) do
    ids[#ids + 1] = id
  end

  local dups = {}
  for i = 1, #ids do
    for j = i + 1, #ids do
      local score = Semantic.cosine (
        Semantic.embeddings[ids[i]].vector,
        Semantic.embeddings[ids[j]].vector
      )
      if score >= threshold then
        dups[#dups + 1] = { id1 = ids[i], id2 = ids[j], score = score }
      end
    end
  end
  table.sort (dups, function (a, b)
    return a.score > b.score
  end)
  return dups
end

--- Compute embedding quality statistics.
---@return { count: number, dim: number, sparsity: number, mean_norm: number, coverage: number }
function Semantic.stats ()
  local count = 0
  local dim = Semantic.config.dimension or 384
  local total_nonzero = 0
  local total_norm = 0
  for _ in pairs (Semantic.embeddings) do
    count = count + 1
  end
  if count == 0 then
    return { count = 0, dim = dim, sparsity = 1, mean_norm = 0, coverage = 0 }
  end

  for _, emb in pairs (Semantic.embeddings) do
    local nnz = 0
    local norm = 0
    for _, v in ipairs (emb.vector) do
      if v ~= 0 then
        nnz = nnz + 1
      end
      norm = norm + v * v
    end
    total_nonzero = total_nonzero + nnz
    total_norm = total_norm + math.sqrt (norm)
  end

  local sparsity = 1 - (total_nonzero / (count * dim))
  local mean_norm = total_norm / count

  local total_tokens = 0
  local covered = 0
  for _, w in pairs (Semantic.idf) do
    total_tokens = total_tokens + 1
    if w > 0 then
      covered = covered + 1
    end
  end
  local coverage = total_tokens > 0 and (covered / total_tokens) or 0

  return {
    count = count,
    dim = dim,
    sparsity = sparsity,
    mean_norm = mean_norm,
    coverage = coverage,
  }
end

--- Compare two texts and return similarity score plus shared terms.
---@param a string
---@param b string
---@return number, string[]
function Semantic.compare (a, b)
  local vec_a = Semantic.embed (a)
  local vec_b = Semantic.embed (b)
  local score = Semantic.cosine (vec_a, vec_b)

  local tokens_a = {}
  for token in a:gmatch ("[%w_]+") do
    local t = token:lower ()
    if #t > 2 and not Semantic.stop_words[t] then
      tokens_a[t] = true
    end
  end
  local shared = {}
  for token in b:gmatch ("[%w_]+") do
    local t = token:lower ()
    if tokens_a[t] then
      shared[#shared + 1] = t
      tokens_a[t] = nil
    end
  end

  return score, shared
end

--- Index all markdown files in the workspace.
function Semantic.index_workspace ()
  local workspace = Semantic.dep["workspace"]
  if not workspace or not workspace.root then
    log.warn ("Semantic.index_workspace: no workspace")
    return
  end
  local root = workspace.root ()
  if not root then
    log.warn ("Semantic.index_workspace: no workspace root")
    return
  end
  local scanned = 0
  local function walk (dir)
    local handle = vim.loop.fs_scandir (dir)
    if not handle then
      return
    end
    while true do
      local name, kind = vim.loop.fs_scandir_next (handle)
      if not name then
        break
      end
      if name:sub (1, 1) ~= "." then
        local full = dir .. "/" .. name
        if kind == "directory" then
          walk (full)
        elseif kind == "file" and name:match ("%.md$") then
          local fd = io.open (full, "r")
          if fd then
            local content = fd:read ("*a")
            fd:close ()
            Semantic.index_file (full, content)
            scanned = scanned + 1
          end
        end
      end
    end
  end
  walk (root)
  Semantic.build_idf ()
  log.info ("Semantic: indexed " .. scanned .. " workspace files")
  return scanned
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
    centroids = Semantic.centroids or {},
    clusters = Semantic.clusters or {},
    cluster_labels = Semantic.cluster_labels or {},
    count = 0,
  }
  for id, emb in pairs (Semantic.embeddings) do
    data[id] = {
      text = emb.text,
      kind = emb.kind,
      source = emb.source,
      created = emb.created,
    }
    data.count = data.count + 1
  end
  Semantic.dep["data"].set ("semantic.store", data)
  Semantic.dep["data"].flush ()
end

--- Restore embeddings from the data store
function Semantic.restore ()
  local data = Semantic.dep["data"].get ("semantic.store")
  if not data or not data.count then
    return
  end
  Semantic.idf = data.idf or {}
  Semantic.centroids = data.centroids or {}
  Semantic.clusters = data.clusters or {}
  Semantic.cluster_labels = data.cluster_labels or {}
  for k, v in pairs (data) do
    if
      k ~= "config"
      and k ~= "idf"
      and k ~= "centroids"
      and k ~= "clusters"
      and k ~= "cluster_labels"
      and k ~= "count"
      and type (v) == "table"
      and v.text
    then
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
      for _ in pairs (Semantic.embeddings) do
        count = count + 1
      end
      vim.notify (
        "Semantic: " .. count .. " embeddings indexed",
        vim.log.levels.INFO
      )
    end,
    commands = {
      index = {
        enabled = true,
        args = 0,
        name = "semantic.index",
        callback = function ()
          Semantic.index_knowledge ()
          vim.notify (
            "Semantic: indexed knowledge graph entities",
            vim.log.levels.INFO
          )
        end,
      },
      ["index-workspace"] = {
        enabled = true,
        args = 0,
        name = "semantic.index-workspace",
        callback = function ()
          local n = Semantic.index_workspace ()
          if n then
            vim.notify (
              "Semantic: indexed " .. n .. " workspace files",
              vim.log.levels.INFO
            )
          end
        end,
      },
      search = {
        enabled = true,
        args = 1,
        name = "semantic.search",
        complete = function ()
          return {}
        end,
        callback = function (e)
          local query = e.body and e.body[1] or ""
          local results = Semantic.search (query)
          if #results == 0 then
            vim.notify (
              "Semantic: no results for '" .. query .. "'",
              vim.log.levels.WARN
            )
            return
          end
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = { "# Semantic Search: " .. query, "" }
          for i, r in ipairs (results) do
            lines[#lines + 1] =
              string.format ("## %d. %s (%.2f)", i, r.id, r.score)
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
            local score =
              Semantic.cosine (Semantic.embed (text) or {}, emb.vector)
            if score > 0.3 and emb.kind == "entity" then
              hits[#hits + 1] =
                string.format ("%s (%.2f)", id:gsub ("^entity:", ""), score)
            end
          end
          if #hits == 0 then
            vim.notify (
              "Semantic: no classification matches",
              vim.log.levels.INFO
            )
          else
            vim.notify (
              "Related: " .. table.concat (hits, ", "),
              vim.log.levels.INFO
            )
          end
        end,
      },
      compare = {
        enabled = true,
        args = 2,
        name = "semantic.compare",
        callback = function (e)
          local a = e.body and e.body[1] or ""
          local b = e.body and e.body[2] or ""
          local score, shared = Semantic.compare (a, b)
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = {
            "# Text Comparison",
            "",
            string.format ("Similarity: %.4f", score),
            "",
            "## Shared terms (" .. #shared .. ")",
            "",
            table.concat (shared, ", "),
          }
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.api.nvim_set_current_buf (buf)
          vim.bo[buf].filetype = "markdown"
        end,
      },
      cluster = {
        enabled = true,
        args = "?",
        name = "semantic.cluster",
        callback = function (e)
          local k = tonumber (e.body and e.body[1]) or Semantic.config.cluster_k
          local assignments, _ = Semantic.cluster (k)
          Semantic.label_clusters (assignments)
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = { "# Semantic Clusters (k=" .. k .. ")", "" }
          local cluster_members = {}
          for id, c in pairs (assignments) do
            if not cluster_members[c] then
              cluster_members[c] = {}
            end
            cluster_members[c][#cluster_members[c] + 1] = id
          end
          for c = 1, k do
            local label = Semantic.cluster_labels[c]
                and table.concat (Semantic.cluster_labels[c], ", ")
              or ""
            lines[#lines + 1] = "## Cluster " .. c .. ": " .. label
            local members = cluster_members[c] or {}
            for _, id in ipairs (members) do
              lines[#lines + 1] = "- " .. id
            end
            lines[#lines + 1] = ""
          end
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.api.nvim_set_current_buf (buf)
          vim.bo[buf].filetype = "markdown"
        end,
      },
      dedup = {
        enabled = true,
        args = "?",
        name = "semantic.dedup",
        callback = function (e)
          local threshold = tonumber (e.body and e.body[1])
            or Semantic.config.dedup_threshold
          local dups = Semantic.dedup (threshold)
          if #dups == 0 then
            vim.notify (
              "Semantic: no near-duplicates found (threshold="
                .. threshold
                .. ")",
              vim.log.levels.INFO
            )
            return
          end
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = {
            "# Near-Duplicates (threshold=" .. threshold .. ")",
            "",
            "| Score | ID 1 | ID 2 |",
            "|-------|------|------|",
          }
          for _, d in ipairs (dups) do
            lines[#lines + 1] =
              string.format ("| %.4f | %s | %s |", d.score, d.id1, d.id2)
          end
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.api.nvim_set_current_buf (buf)
          vim.bo[buf].filetype = "markdown"
        end,
      },
      stats = {
        enabled = true,
        args = 0,
        name = "semantic.stats",
        callback = function ()
          local s = Semantic.stats ()
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = {
            "# Embedding Statistics",
            "",
            "| Metric | Value |",
            "|--------|-------|",
            string.format ("| Count | %d |", s.count),
            string.format ("| Dimension | %d |", s.dim),
            string.format ("| Sparsity | %.4f |", s.sparsity),
            string.format ("| Mean norm | %.4f |", s.mean_norm),
            string.format ("| IDF coverage | %.4f |", s.coverage),
          }
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.api.nvim_set_current_buf (buf)
          vim.bo[buf].filetype = "markdown"
        end,
      },
      centroids = {
        enabled = true,
        args = 0,
        name = "semantic.centroids",
        callback = function ()
          Semantic.build_centroids ()
          local c = 0
          for _ in pairs (Semantic.centroids) do
            c = c + 1
          end
          vim.notify (
            "Semantic: built " .. c .. " document centroids",
            vim.log.levels.INFO
          )
        end,
      },
      idf = {
        enabled = true,
        args = 0,
        name = "semantic.idf",
        callback = function ()
          Semantic.build_idf ()
          local count = 0
          for _ in pairs (Semantic.idf) do
            count = count + 1
          end
          vim.notify (
            "Semantic: built IDF vocabulary (" .. count .. " terms)",
            vim.log.levels.INFO
          )
        end,
      },
    },
  },
}

return Semantic
