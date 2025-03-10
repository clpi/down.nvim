local mod = require("down.mod")
local util = require("down.util")

local Popup = require("down.mod").new("ui.popup")

Popup.setup = function()
  return {
    loaded = true,
  }
end

--- Constructs a new selection
---@param buffer number #The number of the buffer the selection should attach to
---@param keybind_buffer number? #An alternate buffer from which the keys for the selection popup are entered.
---@return table #A selection object
Popup.begin_selection = function(buffer, keybind_buffer)
  -- Data that is gathered up over the lifetime of the selection popup
  local data = {}

  -- Get the name of the buffer we are about to attach to
  local name = vim.api.nvim_buf_get_name(buffer)

  -- Create a namespace from the buffer name
  local namespace = vim.api.nvim_create_namespace(name)

  --- Simply renders things using extmarks
  local renderer = {
    position = 0,

    --- Renders something in the buffer
    --- @vararg table #A vararg of { text, highlight } tables
    render = function(self, ...)
      vim.api.nvim_buf_set_option(buffer, "modifiable", true)

      -- Don't render if we're on the first line
      -- because buffers always open with one line available
      -- anyway
      if self.position > 0 then
        vim.api.nvim_buf_set_lines(buffer, -1, -1, false, { "" })
      end

      if not vim.tbl_isempty({ ... }) then
        vim.api.nvim_buf_set_extmark(buffer, namespace, self.position, 0, {
          virt_text_pos = "overlay",
          virt_text = { ... },
        })
      end

      -- Track which line we're on
      self.position = self.position + 1

      vim.api.nvim_buf_set_option(buffer, "modifiable", false)
    end,

    --- Resets the renderer by clearing the buffer and resetting
    --- the render head
    reset = function(self)
      self.position = 0

      vim.api.nvim_buf_set_option(buffer, "modifiable", true)

      vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
      vim.api.nvim_buf_set_lines(buffer, 0, -1, true, {})

      vim.api.nvim_buf_set_option(buffer, "modifiable", false)
    end,
  }

  ---@class base.ui.selection
  local selection = {
    page = 1,
    pages = { {} },
    opts = {},
    localkeys = {},
    states = {},

    --- Retrieves the options for a certain type
    ---@param type string #The type of element to extract the options for
    ---@return table #The options for said type or {}
    options_for = function(self, type)
      return self.opts[type] or {}
    end,

    --- Applies some new functions for the selection
    ---@param tbl_of_functions table #A table of custom elements
    ---@return base.ui.selection
    apply = function(self, tbl_of_functions)
      self = vim.tbl_deep_extend("force", self, tbl_of_functions)
      return self
    end,

    --- Adds a new element to the current page
    ---@param element function #A pointer to the function that created the item
    --- @vararg any #The arguments that were used to construct the element
    add = function(self, element, ...)
      table.insert(self.pages[self.page], { self[element], { ... } })
    end,

    --- Attaches a key listener to the current buffer
    ---@param keys table #An array of keys to bind
    ---@param func function #A callback to invoke whenever the key has been pressed
    ---@param mode string #Optional, base "n": the mode to create the listener for
    ---@return base.ui.selection
    listener = function(self, keys, func, mode)
      -- Go through all keys that the user has bound a listener to and bind them!
      for _, key in ipairs(keys) do
        vim.keymap.set(mode or "n", key, util.wrap(func, self), {
          buffer = keybind_buffer or buffer,
          silent = true,
          nowait = true,
        })
      end

      return self
    end,

    --- Attaches a key listener to the current page
    ---@param keys table #An array of keys to bind
    ---@param func function #A callback to invoke whenever the key has been pressed
    ---@param mode string #Optional, base "n": the mode to create the listener for
    ---@return base.ui.selection
    locallistener = function(self, keys, func, mode)
      -- Extend the page-local keys too
      self.localkeys = vim.list_extend(self.localkeys, keys)

      -- Go through all keys that the user has bound a listener to and bind them!
      for _, key in pairs(keys) do
        vim.keymap.set(mode or "n", key, util.wrap(func, self), {
          buffer = keybind_buffer or buffer,
          silent = true,
          nowait = true,
        })
      end

      return self
    end,

    --- Sets some options for the selection to take into account
    ---@param opts table #A table of options
    ---@return base.ui.selection
    options = function(self, opts)
      self.opts = vim.tbl_deep_extend("force", self.opts, opts)
      return self
    end,

    --- Returns the data the selection holds
    data = function(_)
      return data
    end,

    --- Add a pair of key, value in data
    ---@param key string #The name for the key
    ---@param value any #Its content
    set_data = function(_, key, value)
      data[key] = value
    end,

    --- Detaches the selection popup from the current buffer
    --- Does *not* close the buffer
    detach = function(self)
      if not vim.api.nvim_buf_is_valid(buffer) then
        return
      end

      renderer:reset()

      self.page = 1
      self.pages = {}

      return data
    end,

    --- Destroys the selection popup and the buffer it occupied
    destroy = function(self)
      if not vim.api.nvim_buf_is_valid(buffer) then
        return
      end

      renderer:reset()

      self.page = 1
      self.pages = {}

      vim.api.nvim_buf_delete(buffer, { force = true })
      return data
    end,

    --- Renders some text on the screen
    ---@param text string #The text to display
    ---@param highlight string #An optional highlight group to use (base to "Normal")
    ---@return base.ui.selection
    text = function(self, text, highlight)
      local custom_highlight = self:options_for("text").highlight

      self:add("text", text, highlight)

      renderer:render({
        text,
        highlight or custom_highlight or "Normal",
      })

      return self
    end,

    --- Generates a title
    ---@param text string #The text to display
    ---@return base.ui.selection
    title = function(self, text)
      return self:text(text, "@text.title")
    end,

    --- Simply enters a blank line
    ---@param count number #An optional number of blank lines to apply
    ---@return base.ui.selection
    blank = function(self, count)
      count = count or 1
      renderer:render()

      self:add("blank", count)

      if count <= 1 then
        return self
      else
        return self:blank(count - 1)
      end
    end,

    --- Creates a pressable flag
    ---@param flag string #The flag. These should be a single character
    ---@param description string #The description for the flag
    ---@param callback table|function #The callback to invoke or configuration options for the flag
    ---@return base.ui.selection
    flag = function(self, flag, description, callback)
      -- Set up the configuration by properly merging everything
      local configuration = vim.tbl_deep_extend(
        "force",
        {
          keys = {
            flag,
          },
          hl = {
            -- TODO: Change highlight group names
            key = "@down.selection_window.key",
            description = "@down.selection_window.keyname",
            delimiter = "@down.selection_window.arrow",
          },
          delimiter = " -> ",
          -- Whether to destroy the selection popup when this flag is pressed
          destroy = true,
        },
        self:options_for( -- First merge the global options
          "flag"
        ),
        type(callback) == "table" and callback or {} -- Then optionally merge the flag-specific options
      )

      self:add("flag", flag, description, callback)

      -- Attach a locallistener to this flag
      self = self:locallistener(configuration.keys, function()
        -- Delete the selection before any action
        -- We assume pressing a flag does quit the popup
        if configuration.destroy then
          self:destroy()
        end

        -- Invoke the user-defined callback
        (function()
          if type(callback) == "function" then
            return callback
          else
            return callback and callback.callback or function() end
          end
        end)()()
      end)

      -- Actually render the flag
      renderer:render({
        flag,
        configuration.hl.key,
      }, {
        configuration.delimiter,
        configuration.hl.delimiter,
      }, {
        description or "no description",
        configuration.hl.description,
      })

      return self
    end,

    --- Constructs a recursive (nested) flag
    ---@param flag string #The flag key, should be one character only
    ---@param description string #The description of the flag
    ---@param callback function|table #The callback to invoke after the flag is entered
    ---@return base.ui.selection
    rflag = function(self, flag, description, callback)
      -- Set up the configuration by properly merging everything
      local configuration = vim.tbl_deep_extend(
        "force",
        {
          keys = {
            flag,
          },
          hl = {
            -- TODO: Change highlight group names
            key = "@down.selection_window.key",
            description = "@down.selection_window.keyname",
            delimiter = "@down.selection_window.arrow",
          },
          delimiter = " -> ",
        },
        self:options_for( -- First merge the global options
          "rflag"
        ),
        type(callback) == "table" and callback or {} -- Then optionally merge the rflag-specific options
      )

      self:add("rflag", flag, description, callback)

      -- Attach a locallistener to this flag
      self = self:locallistener(configuration.keys, function()
        -- Create a new page to allow the renderer to start fresh
        self:push_page();

        -- Invoke the user-defined callback
        (function()
          if type(callback) == "function" then
            return callback()
          elseif callback.callback then
            return callback.callback()
          end
        end)()
      end)

      -- Actually render the flag
      renderer:render({
        flag,
        configuration.hl.key,
      }, {
        configuration.delimiter,
        configuration.hl.delimiter,
      }, {
        "+" .. (description or "no description"),
        configuration.hl.description,
      })

      return self
    end,

    --- Pushes a new page onto the stack, clearing the buffer
    --- and starting fresh
    push_page = function(self)
      -- Go through every locally bound key and unbind it
      -- We don't want page-local keys to continue being bound
      for _, key in ipairs(self.localkeys) do
        vim.api.nvim_buf_del_keymap(buffer, "", key)
      end

      self.localkeys = {}

      self.page = self.page + 1
      self.pages[self.page] = {}

      renderer:reset()
    end,

    --- Pops the page stack, effectively restoring the previous
    --- state
    pop_page = function(self)
      -- If we have no pages left then there's nothing to pop
      if self.page - 1 < 1 then
        return
      end

      for _, key in ipairs(self.localkeys) do
        vim.api.nvim_buf_del_keymap(buffer, "", key)
      end

      self.localkeys = {}
      -- Delete the current page from existence
      self.pages[self.page] = {}

      -- Decrement the page counter
      self.page = self.page - 1

      -- Create a local copy of the previous (now current) page
      -- We do this because when we start rendering objects
      -- they'll start getting added onto the current page
      -- and will start looping to infPopupy.
      local page_copy = vim.deepcopy(self.pages[self.page])
      -- Clear the current page;
      self.pages[self.page] = {}

      -- Reset the renderer to make sure we're starting afresh
      renderer:reset()

      -- Loop through all items in the page and recreate
      -- each element
      for _, item in ipairs(page_copy) do
        item[1](self, unpack(item[2]))
      end
    end,

    --- Creates a prompt inside the page
    ---@param text string #The prompt text
    ---@param callback table|function #The callback to invoke or configuration options for the prompt
    ---@return base.ui.selection
    prompt = function(self, text, callback)
      -- Set up the configuration by properly merging everything
      local configuration = vim.tbl_deep_extend(
        "force",
        {
          text = text or "Input",
          delimiter = " -> ",
          -- Automatically destroys the popup when prompt is confirmed
          destroy = true,
          prompt_text = nil,
        },

        self:options_for( -- First merge the global options
          "prompt"
        ),
        type(callback) == "table" and callback or {} -- Then optionally merge the flag-specific options
      )
      self:add("prompt", text, callback)
      self = self:blank()

      -- Create prompt text
      vim.fn.prompt_setprompt(
        buffer,
        configuration.text .. configuration.delimiter
      )

      -- Create prompt
      vim.api.nvim_buf_set_option(buffer, "modifiable", true)
      local options = vim.api.nvim_buf_get_option(buffer, "buftype")
      vim.api.nvim_buf_set_option(buffer, "buftype", "prompt")

      -- Create a callback to be invoked on prompt confirmation
      vim.fn.prompt_setcallback(buffer, function(content)
        if content:len() > 0 then
          -- Remakes the buftype option the same before prompt
          vim.api.nvim_buf_set_option(buffer, "buftype", options)

          -- Delete the selection before any action
          -- We assume pressing a flag does quit the popup
          if configuration.pop then
            -- Reset buftype options to previous ones
            self:pop_page()
          elseif configuration.destroy then
            self:destroy()
          end

          -- Invoke the user-defined callback
          if type(callback) == "function" then
            callback(content)
          else
            callback.callback(content)
          end
        end
      end)

      -- Jump to insert mode
      vim.api.nvim_feedkeys("A", "t", false)

      -- Add prompt text in the prompt
      if configuration.prompt_text then
        vim.api.nvim_feedkeys(configuration.prompt_text, "n", false)
      end

      return self
    end,

    --- Concatenates a `callback` function that returns the selection popup to the existing selection popup
    --- Example:
    --- selection
    ---   :text("test")
    ---   :concat(this_is_a_function)
    ---@param callback function #The function to append
    ---@return base.ui.selection
    concat = function(self, callback)
      self = callback(self)
      return self
    end,

    ---@return base.ui.selection
    setstate = function(self, key, value, rerender)
      self.states[key] = {
        value = value,
      }

      -- Reset the renderer to make sure we're starting afresh
      renderer:reset()

      if rerender then
        renderer:reset()
        -- Loop through all items in the page and recreate
        -- each element
        for _, item in ipairs(self.pages[self.page]) do
          item[1](self, unpack(item[2]))
        end
      end

      return self
    end,

    -- TODO: Add support for a callback to be invoked on state change
    --- Nicely display a data to be re-rendered on each modification
    ---@param key string key to data
    ---@param format string formatted string to display the content of key
    ---@param force_render? boolean forcefully render the message even if the state isn't present
    ---@return base.ui.selection
    stateof = function(self, key, format, force_render)
      format = format or "%s"
      force_render = force_render or false

      -- Set up the configuration by properly merging everything
      local configuration = vim.tbl_deep_extend("force", {
        highlight = "Normal",
      }, self:options_for("stateof"))

      self:add("stateof", key, format)

      if force_render or (self.states[key] and self.states[key].value) then
        renderer:render({
          format:format(self.states[key] and self.states[key].value or " "),
          configuration.highlight,
        })
      end

      return self
    end,
  }

  return selection
