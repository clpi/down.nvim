--- down.skills - Generate project SKILL.md for AI agent context.
--- Aggregates filesystem analysis + knowledge graph entities, semantic
--- embeddings, memory entries, and ingested data for comprehensive output.

local skills = {}

skills.config = {
  output = "SKILL.md",
  include_architecture = true,
  include_conventions = true,
  include_dependencies = true,
  include_entry_points = true,
  include_knowledge = true,
  include_vector = true,
  include_memory = true,
  include_data = true,
  max_depth = 3,
}

-- ─── filesystem detectors ───────────────────────────────────────

local function detect_dependencies (root)
  local deps = {}
  local files = {
    { "package.json", "npm" },
    { "Cargo.toml", "cargo" },
    { "go.mod", "go" },
    { "requirements.txt", "pip" },
    { "pyproject.toml", "pip/poetry" },
    { "Gemfile", "bundler" },
    { "mix.exs", "mix" },
    { "build.gradle", "gradle" },
    { "pom.xml", "maven" },
    { "composer.json", "composer" },
    { "Justfile", "just" },
    { "Makefile", "make" },
    { "CMakeLists.txt", "cmake" },
    { "stylua.toml", "stylua" },
    { "selene.toml", "selene" },
    { ".luarc.json", "lua-language-server" },
    { "down-scm-1.rockspec", "luarocks" },
  }
  for _, f in ipairs (files) do
    local handle = io.open (root .. "/" .. f[1], "r")
    if handle then
      handle:close ()
      deps[f[1]] = f[2]
    end
  end
  return deps
end

