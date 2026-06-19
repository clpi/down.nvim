--- ai.chat - Conversational AI chat interface
--- Provides a chat buffer with context from the knowledge graph,
--- current file, and conversation history.

local Ai = require ("down.mod.ai")
local mod = require ("down.mod")
local log = require ("down.log")

---@class down.mod.ai.chat.Chat: down.Mod
local Chat = mod.new ("ai.chat")
Chat.dep = { "ai", "cmd", "workspace" }

Chat.config = {
  --- Max messages to keep in history
  max_history = 50,
  --- Whether to stream responses
  stream = false,
  --- System prompt for chat
  system_prompt = "You are a helpful coding assistant integrated into a note-taking environment called down.nvim. "
    .. "You have access to the user's knowledge graph and can reference their notes. "
    .. "Be concise and helpful. Answer questions about the user's notes, code, and knowledge base.",
  --- Window layout: "split", "vsplit", "tab", "float"
  layout = "vsplit",
}

---@class down.mod.ai.chat.Session
---@field id string
---@field title string
---@field messages table[]
---@field created number
---@field buffer number|nil

Chat.sessions = {}
Chat.active = nil

Chat.setup = function ()
  return { loaded = true }
end

--- Create a new chat session
---@param title? string
---@return down.mod.ai.chat.Session
function Chat.new_session (title)
  local session = {
    id = tostring (os.time ()) .. "_" .. math.random (1000, 9999),
    title = title or ("Chat " .. os.date ("%H:%M")),
    messages = {
      { role = "system", content = Ai.config.system_prompt or Chat.config.system_prompt },
    },
    created = os.time (),
    buffer = nil,
  }
  Chat.sessions[session.id] = session
  Chat.active = session.id
  return session
end

--- Get the active session or create one
---@return down.mod.ai.chat.Session
function Chat.get_session ()
  if Chat.active and Chat.sessions[Chat.active] then
    return Chat.sessions[Chat.active]
  end
  return Chat.new_session ()
end

--- Add context from the knowledge graph
---@param session down.mod.ai.chat.Session
local function add_knowledge_context (session)
  local ctx = Ai.knowledge_context ()
  if ctx ~= "" then
    table.insert (session.messages, 2, { role = "system", content = "[Knowledge Graph Context]\n" .. ctx })
  end
end

--- Add context from the current buffer
---@param session down.mod.ai.chat.Session
local function add_buffer_context (session)
  local buf = vim.api.nvim_get_current_buf ()
  local lines = vim.api.nvim_buf_get_lines (buf, 0, math.min (500, vim.api.nvim_buf_line_count (buf)), false)
  local content = table.concat (lines, "\n")
  if #content > 0 then
    local file = vim.api.nvim_buf_get_name (buf)
    table.insert (session.messages, 2, {
      role = "system",
      content = "[Current File: " .. file .. "]\n```\n" .. content:sub (1, 4000) .. "\n```",
    })
  end
end