end
--- Opens a floating window at the specified position and asks for user input
---@param name string #The name of the floating window
---@param input_text string #The input text to prompt the user for input
---@param callback fun(entered_text: string, data: table) #A function that gets invoked whenever the user provides some text.
---@param modifiers table #Special table to modify certain attributes of the floating window (like centering on the x or y axis)
---@param config table #A config like you would pass into nvim_open_win()
Popup.create_prompt = function(name, input_text, callback, modifiers, config)
  local window_config = {
    relative = "win",
    style = "minimal",
    border = "rounded",
  }

  -- Apply any custom modifiers that the user has specified
  window_config =
      assert(mod.get_mod("ui"), "ui is not loaded!").apply_custom_options(
        modifiers,
        vim.tbl_extend("force", window_config, config or {})
      )

  local buf = vim.api.nvim_create_buf(false, true)

  -- Set the buffer type to "prompt" to give it special behaviour (:h prompt-buffer)
  vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
  vim.api.nvim_buf_set_name(buf, name)

  -- Create a callback to be invoked on prompt confirmation
  vim.fn.prompt_setcallback(buf, function(content)
    if content:len() > 0 then
      callback(content, {
        close = function(opts)
          vim.api.nvim_buf_delete(buf, opts or { force = true })
        end,
      })
    end
  end)

  -- Construct some custom mappings for the popup
  vim.keymap.set("n", "<Esc>", vim.cmd.quit, { silent = true, buffer = buf })
  vim.keymap.set("n", "<Tab>", "<CR>", { silent = true, buffer = buf })
  vim.keymap.set("i", "<Tab>", "<CR>", { silent = true, buffer = buf })
  vim.keymap.set("i", "<C-c>", "<Esc>:q<CR>", { silent = true, buffer = buf })

  -- If the use has specified some input text then show that input text in the buffer
  if input_text then
    vim.fn.prompt_setprompt(buf, input_text)
  end

  -- Automatically enter insert mode
  vim.api.nvim_feedkeys("i", "t", false)

  -- Create the floating popup window with the prompt buffer
  local winid = vim.api.nvim_open_win(buf, true, window_config)

  -- Popupake sure to clean up the window if the user leaves the popup at any time
  vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "BufDelete" }, {
    buffer = buf,
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, winid, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end,
  })

  -- HACK(vhyrro): Prevent the "not enough room" error when leaving the window.
  -- See: https://github.com/neovim/neovim/issues/19464
  vim.api.nvim_win_set_option(winid, "winbar", "")
end

return Popup
