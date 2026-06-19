local log = require ("down.log")
local mod = require ("down.mod")

---@class down.mod.data.knowledge.Knowledge: down.Mod
local Knowledge = mod.new ("data.knowledge")
Knowledge.dep = { "data", "workspace" }

---@class down.mod.data.knowledge.Entity
---@field id string
---@field name string
---@field kind string
---@field file string
---@field line number
---@field relations string[]

---@class down.mod.data.knowledge.Graph
---@field entities table<string, down.mod.data.knowledge.Entity>
---@field relations table<string, string[]>

---@class down.mod.data.knowledge.Config
Knowledge.config = {
  --- Enable knowledge graph indexing
  enabled = true,
  --- Auto-index on workspace change
  auto_index = true,
  --- Entity kinds to extract
  kinds = {
    "person",
    "concept",
    "project",
    "place",
    "action",
    "tag",
  },
  --- Patterns to extract entities from wiki-links
  wiki_link_pattern = "%[%[(.-)%]%]",
  --- Patterns to extract entities from tags
  tag_pattern = "#([%w_%-]+)",
}

---@return down.mod.Setup
Knowledge.setup = function ()
  Knowledge.restore ()
  if Knowledge.config.auto_index then
    vim.api.nvim_create_autocmd ("BufWritePost", {
      pattern = "*.md",
      callback = function (ev)
        Knowledge.index_file (ev.file)
      end,
      desc = "Index file into knowledge graph on save",
    })
  end
  return {
    loaded = true,
  }
end

---@type down.mod.data.knowledge.Graph
Knowledge.graph = {
  entities = {},
  relations = {},
}

--- Add an entity to the graph
---@param entity down.mod.data.knowledge.Entity
Knowledge.add_entity = function (entity)
  Knowledge.graph.entities[entity.id] = entity
end

--- Add a relation between two entities
---@param from string
---@param to string
Knowledge.add_relation = function (from, to)
  if not Knowledge.graph.relations[from] then
    Knowledge.graph.relations[from] = {}
  end
  table.insert (Knowledge.graph.relations[from], to)
end

--- Extract entities from a buffer
---@param buf? number
---@return down.mod.data.knowledge.Entity[]
Knowledge.extract_entities = function (buf)
  buf = buf or vim.api.nvim_get_current_buf ()
  local entities = {}
  local lines = vim.api.nvim_buf_get_lines (buf, 0, -1, false)
  local file = vim.api.nvim_buf_get_name (buf)

  for lnum, line in ipairs (lines) do
    -- Extract wiki-links [[entity]]
    for name in line:gmatch (Knowledge.config.wiki_link_pattern) do
      local entity = {
        id = name:lower ():gsub ("%s+", "-"),
        name = name,
        kind = "concept",
        file = file,
        line = lnum,
        relations = {},
      }
      table.insert (entities, entity)
    end

    -- Extract tags #tag
    for tag in line:gmatch (Knowledge.config.tag_pattern) do
      local entity = {
        id = "tag:" .. tag:lower (),
        name = tag,
        kind = "tag",
        file = file,
        line = lnum,
        relations = {},
      }
      table.insert (entities, entity)
    end
  end

  return entities
end

--- Index a single file into the knowledge graph
---@param path string
Knowledge.index_file = function (path)
  local ok, lines = pcall (vim.fn.readfile, path)
  if not ok then
    return
  end
  local file_id = path:gsub ("[/\\]", "."):gsub ("%.md$", "")

  for lnum, line in ipairs (lines) do
    for name in line:gmatch (Knowledge.config.wiki_link_pattern) do
      local entity = {
        id = name:lower ():gsub ("%s+", "-"),
        name = name,
        kind = "concept",
        file = path,
        line = lnum,
        relations = {},
      }
      Knowledge.add_entity (entity)
      Knowledge.add_relation (file_id, entity.id)
    end

    for tag in line:gmatch (Knowledge.config.tag_pattern) do
      local entity = {
        id = "tag:" .. tag:lower (),
        name = tag,
        kind = "tag",
        file = path,
        line = lnum,
        relations = {},
      }
      Knowledge.add_entity (entity)
      Knowledge.add_relation (file_id, entity.id)
    end
  end
