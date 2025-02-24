--- @meta down.ids.workspcae
--- The context of an in-file object.
--- @class (exact) down.Log: { data?: { [string]: string } }
---
--- The context of an in-file object.
--- @class (exact) down.Template: {
---   id: string,
---   uri: down.Uri,
---   context: down.Context,
---   body: string,
---   kind: string } Link
---
--- The context of an in-file object.
--- @class (exact) down.Snippet: {
---   id: string,
---   uri: down.Uri,
---   context: down.Context,
---   body: string,
---   kind: string } Link
---
--- The context of an in-file object.
--- @class (exact) down.Link: {
---   id: string,
---   uri: down.Uri,
---   context: down.Context,
---   target: down.Uri,
---   body: string,
---   kind: string } Link
---
--- The context of an in-file object.
--- @class (exact) down.Anchor: {
---   id: string,
---   uri: down.Uri,
---   context: down.Context,
---   body: string,
---   kind: string } Link
---
--- The context of an in-file object.
--- @class (exact) down.Note: {
---   id: string,
---   uri: down.Uri,
---   context: down.Context,
---   body: string,
---   kind: string } Link
---
--- The context of an in-file object.
--- @class (exact) down.Agenda: {
---   id: string,
---   uri: down.Uri,
---   body: string,
---   groups: down.Group[],
---   tasks: down.Task[],
---   scope: down.Scope[],
---   kind: string } Link
---
--- The tag object.
--- @class down.Tag: { id: string, context: down.Context, flags: down.Flag[] } tags
---
--- @class down.TagsField: { tags: down.Tag[] } Has tags
---
--- @alias down.Tags down.Tag[] Has tags
---
--- @class (exact) Node<I, E, N>: { index: I, edges: E[], weight: N }
---
--- @class (exact) Edge<K1, K2, E>: { [K1]: { [K2]: E } }
---
--- The category object.
--- @class down.Category: { group?: string }
---
--- The project object.
--- @class (exact) down.Group: { group?: string }
---   @field public name string
---   @field public data table<any, any>
---   @field public agenda? down.Data<down.Agenda>
---   @field public info? down.Info
---   @field public tasks? down.Data<down.Task>
---
--- The project object.
--- @class (exact) down.Project
---   @field public id down.Uri
---   @field public info? down.Info
---   @field public data table<any, any>
---   @field public agenda? down.Data<down.Agenda>
---   @field public tasks? down.Data<down.Task>
---
--- The scope of an entity.
--- @alias down.Flag {
---   flag: string,
---   info: down.Info,
---   data: table<any, any>,
--- }
---
---
--- The important store value object
--- @class (exact) down.Log<S>: { id: string, uri: down.Uri, config?: down.config.Local }
---
--- The user object.
--- @class (exact) down.User User
---   @field public id down.Id uri
---   @field public home down.Uri home
---   @field public email? string uri
---   @field public username? string uri
---
--- @class (exact) down.Entity<V>: down.Base, {
---   tags?: down.Tag[],
---   info?: down.HasInfo,
---   context: down.Context,
--- }
---
--- The scope of an entity.
--- @class (exact) down.Task
---   @field public name string
---   @field public info down.Info
---   @field public context down.Context
---   @field public store? down.Id
---   @field public status down.task.Status
---   @field public priority down.task.Priority
---
