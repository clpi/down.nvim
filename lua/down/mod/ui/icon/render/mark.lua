local pos = require("down.util.position")
local tbl = require("down.util.table")
local util = require("down.mod.ui.icon.util")
---@class down.mod.ui.icon.render.Mark
local Mark = {
  rerendering_scheduled_bufids = {},
  enabled = true,
  cursor_record = {},
}
function Mark.is_same_line_movement(event)
  -- some operations like dd / u cannot yet be listened reliably
  -- below is our best approximation
  local cursor_record = Mark.cursor_record
  return (
    cursor_record
    and cursor_record.row_0b == event.cursor_position[1] - 1
    and cursor_record.col_0b ~= event.cursor_position[2]
    and cursor_record.line_content == event.line_content
  )
end

Mark.schedule = function(bufid)
  local not_scheduled = vim.tbl_isempty(Mark.rerendering_scheduled_bufids)
  Mark.rerendering_scheduled_bufids[bufid] = true
  if not_scheduled then
    vim.schedule(Mark.all.render)
  end
end

Mark.enabled = true

Mark.query = function(q)
  return vim.treesitter.query.parse("markdown", q)
end

Mark.handlers = {
  ["cmd.events.icon.toggle"] = Mark.on.toggle.pretty,
}
Mark.on = {
  ft = function(event)
    Mark.on.event(event)
  end,
  scrolled = function(event)
    Mark.schedule(event.buffer)
  end,

  cursor = {
    update = function(event)
      local cursor_record = tbl.orempty(Mark.cursor_record, event.buffer)
      cursor_record.row_0b = event.cursor_position[1] - 1
      cursor_record.col_0b = event.cursor_position[2]
      cursor_record.line_content = event.line_content
    end,
    moved = function(event)
      if not Mark.is_same_line_movement(event) then
        local cursor_record = Mark.cursor_record[event.buffer]
        if cursor_record then
          Mark.ln.mark.changed(event.buffer, cursor_record.row_0b)
        end
        local current_row_0b = event.cursor_position[1] - 1
        Mark.ln.mark.changed(event.buffer, current_row_0b)
      end
      Mark.on.cursor.update(event)
    end,

    moved_i = function(event)
      return Mark.on.cursor.moved(event)
    end,
  },
  event = function(event)
    assert(vim.api.nvim_win_is_valid(event.window))
    Mark.on.cursor.update(event)

    local function on_line_callback(
        tag,
        bufid,
        _changedtick, ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        row_start_0b,
        _row_end_0bex, ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
        row_updated_0bex,
        _n_byte_prev ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
    )
      assert(tag == "lines")

      if not Mark.enabled then
        return
      end

      Mark.ln.mark.changed(bufid, row_start_0b, row_updated_0bex)
    end

    local attach_succeeded = vim.api.nvim_buf_attach(
      event.buffer,
      true,
      { on_lines = on_line_callback }
    )
    assert(attach_succeeded)
    local language_tree = vim.treesitter.get_parser(event.buffer, "markdown")

    local bufid = event.buffer
    -- used for detecting non-local (multiline) changes, like spoiler / code block
    -- TODO: exemption in certain cases, for example when changing only heading followed by pure texts,
    -- in which case all its descendents would be unnecessarily re-concealed.
    local function on_changedtree_callback(ranges)
      -- TODO: abandon if too large
      for i = 1, #ranges do
        local range = ranges[i]
        local row_start_0b = range[1]
        local row_end_0bex = range[3] + 1
        Mark.range.pretty.rm(bufid, row_start_0b, row_end_0bex)
      end
    end

    language_tree:register_cbs({ on_changedtree = on_changedtree_callback })
    Mark.all.mark.changed(event.buffer)

    if
        Mark.config.folds
        and vim.api.nvim_win_is_valid(event.window)
        and vim.api.nvim_buf_is_valid(event.buffer)
    then
      vim.api.nvim_buf_call(event.buffer, function()
        -- NOTE(vhyrro): `vim.wo` only supports `wo[winid][0]`,
        -- hence the `buf_call` here.
        local wo = vim.wo[event.window][0]
        wo.foldmethod = "expr"
        wo.foldexpr = vim.treesitter.foldexpr
            and "v:lua.vim.treesitter.foldexpr()"
            or "nvim_treesitter#foldexpr()"
        wo.foldtext = ""

        local mod_open_folds = Mark.config.mod_open_folds
        local function open_folds()
          vim.cmd("normal! zR")
        end

        if mod_open_folds == "always" then
          open_folds()
        elseif mod_open_folds == "never" then -- luacheck:ignore 542
          -- do nothing
        else
          if mod_open_folds ~= "auto" then
            require("down.util.log").warn(
              '"mod_open_folds" must be "auto", "always", or "never"'
            )
          end

          if wo.foldlevel == 0 then
            open_folds()
          end
        end
      end)
    end
  end,

  insert = {

    toggle = function(event)
      Mark.ln.mark.changed(event.buffer, event.cursor_position[1] - 1)
    end,

    enter = function(event)
      Mark.on.insert.toggle(event)
    end,

    leave = function(event)
      Mark.on.insert.toggle(event)
    end,
  },
  toggle = {
    pretty = function(event)
      -- FIXME: Mark.enabled should be a map from bufid to boolean
      Mark.enabled = not Mark.enabled
      if Mark.enabled then
        Mark.all.mark.changed(event.buffer)
      else
        Mark.rerendering_scheduled_bufids[event.buffer] = nil
        Mark.all.mark.clear(event.buffer)
      end
    end,
  },
}

