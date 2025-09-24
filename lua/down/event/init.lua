local log = require("down.log")

---@class down.Event
local Event = {
  autocmd = require("down.event.autocmd"),
  id = "",
  ref = "",
  split = {},
  body = nil,
  broadcast = true,
  position = vim.api.nvim_win_get_cursor(0),
  file = vim.fn.expand("%:p"),
  dir = vim.fn.getcwd(),
  buf = vim.api.nvim_get_current_buf(),
  win = vim.api.nvim_get_current_win(),
  mode = vim.fn.mode(),
  line = vim.api.nvim_win_get_cursor(0)[1],
  char = vim.api.nvim_win_get_cursor(0)[2],
  ---@type down.Context
  context = {
    ---@type down.Position
    position = {
      line = vim.api.nvim_win_get_cursor(0)[1],
      char = vim.api.nvim_win_get_cursor(0)[2],
    },
    line = vim.api.nvim_get_current_line(),
    char = vim.api.nvim_win_get_cursor(0)[2],
    file = vim.fn.expand("%:p"),
    buf = vim.api.nvim_get_current_buf(),
    win = vim.api.nvim_get_current_win(),
    dir = vim.fn.getcwd(),
    scope = "global",
  },
}

--- Callback
--- @class down.Callback
---   @field cb table<string, { [1]: fun(event: down.Event, content: table|any), [2]?: fun(event: down.Event): boolean }>
local Callback = {
  ---@type table<string, { [1]: fun(event: down.Event, content: table|any), [2]?: fun(event: down.Event): boolean }>
  cb = {},

  ---@type table<string, down.Event>
  events = {},
}

--- @param ty? string
--- @return { [1]: fun(event: down.Event, content: table|any) }
function Event:get_cb(ty)
  return Callback.cb[ty or self.id]
end

--- Triggers a new callback to execute whenever an event of the requested type is executed.
--- @param self down.Event | string
--- @param cb fun(event: down.Event, content: table|any) The function to call whenever our event gets triggered.
--- @param filt? fun(event: down.Event): boolean # A filtering function to test if a certain event meets our expectations.
function Event.callback(self, cb, filt)
  local ty = (self and self.id) or self
  Callback.cb[ty] = Callback.cb[ty] or {}
  table.insert(Callback.cb[ty], { cb, filt })
end

--- @param cb? fun(event: down.Event, content: table|any)
function Event.set_callback(self, cb)
  Callback.cb[self.id] = Callback.cb[self.id] or {}
  table.insert(Callback.cb[self.id], cb)
end

--- Used internally by down to call all C with an event.
--- @param self down.Event
function Event.handle(self)
  log.trace("Event.handle: Handling ", self.id)
  local cbentry = Callback.cb[self.id]
  if cbentry then
    for _, cb in ipairs(cbentry) do
      if not cb[2] or cb[2](self) then
        cb[1](self, self.body)
      end
    end
  end
end

--- Load callback
--- @param m down.Mod.Mod
function Event.load_callback(m)
  for hk, ht in pairs(m.handle) do
    for ck, ct in pairs(ht) do
      if type(ct) == "function" then
        Event.callback(Event.define(m, ck), ct)
      end
    end
  end
end

--- Define a new event
---@param module down.Mod.Mod The module
---@param name string The name of the event
---@param body any? The body payload
---@return down.Event event The result event
Event.define = function(module, name, body)
  local mn = ""
  if type(module) == "table" then
    mn = module.id
  elseif type(module) == "string" then
    mn = module
  end
  local id = mn .. ".events." .. name
  return { ---@type down.Event
    id = id,
    ref = mn,
    split = Event.split_id(id) or {},
    body = body or module,
    broadcast = true,
    position = vim.api.nvim_win_get_cursor(0),
    file = vim.fn.expand("%:p"),
    dir = vim.fn.getcwd(),
    line = vim.api.nvim_get_current_line(),
    buf = vim.api.nvim_get_current_buf(),
    win = vim.api.nvim_get_current_win(),
    mode = vim.fn.mode(),
    context = nil,
  }
end

--- Split id
--- @param id string The full path of a init event
--- @return string[]? splitid id
function Event.split_id(id)
  local sa, sb = id:find("%.events%.")
  local sp_id = { id:sub(0, sa - 1), id:sub(sb + 1) }
  if #sp_id ~= 2 then
    log.warn("Invalid type name:" .. id)
    return
  end
  return sp_id
end

--- Returns an event template defined in `init.events`.
--- @param m down.Mod.Mod A reference to the init invoking the function
--- @param id string A full path to a valid event type (e.g. `init.events.some_event`)
--- @return down.Event?
function Event.get_event(m, id)
  local split = Event.split_id(id)
  if not split then
    log.warn(
      "Unable to get event template for event" .. id .. "and init" .. m.id
    )
    return
  end
  log.trace("Returning" .. split[2] .. "for init" .. split[1])
  return m.events[split[2]]
end

--- Returns a copy of the event template provided by a init.
--- @param m down.Mod.Mod A reference to the init invoking the function
--- @param id string A full path to a valid .vent type (e.g. `init.events.some_event`)
--- @param body table|any? The body of the event, can be anything from a string to a table to whatever you please.
--- @param ev? table The original event data.
--- @return down.Event? # New event.
function Event.new(m, id, body, ev)
  local event_template = Event.get_event(m or { id = m.id }, id)
  if not event_template then
    log.warn("Unable to create event of type" .. id .. ". Returning nil...")
    return
  end
  local mn = vim.deepcopy(event_template)
  mn.id = id
  mn.body = body
  mn.ref = m.id
  mn.split = assert(Event.split_id(id))
  mn.file = vim.fn.expand("%:t") --[[@as string]]
  mn.dir = vim.fn.expand("%:p:h") --[[@as string]]
  mn.buf = ev and ev.buf or vim.api.nvim_get_current_buf()
  mn.win = vim.api.nvim_get_current_win()
  mn.position = vim.api.nvim_win_get_cursor(mn.win)
  mn.mode = vim.api.nvim_get_mode()
  mn.line = vim.api.nvim_buf_get_lines(
    mn.buf,
    mn.position[1] - 1,
    mn.position[1],
    true
  )[1]
  mn.broadcast = true
  return mn
end

--- Sends an event to all subscribed mod. The event contains the filename, filehead, cursor position and line body as a bonus.
--- @param mods down.Mod.Mod[]
--- @param self down.Event
--- @return nil
function Event.broadcast_to(self, mods)
  if not self.split then
    log.error(
      "Unable to broadcast event of type" .. self.id .. "- invalid event name"
    )
    return
  end
  Event.handle(self)
  for mid, cm in pairs(mods or {}) do
    if cm.handle and cm.handle[self.split[1]] then
      local evt = cm.handle[self.split[1]][self.split[2]]
      if evt == nil or type(evt) == "nil" then
        goto broadcastcontinue
      elseif type(evt) == "function" then
        evt(self)
      end
    end
    ::broadcastcontinue::
  end
end

--- Send an event
--- @param recv down.Mod.Mod The name of a loaded init that will be the recipient of the event.
--- @return nil
--- @param self down.Event
function Event.send(self, recv)
  self.broadcast = false
  Event.handle(self)
  if recv.handle and recv.handle[self.split[1]] then
    local evt = recv.handle[self.split[1]][self.split[2]]
    if evt ~= nil and type(evt) == "function" then
      evt(self)
    end
  end
end

return Event
