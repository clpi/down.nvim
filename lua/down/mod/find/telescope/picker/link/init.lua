local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local telescope = require("telescope")
local conf = require("telescope.config").values

local function parse_links(content, link_type)
  local links = {}
  local pattern

  if link_type == "hyperlinks" then
    pattern = "%b<>"
  elseif link_type == "file_links" then
    pattern = "%[.-%]%((.-)%)"
  elseif link_type == "emails" then
    pattern = "%S+@%S+"
  else
    return links
  end

  for link in content:gmatch(pattern) do
    table.insert(links, link)
  end

  return links
end

local function markdown_links_picker(opts)
  opts = opts or {}
  local link_type = opts.link_type or "hyperlinks"

  local content = vim.fn.join(vim.fn.getline(1, "$"), "\n")
  local links = parse_links(content, link_type)

  pickers
    .new(opts, {
      prompt_title = "Markdown Links",
      finder = finders.new_table({
        results = links,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry, status)
          local bufnr = self.state.bufnr
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { entry.value })
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          print("Selected link: " .. selection.value)
        end)
        return true
      end,
    })
    :find()
end

telescope.register_extension({
  exports = {
    markdown_links = markdown_links_picker,
  },
})
