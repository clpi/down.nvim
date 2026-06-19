--- down.compact - Repomix-like codebase packing
--- Packs a directory into an AI-friendly XML/markdown format,
--- respecting .gitignore and excluding binary/secret files.

local compact = {}

---@class down.compact.Config
compact.config = {
  format = "xml",
  output = nil,
  include = {},
  ignore = { "^%.git/", "^%.svn/", "^node_modules/", "^%.DS_Store$", "%.lock$" },
  max_file_size = 1024 * 1024,
  include_binary = false,
  include_empty = false,
  tree = true,
  tokens = true,
}

-- Binary file extensions
local binary_exts = {
  png = true, jpg = true, jpeg = true, gif = true, bmp = true, ico = true, svg = true,
  pdf = true, doc = true, docx = true, xls = true, xlsx = true, ppt = true, pptx = true,
  zip = true, tar = true, gz = true, bz2 = true, xz = true, zst = true, rar = true, ["7z"] = true,
  exe = true, dll = true, so = true, dylib = true, class = true, o = true, obj = true,
  mp3 = true, mp4 = true, avi = true, mov = true, wav = true, flac = true,
  ttf = true, otf = true, woff = true, woff2 = true, eot = true,
  db = true, sqlite = true, sqlite3 = true,
  wasm = true,
}

