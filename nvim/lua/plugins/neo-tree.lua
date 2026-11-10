-- Neo-tree: a file outside the current folder (cwd) no longer breaks the explorer.
--
-- With follow_current_file, Neo-tree asks "File not in cwd. Change cwd to …?" in a small popup each
-- time the current file is outside the cwd (sessions often hold such files). In 3.42 that prompt is
-- also not awaited when opening the tree: the tree is opened twice ("Invalid window id", "E95:
-- Buffer with this name already exists") and the popup left behind swallows the next keys
-- (<Leader>e no longer closes the tree). Here the answer is always "no", without a popup: the tree
-- stays on the project, and the file is only revealed when it is inside it.
-- Patches neo-tree.ui.inputs.confirm (Neo-tree 3.x).

--
-- Also: in the tree, Space stays the leader key (<Leader>e closes the tree, <Leader>o goes back).
-- AstroNvim turns off "<Space>", but Neo-tree's default is spelled "<space>" and stayed mapped
-- (toggle_node), so <Leader>… did nothing from the tree.
--
-- q no longer closes the tree: only <Leader>e (toggle). q does nothing there (see keymaps.lua).

local COLUMNS = { file_size = true, type = true, last_modified = true, created = true }
local columns_shown = false

local function enable(components, on)
  for _, c in ipairs(components or {}) do
    if COLUMNS[c[1]] then c.enabled = on end
    if c.content then enable(c.content, on) end
  end
end

local function set_columns(state, on)
  for _, components in pairs(state and state.renderers or {}) do
    enable(components, on)
  end
end

local function toggle_columns()
  columns_shown = not columns_shown
  local renderer = require("neo-tree.ui.renderer")
  require("neo-tree.sources.manager")._for_each_state(nil, function(state)
    set_columns(state, columns_shown)
    renderer.redraw(state)
  end)
end

---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = function(_, opts)
    opts.window = opts.window or {}
    opts.window.mappings = opts.window.mappings or {}
    opts.window.mappings["<space>"] = false
    opts.window.mappings["<Space>"] = false
    -- q: show / hide the size, type and date columns (hidden by default). A mapping, not false:
    -- an unmapped q gets AstroNvim's "q closes nofile windows" mapping.
    opts.default_component_configs = opts.default_component_configs or {}
    for name in pairs(COLUMNS) do
      opts.default_component_configs[name] = vim.tbl_extend("force", opts.default_component_configs[name] or {}, { enabled = false })
    end
    opts.window.mappings["q"] = { toggle_columns, desc = "Columns (size, type, dates): show / hide" }
    opts.event_handlers = opts.event_handlers or {}
    table.insert(opts.event_handlers, { event = "before_render", handler = function(state) set_columns(state, columns_shown) end })

    -- Z: the opposite of z (collapse all): expand the folder under the cursor and all its sub-folders
    opts.window.mappings["Z"] = "expand_all_subnodes"

    -- compact folders: a folder holding only one folder is shown on one line with it
    -- (src/main/java/com/example/perf), as in VS Code / IntelliJ. "deep" scans ahead so that
    -- folders are grouped as soon as they show, not after they are opened.
    for _, source in ipairs({ "filesystem", "git_status", "buffers" }) do
      opts[source] = opts[source] or {}
      opts[source].group_empty_dirs = true
    end
    opts.filesystem.scan_mode = "deep"
  end,
  config = function(_, opts)
    require("neo-tree").setup(opts)
    local inputs = require("neo-tree.ui.inputs")
    local confirm = inputs.confirm
    inputs.confirm = function(message, callback)
      if callback and type(message) == "string" and vim.startswith(message, "File not in cwd") then
        return callback(false)
      end
      return confirm(message, callback)
    end
  end,
}
