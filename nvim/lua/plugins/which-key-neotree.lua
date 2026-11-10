-- which-key in Neo-tree: only the explorer's own keys, with clear descriptions, plus the few global
-- keys that make sense from the tree (explorer, find, sessions, terminal, packages, global git,
-- windows). Editing keys (g / z / [ / ] motions, LSP, debugger, comments, save…) are left out.
-- Keys left out still work when typed (but after <Leader>, see which-key.lua: blocked).
-- Needs Config.building_buf, set in which-key.lua.

-- global keys kept in Neo-tree: exact keys, or prefixes ending with "*"
local KEEP = {
  "<Space>", "<Space>e", "<Space>o", "<Space>h", "<Space>q", "<Space>Q",
  "<Space>f*", "<Space>S*", "<Space>t*", "<Space>p*",
  "<Space>g", "<Space>gg", "<Space>gt", "<Space>gb", "<Space>gc", "<Space>gT",
  "<C-W>*", "<C-H>", "<C-J>", "<C-K>", "<C-L>", "<C-'>", "<C-Q>",
}

-- Neo-tree command (its keymap description) → description
local DESC = {
  open = "Open",
  child_or_open = "Expand the folder / open the file",
  parent_or_close = "Collapse / go to the parent folder",
  close_node = "Collapse this folder",
  close_all_nodes = "Collapse all folders",
  expand_all_subnodes = "Expand this folder and all its sub-folders",
  open_split = "Open in a split below",
  open_vsplit = "Open in a split on the right",
  open_tabnew = "Open in a new tab page",
  open_with_window_picker = "Open in a window (pick it)",
  system_open = "Open with the system app",
  add = "New file (end with / for a folder)",
  add_directory = "New folder",
  rename = "Rename",
  rename_basename = "Rename (name only, keep the extension)",
  delete = "Delete",
  restore_from_trash = "Restore from the trash",
  undo = "Undo the last file operation",
  copy = "Copy to… (asks where)",
  move = "Move to… (asks where)",
  copy_to_clipboard = "Copy (then p to paste)",
  cut_to_clipboard = "Cut (then p to paste)",
  paste_from_clipboard = "Paste here",
  clear_clipboard = "Empty the clipboard",
  copy_selector = "Copy the path / name (choose)",
  select = "Select / unselect (copy, cut, delete several)",
  invert_selection = "Invert the selection",
  clear_selection = "Clear the selection",
  set_root = "Make this folder the root",
  navigate_up = "Root: go up to the parent folder",
  toggle_hidden = "Hidden files: show / hide",
  toggle_preview = "Preview: on / off",
  scroll_preview = "Scroll the preview",
  toggle_auto_expand_width = "Auto width: on / off",
  show_file_details = "File details (size, dates)",
  refresh = "Refresh",
  fuzzy_finder = "Filter as you type",
  fuzzy_finder_directory = "Filter folders as you type",
  fuzzy_sorter = "Sort by fuzzy match",
  filter_on_submit = "Filter (applied on Enter)",
  clear_filter = "Clear the filter",
  find_files_in_dir = "Find files in this folder",
  find_all_files_in_dir = "Find files here, hidden ones too",
  find_words_in_dir = "Find text in this folder",
  find_all_words_in_dir = "Find text here, hidden files too",
  quick_jump = "Quick jump (labels)",
  next_source = "Next tab (File, Bufs, Git)",
  prev_source = "Previous tab (File, Bufs, Git)",
  next_git_modified = "Next changed file",
  prev_git_modified = "Previous changed file",
  git_add_file = "Git: stage this file",
  git_add_all = "Git: stage everything",
  git_unstage_file = "Git: unstage this file",
  git_toggle_file_stage = "Git: stage / unstage this file",
  git_revert_file = "Git: drop the changes of this file",
  git_commit = "Git: commit",
  git_commit_and_push = "Git: commit and push",
  git_push = "Git: push",
  git_pull = "Git: pull",
  git_undo_last_commit = "Git: undo the last commit",
  buffer_delete = "Close this buffer",
  toggleterm_float = "Terminal here: floating",
  toggleterm_horizontal = "Terminal here: below",
  toggleterm_vertical = "Terminal here: on the right",
  show_help = "Help: all the explorer keys",
  cancel = "Cancel / close the preview",
  close_window = "Close the explorer",
}

-- groups (prefix keys) of the explorer
local GROUPS = {
  { "g", group = "Git" },
  { "o", group = "Sort by" },
  { "f", group = "Find in this folder" },
  { "T", group = "Terminal in this folder" },
  { "[", group = "Previous…" },
  { "]", group = "Next…" },
}

local function kept(keys)
  for _, k in ipairs(KEEP) do
    if k:sub(-1) == "*" then
      if vim.startswith(keys, k:sub(1, -2)) then return true end
    elseif keys == k then
      return true
    end
  end
  return false
end

---@type LazySpec
return {
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      local filter = opts.filter
      opts.filter = function(m)
        if filter and not filter(m) then return false end
        local buf = require("which-key.config").building_buf
        if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "neo-tree") then return true end
        if m.buffer and m.buffer ~= 0 then -- the explorer's own keys
          if m.desc and DESC[m.desc] then m.desc = DESC[m.desc] end
          return true
        end
        local ok, keys = pcall(function() return vim.fn.keytrans(vim.keycode(m.lhs)) end)
        return ok and kept(keys)
      end
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      opts.event_handlers = opts.event_handlers or {}
      table.insert(opts.event_handlers, {
        event = "neo_tree_buffer_enter",
        handler = function(args)
          local buf = args and args.bufnr or vim.api.nvim_get_current_buf()
          if vim.b[buf].wk_neotree_groups then return end
          vim.b[buf].wk_neotree_groups = true
          local spec = vim.tbl_map(function(g) return vim.tbl_extend("force", g, { buffer = buf }) end, GROUPS)
          require("which-key").add(spec)
        end,
      })
    end,
  },
}
