-- Line bookmarks (bookmarks.nvim): an icon in the sign column on the bookmarked line, an optional
-- name shown at the end of the line, kept across restarts (~/.local/share/nvim/bookmarks.json;
-- the plugin's per-project .bms files are not used, they would land in the repositories).
-- Bookmarks follow their line when lines are added or removed above.
--   <Leader>ma  bookmark this line (on / off)     <Leader>mr  name this line's bookmark
--   <Leader>mm  bookmarks of this project          <Leader>mM  bookmarks of all projects
--   <Leader>1…4 go to bookmark 1…4 of this project   <Leader>m1…m4  give this line's bookmark
--               number 1…4 (again: removes it); a number belongs to one bookmark per project
--   <Leader>mj / <Leader>mk  next / previous bookmark in this file
--   <Leader>mx  remove this file's bookmarks
-- In the list: Enter opens, typing filters (name, file, line text), Ctrl-e renames, Ctrl-x removes,
-- Alt-1…4 sets the number (again: removes it). Esc closes the list. An empty name removes the
-- name. Numbered bookmarks come first in the list.
-- Pinned (like kulala): the list reads the plugin's storage (config.cache.data).

local ICON = "󰃀"
local NAMED_ICON = "󰃃"
local SLOT_ICONS = { "󰎤", "󰎧", "󰎪", "󰎭" }
-- the name and the number are stored in the plugin's annotation: "@b <name>", or "@<1-4> [name]"
-- for a numbered one. The plugin shows the first letter of a plain annotation as the sign, a
-- keyword ("@b", "@1"…) gets its icon instead, and the annotation follows the line.
local PREFIX = "@b"

-- annotation -> number (or nil), name (or nil)
local function parse(ann)
  ann = ann or ""
  local tag, rest = ann:match("^@([b1-4])%s*(.*)$")
  if not tag then rest = ann end
  rest = vim.trim(rest or "")
  return tonumber(tag), rest ~= "" and rest or nil
end

local function build(slot, name)
  if slot then return "@" .. slot .. (name and (" " .. name) or "") end
  return name and (PREFIX .. " " .. name) or nil
end

local function strip(ann) return select(2, parse(ann)) end

-- project = git repository of the working directory, else the working directory
local function project_root()
  local cwd = vim.uv.fs_realpath(vim.uv.cwd() or ".") or vim.uv.cwd()
  return vim.fs.root(cwd, ".git") or cwd
end

local function in_root(file, root) return file == root or vim.startswith(file, root .. "/") end

-- bookmarks: numbered ones first (by number), then by file and line; only the project's when all
-- is false
local function bookmarks(all)
  local actions = require("bookmarks.actions")
  pcall(actions.sync_all) -- fold in pending line moves
  local root = project_root()
  local list = {}
  for file, marks in pairs(require("bookmarks.config").config.cache.data or {}) do
    if all or in_root(file, root) then
      for lnum, m in pairs(marks) do
        local slot, name = parse(m.a)
        table.insert(list, { file = file, lnum = tonumber(lnum), line = vim.trim(m.m or ""), name = name, slot = slot })
      end
    end
  end
  table.sort(list, function(a, b)
    if (a.slot or 99) ~= (b.slot or 99) then return (a.slot or 99) < (b.slot or 99) end
    if a.file ~= b.file then return a.file < b.file end
    return a.lnum < b.lnum
  end)
  return list, root
end

local function open(b)
  vim.cmd.edit(vim.fn.fnameescape(b.file))
  pcall(vim.api.nvim_win_set_cursor, 0, { b.lnum, 0 })
  vim.cmd("normal! zz")
end

local set_name, set_slot, ask_name -- defined below

local function pick(all)
  local snacks = require("snacks")
  local function finder()
    local list, root = bookmarks(all)
    local items = {}
    for _, b in ipairs(list) do
      local rel = vim.startswith(b.file, root .. "/") and b.file:sub(#root + 2) or vim.fn.fnamemodify(b.file, ":~")
      table.insert(items, {
        file = b.file,
        pos = { b.lnum, 0 },
        rel = rel,
        bm = b,
        text = table.concat({ b.name or "", rel, b.line }, " "),
      })
    end
    return items
  end
  snacks.picker.pick({
    title = (all and "Bookmarks (all projects)" or "Bookmarks") .. "  ·  C-e rename  C-x remove  M-1…4 number",
    finder = finder,
    format = function(item)
      local b = item.bm
      local out = {
        { b.slot and (SLOT_ICONS[b.slot] .. " ") or "  ", "BookMarksAnn" },
        { (b.name and NAMED_ICON or ICON) .. " ", b.name and "BookMarksAnn" or "BookMarksAdd" },
      }
      if b.name then table.insert(out, { b.name .. "  ", "SnacksPickerLabel" }) end
      table.insert(out, { item.rel, "SnacksPickerFile" })
      table.insert(out, { ":" .. b.lnum .. "  ", "SnacksPickerRow" })
      table.insert(out, { b.line, "SnacksPickerComment" })
      return out
    end,
    confirm = function(picker, item)
      picker:close()
      if item then open(item.bm) end
    end,
    actions = {
      bookmark_delete = function(picker, item)
        if not item then return end
        require("bookmarks.actions").bookmark_del(item.bm.file, item.bm.lnum)
        picker:find()
      end,
      bookmark_slot1 = function(picker, item) if item then set_slot(item.bm.file, item.bm.lnum, 1); picker:find() end end,
      bookmark_slot2 = function(picker, item) if item then set_slot(item.bm.file, item.bm.lnum, 2); picker:find() end end,
      bookmark_slot3 = function(picker, item) if item then set_slot(item.bm.file, item.bm.lnum, 3); picker:find() end end,
      bookmark_slot4 = function(picker, item) if item then set_slot(item.bm.file, item.bm.lnum, 4); picker:find() end end,
      bookmark_rename = function(picker, item)
        if not item then return end
        ask_name(item.bm.name, function(name)
          set_name(item.bm.file, item.bm.lnum, name)
          picker:find()
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-x>"] = { "bookmark_delete", mode = { "n", "i" }, desc = "Remove the bookmark" },
          ["<C-e>"] = { "bookmark_rename", mode = { "n", "i" }, desc = "Rename the bookmark" },
          ["<M-1>"] = { "bookmark_slot1", mode = { "n", "i" }, desc = "Bookmark number 1" },
          ["<M-2>"] = { "bookmark_slot2", mode = { "n", "i" }, desc = "Bookmark number 2" },
          ["<M-3>"] = { "bookmark_slot3", mode = { "n", "i" }, desc = "Bookmark number 3" },
          ["<M-4>"] = { "bookmark_slot4", mode = { "n", "i" }, desc = "Bookmark number 4" },
        },
      },
      list = {
        keys = {
          ["<C-x>"] = "bookmark_delete",
          ["dd"] = "bookmark_delete",
          ["<C-e>"] = "bookmark_rename",
          ["r"] = "bookmark_rename",
          ["1"] = "bookmark_slot1",
          ["2"] = "bookmark_slot2",
          ["3"] = "bookmark_slot3",
          ["4"] = "bookmark_slot4",
          ["<M-1>"] = "bookmark_slot1",
          ["<M-2>"] = "bookmark_slot2",
          ["<M-3>"] = "bookmark_slot3",
          ["<M-4>"] = "bookmark_slot4",
        },
      },
    },
  })
end

-- set the annotation of the bookmark at file:lnum, from anywhere (the list too): updates the
-- plugin's storage, repaints the signs of the buffers showing the file, saves
local function set_ann(file, lnum, ann, save)
  local actions = require("bookmarks.actions")
  local data = require("bookmarks.config").config.cache.data
  local m = data[file] and data[file][tostring(lnum)]
  if not m then return end
  local entry = { m = m.m, a = ann }
  actions.bookmark_del(file, lnum) -- marks the storage as changed, drops the old sign
  data[file] = data[file] or {}
  data[file][tostring(lnum)] = entry
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.uv.fs_realpath(vim.api.nvim_buf_get_name(buf)) == file then
      actions.refresh(buf, true, true)
    end
  end
  if save ~= false then actions.saveBookmarks() end
end

-- set (or clear, with "") the name of the bookmark at file:lnum; keeps its number
function set_name(file, lnum, name)
  local data = require("bookmarks.config").config.cache.data
  local m = data[file] and data[file][tostring(lnum)]
  if not m then return end
  set_ann(file, lnum, build((parse(m.a)), name ~= "" and name or nil))
end

-- give number `slot` to the bookmark at file:lnum (it already has it: removes it). The bookmark of
-- the same project that had this number loses it.
function set_slot(file, lnum, slot)
  local data = require("bookmarks.config").config.cache.data
  local m = data[file] and data[file][tostring(lnum)]
  if not m then return end
  local cur, name = parse(m.a)
  if cur == slot then return set_ann(file, lnum, build(nil, name)) end
  local root = project_root()
  local others = {}
  for f, marks in pairs(data) do
    if in_root(f, root) then
      for l, o in pairs(marks) do
        if not (f == file and l == tostring(lnum)) and parse(o.a) == slot then table.insert(others, { f, l, o.a }) end
      end
    end
  end
  for _, o in ipairs(others) do
    set_ann(o[1], tonumber(o[2]), build(nil, select(2, parse(o[3]))), false)
  end
  set_ann(file, lnum, build(slot, name))
end

function ask_name(current, cb)
  vim.ui.input({ prompt = "Bookmark name (empty: no name)", default = current or "" }, function(answer)
    if answer ~= nil then cb(vim.trim(answer)) end
  end)
end

-- name (or rename) this line's bookmark; creates the bookmark when there is none
local function name_bookmark()
  local file = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0))
  if not file or vim.bo.buftype ~= "" then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local data = require("bookmarks.config").config.cache.data
  local m = data[file] and data[file][tostring(lnum)]
  ask_name(m and strip(m.a), function(name)
    if not (data[file] and data[file][tostring(lnum)]) then require("bookmarks").bookmark_toggle() end
    set_name(file, lnum, name)
  end)