local function detect_entry_points (root)
  local entries = {}
  local patterns = {
    "^main%.lua$",
    "^init%.lua$",
    "^main%.go$",
    "^index%.js$",
    "^index%.ts$",
    "^main%.py$",
    "^__init__%.py$",
    "^main%.rs$",
    "^lib%.rs$",
    "^main%.rb$",
    "^App%.hs$",
    "^Main%.hs$",
  }
  local handle = io.popen ('ls "' .. root .. '" 2>/dev/null')
  if handle then
    for name in handle:lines () do
      for _, p in ipairs (patterns) do
        if name:match (p) then
          entries[#entries + 1] = name
          break
        end
      end
    end
    handle:close ()
  end
  return entries
end

local function detect_structure (root, depth)
  depth = depth or 0
  if depth > skills.config.max_depth then
    return {}
  end
  local lines = {}
  local handle = io.popen ('ls -A "' .. root .. '" 2>/dev/null')
  if not handle then
    return lines
  end
  for name in handle:lines () do
    if name:sub (1, 1) ~= "." or name == ".github" then
      local full = root .. "/" .. name
      local ah = io.popen ('test -d "' .. full .. '" && echo d || echo f')
      local attr = ah and ah:read ("*l") or "f"
      if ah then
        ah:close ()
      end
      local indent = string.rep ("  ", depth)
      if attr == "d" then
        lines[#lines + 1] = indent .. name .. "/"
        local sub = detect_structure (full, depth + 1)
        for _, s in ipairs (sub) do
          lines[#lines + 1] = s
        end
      else
        lines[#lines + 1] = indent .. name
      end
    end
  end
  handle:close ()
  return lines
end

local function detect_conventions (root)
  local conventions = {}
  local patterns = {
    { "lua/", "Lua source in lua/" },
    { "src/", "Source in src/" },
    { "lib/", "Library code in lib/" },
    { "test/", "Tests in test/" },
    { "spec/", "Specs in spec/" },
    { "tests/", "Tests in tests/" },
    { "scripts/", "Scripts in scripts/" },
    { "docs/", "Documentation in docs/" },
    { "ext/", "External dependencies in ext/" },
    { "queries/", "Treesitter queries in queries/" },
    { "plugin/", "Neovim plugin entry" },
    { ".github/workflows/", "CI/CD via GitHub Actions" },
    { "book/", "mdBook documentation" },
    { "assets/", "Static assets" },
  }
  for _, p in ipairs (patterns) do
    local handle =
      io.popen ('test -d "' .. root .. "/" .. p[1] .. '" && echo yes')
    if handle then
      local result = handle:read ("*l")
      handle:close ()
      if result == "yes" then
        conventions[#conventions + 1] = p[2]
      end
    end
  end
  return conventions
end

local function detect_languages (root)
  local exts = {}
  local ext_map = {
    lua = "Lua",
    go = "Go",
    js = "JavaScript",
    ts = "TypeScript",
    jsx = "React JSX",
    tsx = "React TSX",
    py = "Python",
    rs = "Rust",
    rb = "Ruby",
    java = "Java",
    c = "C",
    cpp = "C++",
    h = "C/C++ Header",
    hpp = "C++ Header",
    html = "HTML",
    css = "CSS",
    scss = "SCSS",
    md = "Markdown",
    json = "JSON",
    yaml = "YAML",
    yml = "YAML",
    toml = "TOML",
    sh = "Shell",
    bash = "Bash",
    zsh = "Zsh",
    vim = "Vimscript",
    vim9 = "Vim9script",
    nu = "Nushell",
    sql = "SQL",
    graphql = "GraphQL",
    proto = "Protobuf",
    dockerfile = "Dockerfile",
    makefile = "Makefile",
  }
  local handle = io.popen (
    'find "'
      .. root
      .. '" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null | head -1000'
  )
  if handle then
    for path in handle:lines () do
      local ext = path:match ("%.([^.]+)$")
      if ext and ext_map[ext:lower ()] and not exts[ext:lower ()] then
        exts[ext:lower ()] = ext_map[ext:lower ()]
      end
    end
    handle:close ()
  end
  local result = {}
  for _, lang in pairs (exts) do
    result[#result + 1] = lang
  end
  table.sort (result)
  return result
end

-- ─── data source loaders ────────────────────────────────────────

local function find_down_dir (root)
  local dir = root
  while dir and dir ~= "/" do
    local dd = dir .. "/.down"
    local f = io.open (dd .. "/down.json", "r")
    if f then
      f:close ()
      return dd
    end
    local parent = dir:match ("^(.*)/")
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
  return nil
end

local function load_json (path)
  local f = io.open (path, "r")
  if not f then
    return nil
  end
  local content = f:read ("*a")
  f:close ()
  if not content or content == "" then
    return nil
  end
  local ok, data = pcall (vim.json.decode, content)
  if ok then
    return data
  end
  return nil
end

local function load_knowledge (downDir)
  local path = downDir .. "/knowledge/entities.json"
  return load_json (path)
end

local function load_vector_stats (downDir)
  local path = downDir .. "/vector/model.json"
  return load_json (path)
end

local function load_memory_entries (downDir)
  local path = downDir .. "/memory/index.json"
  local index = load_json (path)
  if not index or not index.entries then
    return nil
  end
  local entries = {}
  for _, name in ipairs (index.entries) do
    local data = load_json (downDir .. "/memory/" .. name)
    if data then
      entries[#entries + 1] = data
    end
  end
  return entries
end

local function load_data_files (downDir)
  local path = downDir .. "/data/index.json"
  local index = load_json (path)
  if not index or not index.files then
    return nil
  end
  local files = {}
  for _, name in ipairs (index.files) do
    local dp = downDir .. "/data/" .. name
    local f = io.open (dp, "r")
    if f then
      local content = f:read ("*a")
      f:close ()
      local title = name
      local source = ""
      if content:match ("^%-%-%-") then
        local endPos = content:find ("\n%-%-%-\n", 5)
        if endPos then
          local fm = content:sub (5, endPos - 1)
          title = fm:match ("title:%s*(.+)") or name
          source = fm:match ("source:%s*(.+)") or ""
        end
      end
      files[#files + 1] = { file = name, title = title, source = source }
    end
  end
  return files
end

-- ─── generate ───────────────────────────────────────────────────

function skills.generate (root, opts)
  local is_vim = vim ~= nil
  root = root or (is_vim and vim.fn.getcwd ()) or io.popen ("pwd"):read ("*l")
  if opts then
    for k, v in pairs (opts) do
      skills.config[k] = v
    end
  end

  local name = root:match ("[^/]+$") or "project"
  local downDir = nil
  if
    is_vim and skills.config.include_knowledge
    or skills.config.include_vector
    or skills.config.include_memory
    or skills.config.include_data
  then
    downDir = find_down_dir (root)
  end

  local out = {}

  out[#out + 1] = "# " .. name
  out[#out + 1] = ""

  out[#out + 1] = "## Project Overview"
  out[#out + 1] = ""
  out[#out + 1] = "<!-- Brief description of what this project does -->"
  out[#out + 1] = ""

  local languages = detect_languages (root)
  if #languages > 0 then
    out[#out + 1] = "**Languages:** " .. table.concat (languages, ", ")
    out[#out + 1] = ""
  end

  if skills.config.include_entry_points then
    local entries = detect_entry_points (root)
    if #entries > 0 then
      out[#out + 1] = "## Entry Points"
      out[#out + 1] = ""
      for _, e in ipairs (entries) do
        out[#out + 1] = "- `" .. e .. "`"
      end
      out[#out + 1] = ""
    end
  end

  if skills.config.include_dependencies then
    local deps = detect_dependencies (root)
    local count = 0
    for _ in pairs (deps) do
      count = count + 1
    end
    if count > 0 then
      out[#out + 1] = "## Dependencies"
      out[#out + 1] = ""
      for file, manager in pairs (deps) do
        out[#out + 1] = "- `" .. file .. "` (" .. manager .. ")"
      end
      out[#out + 1] = ""
    end
  end

  if skills.config.include_architecture then
    out[#out + 1] = "## Project Structure"
    out[#out + 1] = ""
    out[#out + 1] = "```"
    local structure = detect_structure (root)
    for _, line in ipairs (structure) do
      out[#out + 1] = line
    end
    out[#out + 1] = "```"
    out[#out + 1] = ""
  end

  if skills.config.include_conventions then
    local conventions = detect_conventions (root)
    if #conventions > 0 then
      out[#out + 1] = "## Conventions"
      out[#out + 1] = ""
      for _, c in ipairs (conventions) do
        out[#out + 1] = "- " .. c
      end
      out[#out + 1] = ""
    end
  end

  -- ─── rich data sections ───────────────────────────────────────

  out[#out + 1] = "## Key Modules"
  out[#out + 1] = ""

  if downDir and skills.config.include_knowledge then
    local kb = load_knowledge (downDir)
    if kb and #kb > 0 then
      out[#out + 1] = "### Knowledge Graph Entities"
      out[#out + 1] = ""
      local tags = {}
      local concepts = {}
      for _, ent in ipairs (kb) do
        if ent.kind == "tag" then
          tags[#tags + 1] = ent.name
        elseif ent.kind == "concept" then
          concepts[#concepts + 1] = ent
        end
      end
      if #tags > 0 then
        table.sort (tags)
        if #tags > 30 then
          local t = {}
          for i = 1, 30 do
            t[i] = tags[i]
          end
          tags = t
        end
        out[#out + 1] = "**Tags ("
          .. #tags
          .. "):** "
          .. table.concat (tags, ", ")
        out[#out + 1] = ""
      end
      if #concepts > 0 then
        out[#out + 1] = "**Wiki-linked concepts:**"
        out[#out + 1] = ""
        for _, c in ipairs (concepts) do
          local files = c.file or ""
          local count = 0
          for _ in files:gmatch (",") do
            count = count + 1
          end
          out[#out + 1] = "- `[["
            .. c.name
            .. "]]` — in "
            .. (count + 1)
            .. " file(s)"
        end
      end
      out[#out + 1] = ""
    end
  end

  if downDir and skills.config.include_vector then
    local vs = load_vector_stats (downDir)
    if vs then
      out[#out + 1] = "### Semantic Topics"
      out[#out + 1] = ""
      if vs.doc_count then
        out[#out + 1] = "- **Embedded documents:** " .. vs.doc_count
      end
      if vs.dimension then
        out[#out + 1] = "- **Vector dimension:** " .. vs.dimension
      end
      if vs.idf then
        local termCount = 0
        for _ in pairs (vs.idf) do
          termCount = termCount + 1
        end
        out[#out + 1] = "- **IDF vocabulary:** " .. termCount .. " terms"
      end
      out[#out + 1] = ""
    end
  end

  if downDir and skills.config.include_memory then
    local mems = load_memory_entries (downDir)
    if mems and #mems > 0 then
      out[#out + 1] = "## Memory"
      out[#out + 1] = ""
      out[#out + 1] = "Persisted knowledge from workspace memory."
      out[#out + 1] = ""
      for _, m in ipairs (mems) do
        local key = m.key or "?"
        local val = m.value or ""
        if val == "" then
          val = m.content or ""
        end
        val = val:gsub ("\n", " ")
        if #val > 200 then
          val = val:sub (1, 200) .. "..."
        end
        out[#out + 1] = "- **" .. key .. ":** " .. val
      end
      out[#out + 1] = ""
    end
  end

  if downDir and skills.config.include_data then
    local files = load_data_files (downDir)
    if files and #files > 0 then
      out[#out + 1] = "## Referenced Content"
      out[#out + 1] = ""
      out[#out + 1] = "Content ingested from URLs and external sources."
      out[#out + 1] = ""
      for _, df in ipairs (files) do
        local line = "- **" .. (df.title or df.file)
        if df.source and df.source ~= "" then
          line = line .. "** — <" .. df.source .. ">"
        end
        out[#out + 1] = line
      end
      out[#out + 1] = ""
    end
  end

  out[#out + 1] = "## Commands"
  out[#out + 1] = ""
  out[#out + 1] = "```bash"
  out[#out + 1] = "# Build"
  out[#out + 1] = "# Test"
  out[#out + 1] = "# Lint"
  out[#out + 1] = "```"

  local content = table.concat (out, "\n")

  if skills.config.output then
    local f = io.open (skills.config.output, "w")
    if f then
      f:write (content)
      f:close ()
    end
  end

  return content
end

function skills.cli (args)
  local root = nil
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--output" or a == "-o" then
      i = i + 1
      skills.config.output = args[i]
    elseif a == "--no-arch" then
      skills.config.include_architecture = false
    elseif a == "--no-deps" then
      skills.config.include_dependencies = false
    elseif a == "--no-entries" then
      skills.config.include_entry_points = false
    elseif a == "--no-conventions" then
      skills.config.include_conventions = false
    elseif a == "--no-knowledge" then
      skills.config.include_knowledge = false
    elseif a == "--no-vector" then
      skills.config.include_vector = false
    elseif a == "--no-memory" then
      skills.config.include_memory = false
    elseif a == "--no-data" then
      skills.config.include_data = false
    elseif a == "--help" or a == "-h" then
      print ([["down skills" - Generate a project SKILL.md for AI agents

Usage: down skills [options] [directory]

Options:
  -o, --output FILE     Output path (default: SKILL.md)
  --no-arch             Skip architecture section
  --no-deps             Skip dependencies section
  --no-entries          Skip entry points section
  --no-conventions      Skip conventions section
  --no-knowledge        Skip knowledge graph entities
  --no-vector           Skip semantic/embedding topics
  --no-memory           Skip memory entries
  --no-data             Skip ingested data references
  -h, --help            Show this help]])
      return
    elseif a:sub (1, 1) ~= "-" then
      root = a
    end
    i = i + 1
  end

  local result = skills.generate (root)
  if skills.config.output then
    print ("Wrote " .. skills.config.output)
  else
    print (result)
  end
end

return skills