end

--- Index the entire workspace
Knowledge.index_workspace = function ()
  local ws = mod.get_mod ("workspace")
  if not ws then
    return
  end
  local files = ws.files (nil, "**/*.md")
  if not files then
    return
  end
  Knowledge.graph = { entities = {}, relations = {} }
  for _, file in ipairs (files) do
    Knowledge.index_file (file)
  end
  Knowledge.save ()
  log.info (
    "Knowledge graph indexed: "
      .. vim.tbl_count (Knowledge.graph.entities)
      .. " entities"
  )
end

--- Save the knowledge graph to disk
Knowledge.save = function ()
  local data_mod = mod.get_mod ("data")
  if data_mod then
    data_mod.set ("knowledge.graph", Knowledge.graph)
    data_mod.flush ()
  end
end

--- Load the knowledge graph from disk
Knowledge.restore = function ()
  local data_mod = mod.get_mod ("data")
  if data_mod then
    local saved = data_mod.get ("knowledge.graph")
    if saved and type (saved) == "table" and saved.entities then
      Knowledge.graph = saved
    end
  end
end

--- Query the knowledge graph for entities matching a pattern
---@param query string
---@return down.mod.data.knowledge.Entity[]
Knowledge.query = function (query)
  local results = {}
  local pattern = query:lower ()
  for _, entity in pairs (Knowledge.graph.entities) do
    if
      entity.name:lower ():find (pattern, 1, true)
      or entity.id:find (pattern, 1, true)
    then
      table.insert (results, entity)
    end
  end
  return results
end

--- Get relations for an entity
---@param entity_id string
---@return string[]
Knowledge.get_relations = function (entity_id)
  return Knowledge.graph.relations[entity_id] or {}
end

Knowledge.commands = {
  knowledge = {
    name = "knowledge",
    args = 0,
    max_args = 1,
    callback = function ()
      Knowledge.index_workspace ()
    end,
    commands = {
      index = {
        name = "knowledge.index",
        args = 0,
        callback = function ()
          Knowledge.index_workspace ()
        end,
      },
      query = {
        name = "knowledge.query",
        args = 1,
        callback = function (e)
          local query = e.body and e.body[1] or ""
          local results = Knowledge.query (query)
          if #results == 0 then
            vim.notify ("[down.nvim] No entities found for: " .. query)
          else
            local items = {}
            for _, entity in ipairs (results) do
              table.insert (
                items,
                string.format (
                  "[%s] %s (%s:%d)",
                  entity.kind,
                  entity.name,
                  entity.file,
                  entity.line
                )
              )
            end
            vim.ui.select (
              items,
              { prompt = "Knowledge Graph Results" },
              function (choice)
                if choice then
                  local idx = vim.fn.index (items, choice) + 1
                  local entity = results[idx]
                  if entity then
                    vim.cmd ("edit " .. entity.file)
                    vim.api.nvim_win_set_cursor (0, { entity.line, 0 })
                  end
                end
              end
            )
          end
        end,
      },
      stats = {
        name = "knowledge.stats",
        args = 0,
        callback = function ()
          local entities = Knowledge.graph.entities or {}
          local relations = Knowledge.graph.relations or {}
          local entity_count = vim.tbl_count (entities)
          local relation_count = 0
          for _, rels in pairs (relations) do
            relation_count = relation_count + #rels
          end
          vim.notify (
            string.format (
              "[down.nvim] Knowledge Graph: %d entities, %d relations",
              entity_count,
              relation_count
            )
          )
        end,
      },
    },
  },
}

return Knowledge