end

-- this line's bookmark gets number `slot` (created when there is none)
local function slot_line(slot)
  local file = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0))
  if not file or vim.bo.buftype ~= "" then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local data = require("bookmarks.config").config.cache.data
  if not (data[file] and data[file][tostring(lnum)]) then require("bookmarks").bookmark_toggle() end
  set_slot(file, lnum, slot)
end

local function go_to(i)
  for _, b in ipairs(bookmarks(false)) do
    if b.slot == i then return open(b) end
  end
  vim.notify(("No bookmark number %d in this project: <Leader>m%d on a line, or %d in the list"):format(i, i, i), vim.log.levels.INFO)
end

---@type LazySpec
return {
  {
    "tomasky/bookmarks.nvim",
    commit = "ce804b50c7734e163bdfdca9a38b99d32a73bfe4", -- pinned: the list reads its storage
    event = "VeryLazy",
    opts = {
      save_file = vim.fn.stdpath("data") .. "/bookmarks.json",
      virt_text = true, -- the name at the end of the line
      keywords = { [PREFIX] = NAMED_ICON .. " ", ["@1"] = SLOT_ICONS[1] .. " ", ["@2"] = SLOT_ICONS[2] .. " ", ["@3"] = SLOT_ICONS[3] .. " ", ["@4"] = SLOT_ICONS[4] .. " " },
      signs = {
        add = { text = ICON },
        ann = { text = NAMED_ICON },
      },
    },
    config = function(_, opts)
      require("bookmarks").setup(opts)
      local function hl()
        vim.api.nvim_set_hl(0, "BookMarksAdd", { fg = "#71b7ff", default = false })
        vim.api.nvim_set_hl(0, "BookMarksAnn", { fg = "#e09b13", default = false })
      end
      hl()
      vim.api.nvim_create_autocmd("ColorScheme", { group = vim.api.nvim_create_augroup("bookmarks_colors", { clear = true }), callback = hl })
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      local n = opts.mappings.n
      local function bm(fn) return function() require("bookmarks")[fn]() end end
      n["<Leader>m"] = { desc = ICON .. " Bookmarks (lines)" }
      n["<Leader>ma"] = { bm("bookmark_toggle"), desc = "Bookmark this line (on / off)" }
      n["<Leader>mr"] = { name_bookmark, desc = "Name this line's bookmark" }
      n["<Leader>mm"] = { function() pick(false) end, desc = "Bookmarks of this project" }
      n["<Leader>mM"] = { function() pick(true) end, desc = "Bookmarks of all projects" }
      n["<Leader>mj"] = { bm("bookmark_next"), desc = "Next bookmark in this file" }
      n["<Leader>mk"] = { bm("bookmark_prev"), desc = "Previous bookmark in this file" }
      n["<Leader>mx"] = { bm("bookmark_clean"), desc = "Remove this file's bookmarks" }
      for i = 1, 4 do
        n["<Leader>" .. i] = { function() go_to(i) end, desc = "Go to bookmark number " .. i }
        n["<Leader>m" .. i] = { function() slot_line(i) end, desc = "This line's bookmark: number " .. i .. " (on / off)" }
      end
    end,
  },
}
