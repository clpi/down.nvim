# Examples of user custom modules


## Example of a barebones module

```lua
---@brief Let's go through the most boilerplate, simple example of a module you may use.
---@brief This module will have no real functionality,
local mod = require "down.mod"


---@brief Let's say you want to create a module for Jupyter notebooks to run in Neovim.
---@brief We'll start by just creating a barebones module, with no functionality, just to show you how.
---@brief We will name this module "jupyter".
---@type down.Mod
local J = mod.create("jupyter", {

  ---@brief This is where we would automatically call any submodules underneath "jupyter" to be called in
  ---@brief simultaneously as it is loaded. Since we do not have any such submodules, we will leave this empty.

})

--[[           1. Flow of functions:

      +-------+  load mod   +------------------+ +------+ +----------+
      | setup |>----------->| cmds, opts, maps |>| load |>| postload |
      +-------+  set data   +------------------+ +------+ +----------+

--]]

---@brief This is where the module will first be `setup`. As you can see above, this occurs before a module has
---@brief fully loaded its data it needs to function. It may, however, perform important functionality during
---@brief this step, such as specifying dependencies it will need, setting up configuration, defining variables,
---@brief or even defining commands and autocommands that will invoke its functionality.
---@brief It must only return a table generally containing a confirmation it has loaded, as well as its
---@brief dependencies, except on rare occasions.
---@return down.mod.Setup
function J.setup()
  ---@class down.mod.Setup
  return {
    loaded = true,
    ---@brief For a jupyter module, we will likely need several dependencies, perhaps too many to list
    ---@brief through in such an early stage. Taking a guess, however, and knowing we can always change,
    ---@brief we'll just choose a few which we will likely need regardless.
    requires = {
      "data",
      "workspace",
      "data.code",
      "ui.progress",
      "ui.status",
      "ui.notify",
      "ui.vtext"
    }
  }
end

---@brief This is where we will set up the module's data and any methods it will call.
---@class down.jupyter.Data

  ---@brief One such piece of data you may wish to store is the ongoing collection of cells, as well
  ---@brief as their contents and type in the Juypyter notebook. You may even wish to leverage the
  ---@brief down.nvim `lsp.notebook` module to hook into the LSP for Jupyter notebooks.
  J.cells = {

  }

  ---@brief To keep track of the notebook currently being interacted with
  J.notebook = {

    path = nil,

    name = nil,

    kernel = "python3",

  }


---@brief Technically, we have now created a proper module that can be loaded into Neovim through down.nvim.
---@brief However, we will be typically be best off at the beginning characterizing the module with any
---@brief setup, dependencies, configuration, commands, and even keymaps you believe it may one day need.

---@brief Each modue has a config table specified, which is where the user may set any configuration options
---@brief changing the behaviour of the module.

---@class down.jupyter.Config
---@field kernal string: The kernel to use for the Jupyter user interface. Default is `python3
J.config = {

  ---@brief The default directory you might want to specify for Jupyter notebooks to be stored in.
  ---@brief You may also wish to leverage the dep "workspace" module to allow users to specify both
  ---@brief a specific workspace tey would like to associate with Jupyter notebooks, as well as a default
  ---@brief relative directory within that workspace.
  ---
  ---@brief Configuration details about created notebooks. While you are specifying default values here,
  ---@brief consider that a user will likely want to change several of the values.
  notebook = {

    default = "notebook.ipynb",

    dir = {

      workspace = "default",

      default = "notes",
    }

  },

  service = "jupyter",

  command = "jupyterlab",

  kernel = "python3",

  kernels = {
    "python3"
  }

}

---@brief There are many more aspects to a module that can and should be defined as you begin to flesh it out,
---@brief even before you begin to test any major functionality. These include defining commands, options,
---@brief mappings, not to mention learning the interdependencies between your module and other modules,
---@brief whether builtin or custom-made by the community.
---
---@brief Regardless, I hope this has provided a good starting point to help you to take the very first steps
---@brief in creating an awesome module to extend and bless the down.nvim ecosystem. Good luck and godspeed!
return J
```

## Example custom module

Note that the below example is **out of date** and needs to be updated. Thanks!

```lua
local down = require("down")

local mod, config, util = down.mod, down.config, down.util

local M = mod.create("user.example", {
  --- @brief submodules
  ---         child directories containing
  ---         modules to load in tandem, relative
  ---         to this (parent) module.
  --- "subexample",
  --- "pre_example",
  --- ...
})

M.setup = function()
  return {
    requires = {
      ---@brief dep modules
      ---         modules from builtin or custom
      ---         modules that can be loaded in (same as
      ---         if calling `require 'module'`) as a dependency
      ---         for the module.
      --- "ui.popup",
      --- "edit.link",
      --- "integration.treesitter",
      --- ...
    },
    loaded = true,
  }
end

---@class (exact) example.Config
M.config = {
  --- @brief module config
  ---          the public facing config for this module that can be
  ---          set by the user from its default values here.
  --- ...
}

M.load = function()
  --- @brief module load
  ---          a set of functions to run whenever the
  ---          module is fist loaded upon startup.
  ---          TODO: maybe just merge in with setup()
  --- ...
end

return M
```

- See [example.lua](../../lua/module/example.lua)
