-- Self-repair of resession sessions (used by plugins/projects.lua).
--
-- Before a session is opened, its file is checked and fixed:
--   - buffers that are not files (gitsigns://, fugitive://…) or whose file no longer exists: removed
--   - windows showing removed buffers: removed; a tab page left without a file window (saved while
--     only Neo-tree, a terminal… was shown: "wins": false) gets one window on its first file
--   - global working folder other than the project's: set to the project's
-- When no file is left, or only files of other folders (a session polluted by another project), the
-- newest healthy backup is restored instead. Backups: after each save, a copy of the file is kept
-- (when healthy and different from the last backup), KEEP per session, in BACKUPS. A repaired or
-- replaced file is kept there too, tagged "broken".
local M = {}

M.BACKUPS = vim.fn.stdpath("data") .. "/session-backups"
M.KEEP = 5

local function escape(s) return (s:gsub("/", "_"):gsub(":", "_")) end

local function read(path)
  if vim.fn.filereadable(path) == 0 then return end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"), { luanil = { object = true, array = true } })
  return ok and type(data) == "table" and data or nil
end

local function write(path, data) vim.fn.writefile({ vim.json.encode(data) }, path) end

local function is_file(name)
  if type(name) ~= "string" or name == "" or name:match("^%a[%w+.-]*://") then return false end
  local stat = vim.uv.fs_stat(name)
  return stat ~= nil and stat.type == "file"
end

local function count_leaves(layout)
  if type(layout) ~= "table" then return 0 end
  if layout[1] == "leaf" then return 1 end
  local n = 0
  for _, child in ipairs(layout[2] or {}) do
    n = n + count_leaves(child)
  end
  return n
end

-- Fixed copy of a session's data, the list of fixes, and whether it holds no file of `folder`.
-- nil when no file is left.
function M.sanitize(data, folder)
  data = vim.deepcopy(data)
  local fixes = {}
  local names, kept = {}, {}
  for _, buf in ipairs(data.buffers or {}) do
    if is_file(buf.name) then
      table.insert(kept, buf)
      names[buf.name] = buf
    end
  end
  local dropped = #(data.buffers or {}) - #kept
  if dropped > 0 then table.insert(fixes, dropped .. " buffer(s) that are not files or no longer exist removed") end
  data.buffers = kept
  if #kept == 0 then return nil, fixes end

  local foreign = folder ~= nil
  for _, buf in ipairs(kept) do
    if folder and vim.startswith(buf.name, folder .. "/") then foreign = false end
  end

  data.global = data.global or {}
  if folder and not data.tab_scoped and data.global.cwd ~= folder then
    table.insert(fixes, ("working folder %s → %s"):format(vim.fn.fnamemodify(data.global.cwd or "?", ":~"), vim.fn.fnamemodify(folder, ":~")))
    data.global.cwd = folder
  end

  -- windows
  local astro = data.astrocore or {}
  local name_of = {}
  for name, nr in pairs(astro.bufnrs or {}) do
    name_of[nr] = name
  end
  local function prune(layout)
    if type(layout) ~= "table" then return false end
    if layout[1] == "leaf" then
      local win = layout[2]
      return type(win) == "table" and (win.extension or names[win.bufname]) and layout or false
    end
    local items = {}
    for _, child in ipairs(layout[2] or {}) do
      local c = prune(child)
      if c then table.insert(items, c) end
    end
    if #items == 0 then return false end
    if #items == 1 then return items[1] end
    layout[2] = items
    return layout
  end
  local function has_file(layout)
    if layout[1] == "leaf" then return names[layout[2].bufname] ~= nil end
    for _, child in ipairs(layout[2]) do
      if has_file(child) then return true end
    end
    return false
  end
  local removed, rebuilt = 0, 0
  for i, tab in ipairs(data.tabs or {}) do
    if folder and tab.cwd == folder then tab.cwd = nil end -- same as the global one now
    local before = count_leaves(tab.wins)
    local wins = prune(tab.wins)
    removed = removed + before - count_leaves(wins)
    if not wins or not has_file(wins) then
      -- one window on the tab's first file (AstroNvim's buffer list of the tab), else the first file
      local name
      for _, nr in ipairs((astro.tabs or {})[i] or {}) do
        if name_of[nr] and names[name_of[nr]] then
          name = name_of[nr]
          break
        end
      end
      name = name or kept[1].name
      wins = {
        "leaf",
        {
          bufname = name,
          current = true,
          cursor = names[name].last_pos or { 1, 0 },
          width = data.global.width or 80,
          height = (data.global.height or 24) - 2,
          options = {},
        },
      }
      rebuilt = rebuilt + 1
    end
    tab.wins = wins
  end
  if removed > 0 then table.insert(fixes, removed .. " window(s) without a file removed") end
  if rebuilt > 0 then table.insert(fixes, "window layout rebuilt in " .. rebuilt .. " tab page(s)") end

  -- AstroNvim's tab buffer lists
  if astro.bufnrs then
    local keep = {}
    for name, nr in pairs(vim.deepcopy(astro.bufnrs)) do
      if names[name] then
        keep[nr] = true
      else
        astro.bufnrs[name] = nil
      end
    end
    for i, list in ipairs(astro.tabs or {}) do
      astro.tabs[i] = vim.tbl_filter(function(nr) return keep[nr] end, list)
    end
    if astro.current_buf and not keep[astro.current_buf] then astro.current_buf = nil end
    if astro.last_buf and not keep[astro.last_buf] then astro.last_buf = nil end
  end

  return data, fixes, foreign
