---@meta down.ids.event
---
--- @class (exact) down.Event
---   @field id string The type of the event. Exists in the format of `category.id`.
---   @field split string[] The event type, just split on every `.` character, e.g. `{ "category", "name" }`.
---   @field body? table|any The content of the event. The data found here is specific to each individual event. Can be thought of as the payload.
---   @field ref string The name of the init that triggered the event.
---   @field broadcast boolean Whether the event was broadcast to all mod. `true` is so, `false` if the event was specifically sent to a single recipient.
---   @field position { [1]: number, [2]: number } The position of the cursor at the moment of broadcasting the event.
---   @field file string The name of the file that the user was in at the moment of broadcasting the event.
---   @field dir string The name of the file that the user was in at the moment of broadcasting the event.
---   @field line string The content of the line the user was editing at the moment of broadcasting the event.
---   @field buf number The buffer ID of the buffer the user was in at the moment of broadcasting the event.
---   @field win number The window ID of the window the user was in at the moment of broadcasting the event.
---   @field mode string The mode Neovim was in at the moment of broadcasting the event.
---   @field broadcast fun(self: down.Event)
---   @field new fun(m: down.Mod.Mod, type: string, body: table|string, ev?: table): down.Event?
---   @field send fun(self: down.Event, recipient: down.Mod.Mod[])
---   @field handle fun(self: down.Event)
---   @field broadcast_to fun(self: down.Event, mods: down.Mod.Mod[])
---   @field define fun(module: down.Mod.Mod|string, type: string): down.Event
---   @field context? down.Context
---
---
--- @class (exact) down.mod.Events: {
---   [string]: down.Event
--- }
---
--- @class (exact) down.mod.Subscribed: {
---   [string]: {
---     [string]: boolean
---   }
--- }
