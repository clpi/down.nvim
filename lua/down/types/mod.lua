---@meta down.ids.mod
---
--- @alias down.mod.Handler fun(event: down.Event)
---
--- @alias down.Opts { [string]?: string } | function
---
--- @alias down.VimMode
--- | 'n'
--- | 'i'
--- | 'v'
--- | 'x'
--- | 'c'
---
--- @class down.Map: {
---   [1]: down.VimMode | down.VimMode[],
---   [2]: string,
---   [3]: string | fun(),
---   [4]?: string,
---   [5]?: down.MapOpts,
---
--- @class down.MapOpts: {
---   mode?: down.VimMode | down.VimMode[],
---   key?: string,
---   callback?: string | fun(),
---   desc?: string,
---   noremap?: boolean,
---   nowait?: boolean
--- }
---
--- @alias down.Maps down.Map[]|fun()
--- @alias down.Handler fun(event: down.Event, ...: any)
--- @alias down.Handlers {
---   [string]?: down.Handler|down.Handlers,
---   __call?: down.Handler,
--- }
--- @class down.Mod
---   @field public config? down.mod.Config The config for the mod.
---   @field public import? table<string, down.Mod> Imported submod of the given mod. Contrary to `dep`, which only exposes the public API of a mod, imported mod can be accessed in their entirety.
---   @field public commands?  down.Command[] that adds all the commands for the mod.
---   @field public maps? down.Maps
---   @field public opts? down.Opts Function that adds all the options for the mod.
---   @field public load? fun() Function that is invoked once the mod is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
---   @field public bench? fun() Function that is invoked when the mod is being benchmarked.
---   @field public id string The name of the mod.
---   @field public namespace string The name of the mod.
---   @field public data down.Data
---   @field public post_load? fun() Function that is invoked after all mod are loaded. Useful if you want the down environment to be fully set up before performing some task.
---   @field public dep? { [down.Mod.Id]: down.Mod.Mod } Contains the public tables of all mod that were dep via the `dependencies` array provided in the `setup()` function of this mod.
---   @field public setup? fun(): down.mod.Setup Function that is invoked before any other loading occurs. Should perform preliminary startup tasks.
---   @field public replaced? boolean If `true`, this means the mod is a replacement for a base mod. This flag is set automatically whenever `setup().replaces` is set to a value.
---   @field public handle? down.Handlers callback that is invoked any time an event the mod has subscribed to has fired.
---   @field public tests? table<string, fun()> Function that is invoked when the mod is being tested.
---   @field public events? down.mod.Events
---   @field public [any]? any
---
--- @class (exact) down.mod.Setup
--- @field loaded? boolean
--- @field dependencies? down.Mod.Id[]
--- @field replaces? string
--- @field merge? boolean
---
--- @class (exact) down.mod.Events: { [string]: down.Event }
---
--- The entire mod configuration
--- @alias down.Mod.Mod
---   | down.mod.lsp.Lsp
---   | down.mod.code.Code
---   | down.mod.time.Time
---   | down.mod.export.Export
---   | down.mod.tag.Tag
---   | down.mod.parse.Parse
---   | down.mod.edit.Edit
---   | down.mod.Data
---   | down.mod.Link
---   | down.mod.Task
---   | down.mod.template.Template
---   | down.mod.log.Log
---   | down.mod.cmd.Cmd
---   | down.mod.tool.Tool
---   | down.mod.workspace.Workspace
---   | down.mod.note.Note
---   | down.mod.ui.Ui
---   | down.mod.data.bookmark.Bookmark
---   | down.mod.data.Store
---   | down.mod.data.history.History
---   | down.mod.task.agenda.Agenda
---   | down.mod.task.Task
---   | down.mod.ui.Calendar
---   | down.mod.ui.calendar.Day
---   | down.mod.keymap.Keymap
---   | down.mod.ui.calendar.month.Month
---
--- @alias down.Mod.Config
---   | down.mod.keymap.Config
---   | down.mod.lsp.Config
---   | down.mod.data.Config
---   | down.mod.edit.Config
---   | down.mod.cmd.Config
---   | down.mod.tool.Config
---   | down.mod.workspace.Config
---   | down.mod.note.Config
---   | down.mod.ui.Config
---   | down.mod.parse.Config
---   | down.mod.code.Config
---   | down.mod.link.Config
---   | down.mod.task.Config
---   | down.mod.tag.Config
---   | down.mod.template.Config
---   | down.mod.export.Config
---   | down.mod.log.Config
---   | down.mod.task.agenda.Config
---   | down.mod.data.bookmark.Config
---   | down.mod.data.store.Config
---   | down.mod.data.history.Config
---   | down.mod.ui.calendar.Config
---   | down.mod.ui.calendar.day.Config
---   | down.mod.ui.calendar.month.Config
---   | down.mod.ui.calendar.week.Config
---
---  @alias down.Mod.Id
---  | "log"
---  | "mod"
---  | "data.store"
---  | 'tool.telescope'
---  | 'find.fzflua'
---  | 'find.builtin'
---  | 'find.snacks'
---  | 'find.mini'
---  | 'find'
---  | "data"
---  | "edit"
---  | "cmd"
---  | "tool"
---  | "workspace"
---  | "note"
---  | "ui"
---  | "keymap"
---  | "lsp"
---  | "tag"
---  | "time"
---  | "code"
---  | "link"
---  | "template"
---  | "task"
---  | "export"
---  | "ui.calendar"
---  | "ui.calendar.day"
---  | "ui.calendar.month"
---  | "tool.treesitter"
---  | "task.agenda"
---  | "ui.calendar.week"
---  | "data.bookmark"
---  | "data.store"
---  | "data.history"
---  | "task.agenda"
---  | "parse"
---  | "ui.win"
---  | "ui.icon"
---  | "edit.indent"
---
---
---  The user configuration passed into down.setup
---  @class (exact) down.mod.Config: {
---    [down.Mod.Id]?: down.Mod.Config,
---    dev?: boolean,
---    test?: boolean|string[],
---    bench?: boolean|string[],
---    load?: boolean|string[],
---    defaults?: boolean,
---    debug?: boolean,
---    hook?: fun(...: any)
---  }
---
--- The base configuration
--- @class (exact) down.config.BaseConfig: {
---   [string]?: any,
---   dev?: boolean,
--- }
---
--- @class (exact) down.Command
--- @field name? string
--- @field args? number
--- @field max_args? number
--- @field condition? string
--- @field complete? table<string, string[]>
--- @field callback? fun(e?: down.Event, ...: any)
--- @field min_args? number
--- @field commands? { [string]?:down.Command}

--- @alias down.CommandsB {[string]?: down.Command } | function