--- Send a message in the active chat session
---@param content string
---@param opts? { no_context?: boolean }
---@return string|nil
function Chat.send (content, opts)
  opts = opts or {}
  local session = Chat.get_session ()

  if not opts.no_context then
    add_knowledge_context (session)
    add_buffer_context (session)
  end

  table.insert (session.messages, { role = "user", content = content })

  -- Trim history
  if #session.messages > Chat.config.max_history + 2 then
    local keep = session.messages[1] -- system prompt
    local rest = {}
    for i = #session.messages - Chat.config.max_history, #session.messages do
      rest[#rest + 1] = session.messages[i]
    end
    session.messages = { keep, table.unpack (rest) }
  end

  local response, err = Ai.complete (session.messages)
  if response then
    table.insert (session.messages, { role = "assistant", content = response })
    return response
  else
    log.error ("Chat.send failed: " .. (err or "unknown"))
    return nil
  end
end

--- Open or focus the chat buffer
---@param session? down.mod.ai.chat.Session
function Chat.open (session)
  session = session or Chat.get_session ()

  if session.buffer and vim.api.nvim_buf_is_valid (session.buffer) then
    local wins = vim.api.nvim_list_wins ()
    for _, win in ipairs (wins) do
      if vim.api.nvim_win_get_buf (win) == session.buffer then
        vim.api.nvim_set_current_win (win)
        return
      end
    end
    vim.cmd (Chat.config.layout == "vsplit" and "vsplit" or "split")
    vim.api.nvim_win_set_buf (0, session.buffer)
    return
  end

  local buf = vim.api.nvim_create_buf (false, true)
  vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option (buf, "filetype", "markdown")

  local lines = { "# " .. session.title, "" }
  for _, msg in ipairs (session.messages) do
    if msg.role == "user" then
      lines[#lines + 1] = "**You:** " .. msg.content
    elseif msg.role == "assistant" then
      lines[#lines + 1] = ""
      for _, l in ipairs (vim.split (msg.content, "\n")) do
        lines[#lines + 1] = l
      end
      lines[#lines + 1] = ""
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "---"
  lines[#lines + 1] = "*Type your message and press <Enter> to send. :q to close.*"

  vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option (buf, "modified", false)
  session.buffer = buf

  vim.cmd (Chat.config.layout == "vsplit" and "vsplit" or "split")
  vim.api.nvim_win_set_buf (0, buf)

  -- Set up Enter to send
  local send_fn = function ()
    local last_line = vim.api.nvim_buf_line_count (buf)
    local text = table.concat (
      vim.api.nvim_buf_get_lines (buf, last_line - 1, last_line, false),
      "\n"
    )
    text = text:match ("^%s*(.-)%s*$") or ""
    if text == "" or text:match ("^%-%-%-") then return end
    if text:match ("^%*.*%*$") then return end -- placeholder line

    -- Append user message
    vim.api.nvim_buf_set_lines (buf, last_line - 1, last_line, false, { "**You:** " .. text, "" })
    vim.api.nvim_buf_set_lines (buf, last_line, last_line, false, { "..." })

    local response = Chat.send (text)
    if response then
      local new_last = vim.api.nvim_buf_line_count (buf)
      vim.api.nvim_buf_set_lines (buf, new_last - 1, new_last, false, {})
      for _, l in ipairs (vim.split (response, "\n")) do
        vim.api.nvim_buf_set_lines (buf, -1, -1, false, { l })
      end
      vim.api.nvim_buf_set_lines (buf, -1, -1, false, { "", "---" })
    else
      local new_last = vim.api.nvim_buf_line_count (buf)
      vim.api.nvim_buf_set_lines (buf, new_last - 1, new_last, false, { "_Error: " .. (response or "failed") .. "_", "", "---" })
    end
    vim.api.nvim_buf_set_option (buf, "modified", false)
  end

  vim.keymap.set ("n", "<CR>", send_fn, { buffer = buf, desc = "Send chat message" })
  vim.keymap.set ("i", "<CR>", "<Esc>" .. send_fn, { buffer = buf, desc = "Send chat message" })
end

--- List all sessions
---@return down.mod.ai.chat.Session[]
function Chat.list_sessions ()
  local sessions = {}
  for _, s in pairs (Chat.sessions) do
    sessions[#sessions + 1] = s
  end
  table.sort (sessions, function (a, b) return a.created > b.created end)
  return sessions
end

--- Delete a session
---@param id string
function Chat.delete_session (id)
  local s = Chat.sessions[id]
  if s and s.buffer and vim.api.nvim_buf_is_valid (s.buffer) then
    vim.api.nvim_buf_delete (s.buffer, { force = true })
  end
  Chat.sessions[id] = nil
  if Chat.active == id then Chat.active = nil end
end

--- Reset the active session
function Chat.reset ()
  if Chat.active then
    Chat.delete_session (Chat.active)
  end
  Chat.new_session ()
end

Chat.commands = {
  chat = {
    enabled = true,
    args = 0,
    name = "chat",
    callback = function (_)
      Chat.open ()
    end,
    commands = {
      new = {
        enabled = true,
        args = 0,
        name = "chat.new",
        callback = function ()
          Chat.new_session ()
          Chat.open ()
        end,
      },
      reset = {
        enabled = true,
        args = 0,
        name = "chat.reset",
        callback = function ()
          Chat.reset ()
          Chat.open ()
        end,
      },
      list = {
        enabled = true,
        args = 0,
        name = "chat.list",
        callback = function ()
          local sessions = Chat.list_sessions ()
          local items = {}
          for _, s in ipairs (sessions) do
            items[#items + 1] = s.title .. " (" .. os.date ("%Y-%m-%d %H:%M", s.created) .. ")"
          end
          if #items == 0 then
            vim.notify ("No chat sessions", vim.log.levels.INFO)
          else
            vim.ui.select (items, { prompt = "Chat sessions:" }, function (choice)
              if choice then
                for _, s in ipairs (sessions) do
                  if choice:find (s.title, 1, true) then
                    Chat.active = s.id
                    Chat.open (s)
                    return
                  end
                end
              end
            end)
          end
        end,
      },
      delete = {
        enabled = true,
        args = 0,
        name = "chat.delete",
        callback = function ()
          local sessions = Chat.list_sessions ()
          local items = {}
          for _, s in ipairs (sessions) do
            items[#items + 1] = s.title
          end
          vim.ui.select (items, { prompt = "Delete chat session:" }, function (choice)
            if choice then
              for _, s in ipairs (sessions) do
                if s.title == choice then
                  Chat.delete_session (s.id)
                  vim.notify ("Deleted: " .. s.title, vim.log.levels.INFO)
                  return
                end
              end
            end
          end)
        end,
      },
    },
  },
}

return Chat
