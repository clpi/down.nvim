--- @meta down.ids
--- @brief Provides core data types
--- @version <5.2,JIT
---
---
--- The important store value object
--- @class (exact) down.old.Store<V>: { id: down.store.id, uri: down.Uri, data?: down.store.Data<V> } store
---
--- [string]: down.Store<V>
--- @class (exact) down.old.store.Map<V>: { [down.store.Key]?: down.Store<V> } Map { log1 = { i}}
---
--- The important store value object
--- @class (exact) down.old.store.Kind: { [down.store.ItemKind]?: down.store.Map<down.store.Key> }
---
---
---
---
--- down.Mods
--- @class (exact) down.mod.config.Cfg: table
---   @field [string]? { [string]?: any }
---   @field enabled? boolean
---
--- TODO: merge data field to [string]? { [string]?: down.Event }
--- TODO:   down.mod.Events.defined ->
--- TODO:     #field [string]? { [string]?: down.Event }
---
--- @class (exact) down.event.Subscribed
---   @field public [string]? { [string]: boolean }

---
--- @class (exact) down.mod.Config: { [string]?: any }
--- @field public enabled? boolean
---   @field public [string]? any

--- TODO: merge data field to [string]?: down.mod.Data
--- TODO:   down.Mod. ->
--- TODO:     #field [string]? down.config.UserMod
--- TODO:   down.Mod.config ->
--- TODO:     #field config? down.mod.Config

---
--- @class (exact) down.config.Ft
---   @field md boolean
---   @field mdx boolean
---   @field markdown boolean
---   @field down boolean
---
--- TODO: make down.config.User? table
--- TODO:   down.config.config.User.mod.config ->
--- TODO:     #field [string]? down.config.UserMod
---
--- @class (exact) down.config.User
---   @field [string]? down.Mod.Config
---   @field hook? fun(args?: string) Hook to optionally run on load
---   @field dev? boolean Whether to start in dev mode
---
--- TODO: make down.config.UserMod? table
--- TODO:   down.config.UserMod.config ->
--- TODO:     #field [string]? down.Mod
---
--- @class (exact) down.config.UserConfig: down.config.BaseConfig, {
---   lsp?: down.mod.lsp.Config,
---   data?: down.mod..Config,
---   edit?: down.mod.edit.Config,
---   config?: down.mod.config.Config,
---   cmd?: down.mod.cmd.Config,
---   tool?: down.mod.tool.Config,
---   workspace?: down.mod.worksspace.Config,
---   note?: down.mod.note.Config,
---   ui?: down.mod.ui.Config,
---   config?: down.mod.config.Config,
--- }

--- @alias down.Pathsep "\\" | "/"
---
--[[
--- @class  down.Config
---   @field log? down.log.Config
---   @field defaults? boolean|string[]
---   @field dev? boolean  Whether to start in dev mode
---   @field debug? boolean Whether to start in debug mode
---   @field bench? boolean Whether to start in benchmark mode
---   @field test? boolean Whether to start in test mode
---   @field load? boolean Whether to load the user config
---   @field user down.mod.Config The user config to load in
---   @field hook? fun()   A hook that is run when down is started
---   @field started boolean                                   Set to `true` when down is fully initialized.
---   @field version string                                    The version of down that is currently active. Automatically updated by CI on every release.
---   @field setup fun(self: down.Config, user: down.config.User, default: string[], ...: any): boolean Loads user config
---   @field homedir fun(...: string): string
---   @field vimdir fun(...: string): string
---   @field file fun(file: string | nil): string
---   @field fromfile fun(f: string | nil): down.config.User
--]]

--- Stores the config for the entirety of down.
--- This includes not only the user config (passed to `setup()`), but also internal
--- variables that describe something specific about the user's hardware.
--- @see down.Setup
---
---
--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