-- Approximate token counting per character
local function estimate_tokens(text)
  return math.ceil(#text / 4)
end

--- Check if a path should be ignored
---@param path string
---@param ignores string[]
---@return boolean
local function is_ignored(path, ignores)
  for _, pattern in ipairs(ignores) do
    if path:match(pattern) then
      return true
    end
  end
  return false
end

--- Check if a file is binary
---@param path string
---@return boolean
local function is_binary(path)
  local ext = path:match("%.([^.]+)$")
  if ext and binary_exts[ext:lower()] then
    return true
  end
  local f = io.open(path, "rb")
  if not f then return true end
  local bytes = f:read(1024)
  f:close()
  if not bytes then return true end
  for i = 1, #bytes do
    local b = bytes:byte(i)
    if b == 0 then return true end
  end
  return false
end

--- Load .gitignore patterns from a directory
---@param dir string
---@return string[]
local function load_gitignore(dir)
  local patterns = {}
  local gitignore = dir .. "/.gitignore"
  local f = io.open(gitignore, "r")
  if not f then return patterns end
  for raw_line in f:lines() do
    local ln = raw_line:match("^%s*(.-)%s*$")
    if ln ~= "" and not ln:match("^#") then
      ln = ln:gsub("%.", "%%."):gsub("%*", ".*"):gsub("%?", ".")
      if ln:sub(1, 1) == "/" then
        patterns[#patterns + 1] = "^" .. ln:sub(2)
      else
        patterns[#patterns + 1] = ln
      end
    end
  end
  f:close()
  return patterns
end

--- Walk a directory recursively
---@param dir string
---@param ignores string[]
---@param files table
---@param prefix string
local function walk(dir, ignores, files, prefix)
  prefix = prefix or ""
  local handle = io.popen('ls -A "' .. dir .. '" 2>/dev/null')
  if not handle then return end
  for name in handle:lines() do
    local full = dir .. "/" .. name
    local rel = prefix .. name
    if is_ignored(rel, ignores) then
      goto continue
    end
    local attr = io.popen('test -d "' .. full .. '" && echo d || echo f'):read("*l")
    if attr == "d" then
      files[#files + 1] = { path = rel, type = "dir" }
      walk(full, ignores, files, rel .. "/")
    else
      files[#files + 1] = { path = rel, type = "file" }
    end
    ::continue::
  end
  handle:close()
end

--- Generate a directory tree string
---@param files table
---@return string
local function generate_tree(files)
  local tree = {}
  tree[#tree + 1] = "."
  local stack = {}
  for _, f in ipairs(files) do
    local parts = {}
    for part in f.path:gmatch("[^/]+") do
      parts[#parts + 1] = part
    end
    local depth = #parts
    local indent = ""
    for i = 1, depth - 1 do
      indent = indent .. "  "
    end
    local connector = f.type == "dir" and "/" or ""
    tree[#tree + 1] = indent .. parts[depth] .. connector
  end
  return table.concat(tree, "\n")
end

--- Collect all files in a directory respecting ignores
---@param root string
---@param ignores? string[]
---@return table
function compact.collect(root, ignores)
  ignores = ignores or {}
  local gitignores = load_gitignore(root)
  for _, p in ipairs(gitignores) do
    ignores[#ignores + 1] = p
  end
  for _, p in ipairs(compact.config.ignore) do
    ignores[#ignores + 1] = p
  end
  local files = {}
  walk(root, ignores, files)
  return files
end

--- Read file content safely
---@param path string
---@return string|nil
local function read_file(path)
  local f, err = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

--- Pack files into XML format (repomix-style)
---@param root string
---@param files table
---@return string
local function pack_xml(root, files)
  local out = {}
  local total_tokens = 0
  local file_count = 0

  out[#out + 1] = '<?xml version="1.0" encoding="UTF-8"?>'
  out[#out + 1] = '<project>'
  out[#out + 1] = '  <metadata>'
  out[#out + 1] = '    <source>' .. root .. '</source>'
  out[#out + 1] = '    <generated>' .. os.date("%Y-%m-%dT%H:%M:%S") .. '</generated>'
  out[#out + 1] = '  </metadata>'

  if compact.config.tree then
    out[#out + 1] = '  <structure>'
    local tree = generate_tree(files)
    out[#out + 1] = '  <![CDATA['
    out[#out + 1] = tree
    out[#out + 1] = '  ]]>'
    out[#out + 1] = '  </structure>'
  end

  out[#out + 1] = '  <files>'

  for _, f in ipairs(files) do
    if f.type == "file" then
      local full = root .. "/" .. f.path
      local stat_handle = io.popen('wc -c < "' .. full .. '" 2>/dev/null')
      local size_str = stat_handle and stat_handle:read("*a") or "0"
      if stat_handle then stat_handle:close() end
      local size = tonumber(size_str) or 0

      if size > compact.config.max_file_size then
        goto skip_file
      end
      if not compact.config.include_binary and is_binary(full) then
        goto skip_file
      end

      local content = read_file(full)
      if content == nil then
        goto skip_file
      end
      if not compact.config.include_empty and content:match("^%s*$") then
        goto skip_file
      end

      file_count = file_count + 1
      local tokens = estimate_tokens(content)
      total_tokens = total_tokens + tokens

      out[#out + 1] = '    <file path="' .. f.path .. '" tokens="' .. tokens .. '">'
      out[#out + 1] = '<![CDATA['
      out[#out + 1] = content
      out[#out + 1] = ']]>'
      out[#out + 1] = '    </file>'
      ::skip_file::
    end
  end

  out[#out + 1] = '  </files>'
  if compact.config.tokens then
    out[#out + 1] = '  <tokens total="' .. total_tokens .. '" files="' .. file_count .. '" />'
  end
  out[#out + 1] = '</project>'

  return table.concat(out, "\n")
end

--- Pack files into markdown format
---@param root string
---@param files table
---@return string
local function pack_markdown(root, files)
  local out = {}
  local total_tokens = 0
  local file_count = 0

  out[#out + 1] = "# Project: " .. root:match("[^/]+$")
  out[#out + 1] = ""
  out[#out + 1] = "> Generated: " .. os.date("%Y-%m-%d %H:%M:%S")
  out[#out + 1] = ""

  if compact.config.tree then
    out[#out + 1] = "## Directory Structure"
    out[#out + 1] = ""
    out[#out + 1] = "```"
    out[#out + 1] = generate_tree(files)
    out[#out + 1] = "```"
    out[#out + 1] = ""
  end

  out[#out + 1] = "## Files"
  out[#out + 1] = ""

  for _, f in ipairs(files) do
    if f.type == "file" then
      local full = root .. "/" .. f.path
      local stat_handle = io.popen('wc -c < "' .. full .. '" 2>/dev/null')
      local size_str = stat_handle and stat_handle:read("*a") or "0"
      if stat_handle then stat_handle:close() end
      local size = tonumber(size_str) or 0

      if size > compact.config.max_file_size then goto skip_file end
      if not compact.config.include_binary and is_binary(full) then goto skip_file end

      local content = read_file(full)
      if content == nil then goto skip_file end
      if not compact.config.include_empty and content:match("^%s*$") then goto skip_file end

      file_count = file_count + 1
      total_tokens = total_tokens + estimate_tokens(content)

      local ext = f.path:match("%.(.+)$") or ""
      out[#out + 1] = "### " .. f.path
      out[#out + 1] = ""
      out[#out + 1] = "```" .. ext
      out[#out + 1] = content
      out[#out + 1] = "```"
      out[#out + 1] = ""
      ::skip_file::
    end
  end

  if compact.config.tokens then
    out[#out + 1] = "---"
    out[#out + 1] = ""
    out[#out + 1] = "**Files:** " .. file_count .. " | **Tokens:** ~" .. total_tokens
    out[#out + 1] = ""
  end

  return table.concat(out, "\n")
end

--- Pack a directory into compact format
---@param root? string
---@param opts? table
---@return string
function compact.pack(root, opts)
  local is_vim = vim ~= nil
  root = root or (is_vim and vim.fn.getcwd()) or io.popen("pwd"):read("*l")
  if opts then
    for k, v in pairs(opts) do
      compact.config[k] = v
    end
  end

  local ignores = {}
  local files = compact.collect(root, ignores)

  local output
  if compact.config.format == "markdown" then
    output = pack_markdown(root, files)
  else
    output = pack_xml(root, files)
  end

  if compact.config.output then
    local f = io.open(compact.config.output, "w")
    if f then
      f:write(output)
      f:close()
    end
  end

  return output
end

--- Run as CLI command (parses arg table)
---@param args table
function compact.cli(args)
  local root = nil
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--output" or a == "-o" then
      i = i + 1
      compact.config.output = args[i]
    elseif a == "--format" or a == "-f" then
      i = i + 1
      compact.config.format = args[i]
    elseif a == "--no-tree" then
      compact.config.tree = false
    elseif a == "--no-tokens" then
      compact.config.tokens = false
    elseif a == "--help" or a == "-h" then
      print([[down compact - Pack a directory into AI-friendly format

Usage: down compact [options] [directory]

Options:
  -o, --output FILE   Write output to file (default: stdout)
  -f, --format FMT    Output format: xml (default), markdown
  --no-tree           Omit directory tree
  --no-tokens         Omit token count
  -h, --help          Show this help]])
      return true
    elseif a:sub(1, 1) ~= "-" then
      root = a
    end
    i = i + 1
  end

  local result = compact.pack(root)
  if not compact.config.output then
    print(result)
  else
    print("Wrote " .. compact.config.output)
  end
  return true
end

return compact