--- @param query TSQuery|any
--- @param document_root Node|any
--- @param bufid number
--- @param row_start_0b number
--- @param row_end_0bex number
Mark.query_get_nodes = function(
    query,
    document_root,
    bufid,
    row_start_0b,
    row_end_0bex
)
  local result = {}
  local concealed_node_ids = {}
  for id, node in
  query:iter_captures(document_root, bufid, row_start_0b, row_end_0bex)
  do
    if node:missing() then
      goto continue
    end
    if query.captures[id] == "icon-concealed" then
      concealed_node_ids[node:id()] = true
    end
    table.insert(result, node)
    ::continue::
  end
  return result, concealed_node_ids
end

function Mark.inside_example(_)
  -- TODO: waiting for parser fix
  return false
end

Mark.skip_prettify = function(
    current_mode,
    current_row_0b,
    node,
    config,
    row_start_0b,
    row_end_0bex
)
  local result
  if config.insert_enabled then
    result = false
  elseif
      (current_mode == "i")
      and u.in_range(current_row_0b, row_start_0b, row_end_0bex)
  then
    result = true
  elseif Mark.inside_example(node) then
    result = true
  else
    result = false
  end
  return result
end
Mark.opts = function(row_0b, col_0b, text, highlight)
  return {
    virt_text = { { text, highlight } },
    virt_text_pos = "overlay",
    virt_text_win_col = nil,
    hl_group = nil,
    conceal = nil,
    id = nil,
    end_row = row_0b,
    end_col = col_0b,
    hl_eol = nil,
    virt_text_hide = nil,
    hl_mode = "combine",
    virt_lines = nil,
    virt_lines_above = nil,
    virt_lines_leftcol = nil,
    ephemeral = nil,
    right_gravity = nil,
    end_right_gravity = nil,
    priority = nil,
    strict = nil, -- default true
    sign_text = nil,
    sign_hl_group = nil,
    number_hl_group = nil,
    line_hl_group = nil,
    cursorline_hl_group = nil,
    spell = nil,
    ui_watched = nil,
    invalidate = true,
  }
end

Mark.clear = function(bufid)
  vim.api.nvim_buf_clear_namespace(bufid or 0, Mark.ns.icon.ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufid or 0, Mark.ns.pretty.ns, 0, -1)
end

Mark.set = function(bufid, row_0b, col_0b, text, highlight, ext_opts)
  local opt = Mark.opts(row_0b, col_0b, text, highlight)

  if ext_opts then
    tbl.extendinplace(opt, ext_opts)
  end

  vim.api.nvim_buf_set_extmark(bufid, Mark.ns.icon.ns, row_0b, col_0b, opt)
end
Mark.remove = function(bufid, pos_start_0b_0b, pos_end_0bin_0bex)
  if pos.eq(pos_start_0b_0b, pos_end_0bin_0bex) then
    return
  end

  local ns_icon = Mark.ns.icon.ns
  for _, result in
  ipairs(
    vim.api.nvim_buf_get_extmarks(
      bufid,
      ns_icon,
      { pos_start_0b_0b.x, pos_start_0b_0b.y },
      {
        pos_end_0bin_0bex.x - ((pos_end_0bin_0bex.y == 0) and 1 or 0),
        pos_end_0bin_0bex.y - 1,
      },
      {}
    )
  )
  do
    local extmark_id = result[1]
    -- TODO: Optimize
    -- local node_pos_0b_0b = { x = result[2], y = result[3] }
    -- assert(
    --     pos_le(pos_start_0b_0b, node_pos_0b_0b) and pos_le(node_pos_0b_0b, pos_end_0bin_0bex),
    --     ("start=%s, end=%s, node=%s"):format(
    --         vim.inspect(pos_start_0b_0b),
    --         vim.inspect(pos_end_0bin_0bex),
    --         vim.inspect(node_pos_0b_0b)
    --     )
    -- )
    vim.api.nvim_buf_del_extmark(bufid, Mark.ns.icon.ns, extmark_id)
  end