end

local function base(name, dir) return escape(dir .. "@" .. name) end

-- backup files of a session, newest first; tag: nil = healthy ones, "broken"
local function backups(name, dir, tag)
  local prefix, ret = base(name, dir) .. ".", {}
  vim.fn.mkdir(M.BACKUPS, "p")
  for fname in vim.fs.dir(M.BACKUPS) do
    local stamp, rest = fname:sub(#prefix + 1):match("^(%d+%-%d+)(.*)%.json$")
    if vim.startswith(fname, prefix) and stamp and rest == (tag and ("." .. tag) or "") then
      table.insert(ret, { path = M.BACKUPS .. "/" .. fname, stamp = stamp })
    end
  end
  table.sort(ret, function(a, b) return a.stamp > b.stamp end)
  return ret
end

local function keep_copy(path, name, dir, tag)
  vim.fn.mkdir(M.BACKUPS, "p")
  local target = ("%s/%s.%s%s.json"):format(M.BACKUPS, base(name, dir), os.date("%Y%m%d-%H%M%S"), tag and ("." .. tag) or "")
  vim.uv.fs_copyfile(path, target)
  for i, old in ipairs(backups(name, dir, tag)) do
    if i > (tag and 3 or M.KEEP) then os.remove(old.path) end
  end
end

-- After a save: keep a copy of the file when it is healthy and differs from the last backup
function M.backup(name, dir, folder)
  local path = require("resession.util").get_session_file(name, dir)
  local data = read(path)
  if not data then return end
  local fixed, _, foreign = M.sanitize(data, folder)
  if not fixed or foreign then return end
  local last = backups(name, dir)[1]
  if last and table.concat(vim.fn.readfile(last.path), "\n") == table.concat(vim.fn.readfile(path), "\n") then return end
  keep_copy(path, name, dir)
end

local function newest_healthy(name, dir, folder)
  for _, b in ipairs(backups(name, dir)) do
    local data = read(b.path)
    local fixed, foreign
    if data then
      fixed, _, foreign = M.sanitize(data, folder)
    end
    if fixed and not foreign then
      local y, mo, d, h, mi = b.stamp:match("^(%d%d%d%d)(%d%d)(%d%d)%-(%d%d)(%d%d)")
      return fixed, ("%s/%s %s:%s"):format(d, mo, h, mi)
    end
  end
end

-- Check and fix a session before it is loaded. false: nothing usable (no file, no backup).
function M.prepare(name, dir, folder, label)
  local util = require("resession.util")
  local path = util.get_session_file(name, dir)
  local data = read(path)
  if not data then return vim.fn.filereadable(path) == 0 end -- missing: resession says so
  local fixed, fixes, foreign = M.sanitize(data, folder)
  local restored, when
  if not fixed or foreign then restored, when = newest_healthy(name, dir, folder) end
  if fixed and #fixes == 0 and not restored then return true end -- healthy (or foreign, no backup)

  keep_copy(path, name, dir, "broken")
  if restored then
    write(path, restored)
    local why = fixed and "it only held files of other folders" or "no file was left in it"
    vim.notify(("Session %s repaired: %s, restored its backup of %s"):format(label, why, when), vim.log.levels.WARN)
    return true
  end
  if not fixed then
    vim.notify(("Session %s had no usable file and no backup: it starts empty"):format(label), vim.log.levels.WARN)
    return false
  end
  write(path, fixed)
  vim.notify(("Session %s repaired:\n- %s"):format(label, table.concat(fixes, "\n- ")), vim.log.levels.WARN)
  return true
end

return M