end

Mark.ns = {
  icon = {
    name = "down.mod.ui.icon.icon",
    ns = vim.api.nvim_create_namespace("down.mod.ui.icon.icon"),
  },
  pretty = {
    name = "down.mod.ui.icon.pretty",
    ns = vim.api.nvim_create_namespace("down.mod.ui.icon.pretty"),
  },
}
Mark.enabled = true

Mark.ln = {

  visible = function(winid)
    local row_start_1b = vim.fn.line("w0", winid)
    local row_end_1b = vim.fn.line("w$", winid)
    return (row_start_1b - 1), row_end_1b
  end,
  mark = {
    changed = function(bufid, row_0b)
      Mark.ln.pretty.rm(bufid, row_0b)
      Mark.schedule(bufid)
    end,
  },
  enabled = true,
  schedule = function(bufid)
    vim.schedule(function()
      vim.api.nvim_buf_clear_namespace(bufid, Mark.ns.pretty.ns, 0, -1)
    end)
  end,
  pretty = {
    rm = function(bufid, row_0b)
      -- TODO: optimize
      local ns_prettify_flag = Mark.ns.pretty.ns
      vim.api.nvim_buf_clear_namespace(
        bufid,
        ns_prettify_flag,
        row_0b,
        row_0b + 1
      )
    end,
    --- Add a prettify flag to a row
    --- @param bufid number
    --- @param row number
    add = function(bufid, row)
      vim.api.nvim_buf_set_extmark(bufid, Mark.ns.pretty.ns, row, 0, {})
    end,
  },
}

function Mark.get_parsed_query_lazy(p)
  if p then
    return p
  end

  local keys = { "config", "icons" }
  local function traverse_config(config, f)
    if config == false then
      return
    end
    if config.nodes then
      f(config)
      return
    end
    if type(config) ~= "table" then
      require("down.util.log").warn(
        ("unsupported icon config: %s = %s"):format(
          table.concat(keys, "."),
          config
        )
      )
      return
    end
    local key_pos = #keys + 1
    for key, sub_config in pairs(config) do
      keys[key_pos] = key
      traverse_config(sub_config, f)
      keys[key_pos] = nil
    end
  end

  local config_by_node_name = {}
  local queries = { "[" }

  traverse_config(Mark.config.icons, function(config)
    for _, node_type in ipairs(config.nodes) do
      table.insert(queries, ("(%s)@icon"):format(node_type))
      config_by_node_name[node_type] = config
    end
    for _, node_type in ipairs(config.nodes.concealed or {}) do
      table.insert(queries, ("(%s)@icon-concealed"):format(node_type))
      config_by_node_name[node_type] = config
    end
  end)

  table.insert(queries, "]")
  local query_combined = table.concat(queries, " ")
  Mark.prettify_query =
      require("nvim-treesitter.util").ts_parse_query("markdown", query_combined)
  assert(Mark.prettify_query)
  Mark.config_by_node_name = config_by_node_name
  return Mark.prettify_query
end

Mark.range = {
  changed = function(bufid, row_start_0b, row_end_0bex)
    Mark.range.pretty.rm(bufid, row_start_0b, row_end_0bex)
    Mark.schedule(bufid)
  end,
  pretty = {
    rm = function(bufid, row_start_0b, row_end_0bex)
      -- TODO: optimize
      local ns_prettify_flag = Mark.ns.pretty.ns
      vim.api.nvim_buf_clear_namespace(
        bufid,
        ns_prettify_flag,
        row_start_0b,
        row_end_0bex
      )
    end,
    add = function(bufid, row_start_0b, row_end_0bex)
      for row = row_start_0b, row_end_0bex - 1 do
        Mark.ln.pretty.add(bufid, row)
      end
    end,
    render = function(bufid, row_start_0b, row_end_0bex, p)
      -- in case there's undo/removal garbage
      -- TODO: optimize
      row_end_0bex =
          math.min(row_end_0bex + 1, vim.api.nvim_buf_line_count(bufid))

      local tsm = require("down.mod.integration.treesitter")
      local document_root = tsm.get_document_root(bufid)
      assert(document_root)

      local nodes, concealed_node_ids = Mark.query_get_nodes(
        Mark.get_parsed_query_lazy(p),
        document_root,
        bufid,
        row_start_0b,
        row_end_0bex
      )

      local winid = vim.fn.bufwinid(bufid)
      assert(winid > 0)
      local current_row_0b = vim.api.nvim_win_get_cursor(winid)[1] - 1
      local current_mode = vim.api.nvim_get_mode().mode
      local conceallevel = vim.wo[winid].conceallevel
      local concealcursor = vim.wo[winid].concealcursor

      assert(document_root)

      for _, node in ipairs(nodes) do
        local node_row_start_0b, node_col_start_0b, node_row_end_0bin, node_col_end_0bex =
            node:range()
        local node_row_end_0bex = node_row_end_0bin + 1
        local config = Mark.config_by_node_name[node:type()]

        if config.clear then
          config:clear(bufid, node)
        else
          local pos_start_0b_0b, pos_end_0bin_0bex =
              { x = node_row_start_0b, y = node_col_start_0b },
              { x = node_row_end_0bin, y = node_col_end_0bex }

          pos.check.min(pos_start_0b_0b, node:start())
          pos.check.max(pos_end_0bin_0bex, node:end_())

          Mark.remove(bufid, pos_start_0b_0b, pos_end_0bin_0bex)
        end

        Mark.range.pretty.rm(node_row_start_0b, node_row_end_0bex)
        Mark.range.pretty.add(bufid, node_row_start_0b, node_row_end_0bex)

        if
            Mark.skip_prettify(
              current_mode,
              current_row_0b,
              node,
              config,
              node_row_start_0b,
              node_row_end_0bex
            )
        then
          goto continue
        end

        local has_conceal = (
          concealed_node_ids[node:id()]
          and (not config.check_conceal or config.check_conceal(node))
          and util.is_concealing_on_row_range(
            current_mode,
            conceallevel,
            concealcursor,
            current_row_0b,
            node_row_start_0b,
            node_row_end_0bex
          )
        )

        if has_conceal then
          if config.render_concealed then
            config:render_concealed(bufid, node)
          end
        else
          config:render(bufid, node)
        end

        ::continue::
      end
    end,
  },
}

--- @param bufid? integer
Mark.render_buf = function(bufid, p)
  bufid = bufid or vim.api.nvim_get_current_buf()
  local ns_prettify_flag = Mark.ns.pretty.ns
  local winid = vim.fn.bufwinid(bufid)
  local row_start_0b, row_end_0bex = Mark.ln.visible(winid)
  local prettify_flags_0b = vim.api.nvim_buf_get_extmarks(
    bufid,
    ns_prettify_flag,
    { row_start_0b, 0 },
    { row_end_0bex - 1, -1 },
    {}
  )
  local row_nomark_start_0b, row_nomark_end_0bin
  local i_flag = 1
  for i = row_start_0b, row_end_0bex - 1 do
    while i_flag <= #prettify_flags_0b and i > prettify_flags_0b[i_flag][2] do
      i_flag = i_flag + 1
    end

    if i_flag <= #prettify_flags_0b and i == prettify_flags_0b[i_flag][2] then
      i_flag = i_flag + 1
    else
      assert(
        i
        < (
          prettify_flags_0b[i_flag] and prettify_flags_0b[i_flag][2]
          or row_end_0bex
        )
      )
      row_nomark_start_0b = row_nomark_start_0b or i
      row_nomark_end_0bin = i
    end
  end

  assert((row_nomark_start_0b == nil) == (row_nomark_end_0bin == nil))
  if row_nomark_start_0b then
    Mark.range.pretty.render(
      bufid,
      row_nomark_start_0b,
      row_nomark_end_0bin + 1,
      p
    )
  end
end
Mark.all = {
  render = function()
    for bufid, _ in pairs(Mark.rerendering_scheduled_bufids) do
      if vim.fn.bufwinid(bufid) >= 0 then
        Mark.render_buf(bufid, Mark.prettify_query)
      end
    end
    Mark.rerendering_scheduled_bufids = {}
  end,
  mark = {
    clear = function(bufid)
      local ns_icon = Mark.ns.icon.ns
      local ns_prettify_flag = Mark.ns.pretty.ns
      vim.api.nvim_buf_clear_namespace(bufid, ns_icon, 0, -1)
      vim.api.nvim_buf_clear_namespace(bufid, ns_prettify_flag, 0, -1)
    end,
    changed = function(bufid)
      if not Mark.enabled then
        return
      end

      Mark.all.pretty.rm(bufid)
      Mark.schedule(bufid)
    end,
  },
  pretty = {
    rm = function(bufid)
      Mark.range.pretty.rm(bufid, 0, -1)
    end,
  },
}

return Mark
