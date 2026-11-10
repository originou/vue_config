-- Projects with several named sessions each.
--
-- <Leader>fp (Snacks projects picker): saves the session we leave, changes to the picked project,
-- then lists its sessions: "default" (AstroNvim's dirsession of the folder, what <Leader>S. loads)
-- + named ones + "new" / "delete". <Leader>Sp shows the same list for the current folder,
-- <Leader>Sm the session manager (all projects: open, rename, delete). Start screen: p = <Leader>Sp,
-- a = <Leader>fp (project, then its sessions), m = <Leader>Sm.
-- Snacks' own "load_session" only knows persistence.nvim & co, not resession (AstroNvim's).
--
-- Named sessions: resession dir "project-sessions", name "<cwd>@@<session>". The active one is in
-- vim.g.project_session (nil = default); it is saved on exit instead of AstroNvim's dirsession
-- autosave (turned off below, it would overwrite "default" with a named session's buffers).
local DIR = "project-sessions"
local SEP = "@@"

-- resession stores "<name>.json" with / and : replaced by _; list() returns those escaped names
local function escape(s) return (s:gsub("/", "_"):gsub(":", "_")) end

local function named_sessions(cwd)
  local prefix = escape(cwd) .. SEP
  local ret = {}
  for _, name in ipairs(require("resession").list({ dir = DIR })) do
    if vim.startswith(name, prefix) then table.insert(ret, name:sub(#prefix + 1)) end
  end
  table.sort(ret)
  return ret
end

local function has_default(cwd)
  return vim.fn.filereadable(require("resession.util").get_session_file(cwd, "dirsession")) == 1
end

-- Buffers kept in sessions: AstroNvim's rule (listed, named, not nofile...) minus buffers that are
-- not files (gitsigns:// diffs, fugitive://, term://...): restored, they come back empty and broken
local function is_file_buf(bufnr)
  return require("astrocore.buffer").is_restorable(bufnr)
    and not vim.api.nvim_buf_get_name(bufnr):match("^%a[%w+.-]*://")
end

-- One Neovim per session: the instance that opens a session holds a lock (a file with its PID);
-- another instance can neither open nor save that session (two instances on one session: the last
-- one to quit overwrote the other's). A lock whose Neovim is gone is ignored.
local LOCKS = vim.fn.stdpath("state") .. "/session-locks"
-- name: as given to resession (default: the cwd, named: "<cwd>@@<session>"), escaped or not
local function lock_file(name, dir) return LOCKS .. "/" .. escape(dir .. "@" .. name) .. ".lock" end

local function lock_pid(name, dir)
  local f = io.open(lock_file(name, dir))
  if not f then return end
  local pid = tonumber(f:read("*l"))
  f:close()
  return pid
end

local function alive(pid)
  if vim.uv.kill(pid, 0) ~= 0 then return false end
  local f = io.open("/proc/" .. pid .. "/cmdline") -- Linux: check the PID is still a Neovim
  if not f then return true end
  local cmd = f:read("*a")
  f:close()
  return cmd:find("nvim", 1, true) ~= nil
end

-- PID of another running Neovim that has this session open, or nil
local function locked_by(name, dir)
  local pid = lock_pid(name, dir)
  if pid and pid ~= vim.fn.getpid() and alive(pid) then return pid end
end

local function warn_locked(label, pid)
  vim.notify(("Session %s is already open in another Neovim (PID %d)"):format(label, pid), vim.log.levels.WARN)
end

-- resession name and dir of the active session of the current folder
local function current()
  local cwd = vim.uv.cwd()
  if vim.g.project_session then return escape(cwd) .. SEP .. escape(vim.g.project_session), DIR end
  return cwd, "dirsession"
end

local function acquire(name, dir)
  vim.fn.mkdir(LOCKS, "p")
  vim.fn.writefile({ tostring(vim.fn.getpid()) }, lock_file(name, dir))
end

local function release()
  local name, dir = current()
  if lock_pid(name, dir) == vim.fn.getpid() then os.remove(lock_file(name, dir)) end
end

-- Save the active session of the current folder (default or named): not when it is open in
-- another Neovim, not after a failed load, not without any file
local function save_current()
  if vim.g.project_session_nosave then return end
  if not vim.iter(vim.api.nvim_list_bufs()):any(is_file_buf) then return end
  local name, dir = current()
  if locked_by(name, dir) then return end
  require("resession").save(name, { dir = dir, notify = false })
  require("session_repair").backup(name, dir, vim.uv.cwd()) -- a copy of it, when healthy
end

local function close_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and not vim.bo[buf].modified then pcall(vim.api.nvim_buf_delete, buf, {}) end
  end
end

-- Leave the active session: save it, free it. Until another session is loaded, nothing is saved
-- (the buffers would end up in the wrong session after a chdir).
local function leave()
  save_current()
  release()
  vim.g.project_session_nosave = true
end

-- Open a session (resession name and dir) of the folder cwd. Refused when another Neovim has it.
-- On a load error: say so and save nothing until the next load, so a half-loaded state never
-- overwrites a session.
local function switch(cwd, name, dir, session)
  local pid = locked_by(name, dir)
  if pid then
    warn_locked(vim.fn.fnamemodify(cwd, ":t") .. " / " .. (session or "default"), pid)
    return false
  end
  leave()
  vim.fn.chdir(cwd)
  -- check and repair the session file first (see session_repair.lua)
  local label = vim.fn.fnamemodify(cwd, ":t") .. " / " .. (session or "default")
  if not require("session_repair").prepare(name, dir, cwd, label) then
    -- nothing usable left: open it as a new, empty session
    close_buffers()
    vim.g.project_session = session
    vim.g.project_session_nosave = nil
    acquire(name, dir)
    Snacks.picker.files()
    return true
  end
  local ok, err = pcall(require("resession").load, name, { dir = dir })
  vim.g.project_session = session
  if ok then
    vim.g.project_session_nosave = nil
    acquire(name, dir)
  else
    vim.notify("Session not fully loaded, it will not be saved until the next load:\n" .. tostring(err), vim.log.levels.ERROR)
  end
  return ok
end

local function choose_session(cwd)
  local resession = require("resession")
  local named = named_sessions(cwd)
  if #named == 0 and not has_default(cwd) then
    -- start its default session: saved on exit (or with <Leader>SS), <Leader>Ss gives it a name
    vim.g.project_session = nil
    local pid = locked_by(cwd, "dirsession")
    if pid then return warn_locked(vim.fn.fnamemodify(cwd, ":t") .. " / default", pid) end
    vim.g.project_session_nosave = nil
    acquire(cwd, "dirsession")
    vim.notify("No session in " .. vim.fn.fnamemodify(cwd, ":~") .. " yet: new default session")
    Snacks.picker.files()
    return
  end

  local items = {}
  if has_default(cwd) then table.insert(items, { label = "default", load = function() return cwd, "dirsession" end }) end
  for _, s in ipairs(named) do
    table.insert(items, { label = s, name = s, load = function() return escape(cwd) .. SEP .. s, DIR end })
  end
  table.insert(items, { label = "+ new session", new = true })
  if #named > 0 then table.insert(items, { label = "✗ delete a session", delete = true }) end

  local project = vim.fn.fnamemodify(cwd, ":t")
  vim.ui.select(items, {
    prompt = "Sessions of " .. project,
    format_item = function(item) return item.label end,
  }, function(item)
    if not item then return end
    if item.new then
      vim.ui.input({ prompt = "New session name" }, function(name)
        name = name and vim.trim(name) or ""
        if name == "" then return end
        local pid = locked_by(escape(cwd) .. SEP .. escape(name), DIR)
        if pid then return warn_locked(project .. " / " .. name, pid) end
        leave()
        close_buffers()
        vim.g.project_session = name
        vim.g.project_session_nosave = nil
        acquire(current())
        vim.notify("Session " .. project .. " / " .. name)
        Snacks.picker.files()
      end)
    elseif item.delete then
      vim.ui.select(named, { prompt = "Delete session of " .. project }, function(s)
        if not s then return end
        local pid = locked_by(escape(cwd) .. SEP .. s, DIR)
        if pid then return warn_locked(project .. " / " .. s, pid) end
        resession.delete(escape(cwd) .. SEP .. s, { dir = DIR, notify = false })
        if vim.g.project_session == s then vim.g.project_session = nil end
        vim.notify("Session " .. s .. " deleted")
      end)
    else
      local name, dir = item.load()
      if switch(cwd, name, dir, item.name) then vim.notify("Session " .. project .. " / " .. item.label) end
    end
  end)
end

-- Session manager: every session of every project (default ones = dirsession, named ones), with a
-- preview of the folder and files of each. Enter opens it, Ctrl-e renames it (a renamed "default"
-- becomes a named session), Ctrl-x deletes it.
local function session_items()
  local resession = require("resession")
  local util = require("resession.util")
  local items = {}
  local function add(dir, name, session)
    local path = util.get_session_file(name, dir)
    local data = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
    local cwd = data and data.global and data.global.cwd
    if not cwd then return end
    -- the folder a session belongs to is in its name; the saved global cwd can differ (tabs with
    -- their own :tcd), so take the saved cwd (global or of a tab) that matches the name
    local prefix = dir == DIR and name:match("^(.+)" .. SEP) or name
    for _, c in ipairs(vim.list_extend({ cwd }, vim.tbl_map(function(t) return t.cwd end, data.tabs or {}))) do
      if c and escape(c) == prefix then
        cwd = c
        break
      end
    end
    local files = {}
    for _, buf in ipairs(data.buffers or {}) do
      if buf.name and buf.name ~= "" then
        local rel = vim.startswith(buf.name, cwd .. "/") and buf.name:sub(#cwd + 2) or vim.fn.fnamemodify(buf.name, ":~")
        table.insert(files, "- " .. rel)
      end
    end
    local project = vim.fn.fnamemodify(cwd, ":t")
    table.insert(items, {
      text = project .. " " .. (session or "default"),
      project = project,
      session = session,
      cwd = cwd,
      dir = dir,
      name = name,
      path = path,
      preview = {
        text = "# " .. project .. " / " .. (session or "default") .. "\n\n`" .. vim.fn.fnamemodify(cwd, ":~")
          .. "`\n\n" .. (#files > 0 and table.concat(files, "\n") or "(no file)"),
        ft = "markdown",
      },
    })
  end
  for _, name in ipairs(resession.list({ dir = "dirsession" })) do
    pcall(add, "dirsession", name, nil)
  end
  for _, name in ipairs(resession.list({ dir = DIR })) do
    local session = name:match(SEP .. "(.+)$")
    if session then pcall(add, DIR, name, session) end
  end
  table.sort(items, function(a, b)
    if a.project ~= b.project then return a.project < b.project end
    if not a.session or not b.session then return not a.session end -- default first
    return a.session < b.session
  end)
  return items
end

local function is_active(item)
  return vim.uv.cwd() == item.cwd and vim.g.project_session == item.session and not locked_by(item.name, item.dir)
end

local function session_manager()
  Snacks.picker({
    title = "Sessions  (Enter open · Ctrl-e rename · Ctrl-x delete)",
    finder = session_items,
    format = function(item)
      return {
        { item.project, "Directory" },
        { "  " .. (item.session or "default"), item.session and "String" or "Comment" },
        { is_active(item) and "  ● active" or "", "DiagnosticOk" },
        { locked_by(item.name, item.dir) and "  🔒 open in another Neovim" or "", "DiagnosticWarn" },
      }
    end,
    preview = "preview",
    confirm = function(picker, item)
      if not item then return end
      if is_active(item) then return picker:close() end
      local pid = locked_by(item.name, item.dir)
      if pid then return warn_locked(item.project .. " / " .. (item.session or "default"), pid) end
      picker:close()
      if switch(item.cwd, item.name, item.dir, item.session) then
        vim.notify("Session " .. item.project .. " / " .. (item.session or "default"))
      end
    end,
    actions = {
      session_rename = function(picker, item)
        if not item then return end
        local pid = locked_by(item.name, item.dir)
        if pid then return warn_locked(item.project .. " / " .. (item.session or "default"), pid) end
        vim.ui.input({ prompt = "Rename session", default = item.session or "" }, function(new)
          new = new and vim.trim(new) or ""
          if new == "" or new == "default" or new == item.session then return end
          local util = require("resession.util")
          local target = util.get_session_file(escape(item.cwd) .. SEP .. escape(new), DIR)
          if vim.fn.filereadable(target) == 1 then
            vim.notify("Session " .. new .. " already exists in " .. item.project, vim.log.levels.ERROR)
            return
          end
          vim.fn.mkdir(vim.fn.fnamemodify(target, ":h"), "p")
          local active = is_active(item)
          if active then release() end
          os.rename(item.path, target)
          if active then
            vim.g.project_session = new
            acquire(current())
          end
          picker.input:set("", "") -- the old query would no longer match anything
          picker:find()
        end)
      end,
      session_delete = function(picker, item)
        if not item then return end
        local label = item.project .. " / " .. (item.session or "default")
        local pid = locked_by(item.name, item.dir)
        if pid then return warn_locked(label, pid) end
        if vim.fn.confirm("Delete session " .. label .. "?", "&Yes\n&No", 2) ~= 1 then return end
        if is_active(item) then
          release()
          vim.g.project_session = nil
          vim.g.project_session_nosave = true -- the buffers would land in "default"
        end
        os.remove(item.path)
        picker.input:set("", "")
        picker:find()
      end,
    },
    win = {
      input = {
        keys = {
          ["<c-e>"] = { "session_rename", mode = { "n", "i" } },
          ["<c-x>"] = { "session_delete", mode = { "n", "i" } },
        },
      },
      list = { keys = { ["<c-e>"] = "session_rename", ["<c-x>"] = "session_delete" } },
    },
  })
end

local function open_project(picker, item)
  picker:close()
  if not item then return end
  leave() -- nothing saved until a session of the new project is opened or created
  vim.g.project_session = nil
  vim.fn.chdir(item.file)
  choose_session(vim.uv.cwd())
end

---@type LazySpec
return {
  {
    "stevearc/resession.nvim",
    -- also applies to AstroNvim's own saves ("Last Session", <Leader>S...)
    opts = function(_, opts) opts.buf_filter = is_file_buf end,
  },
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.projects = {
        -- every git repo under these folders is listed, not only the recently opened ones
        -- folders holding the projects (the missing ones are skipped)
        dev = vim.tbl_filter(
          function(d) return vim.fn.isdirectory(vim.fn.expand(d)) == 1 end,
          { "~/workspace", "~/workspace/projects", "~/projects", "~/dev", "~/git", "~/src", "~/code" }
        ),
        confirm = open_project,
      }
      -- start screen: the two session lists at the top
      local keys = vim.tbl_get(opts, "dashboard", "preset", "keys")
      if keys then
        local icon = require("astroui").get_icon("Session", 0, true)
        local pos = 1
        table.insert(keys, pos, { key = "m", action = "<Leader>Sm", icon = icon, desc = "Session Manager  " })
        table.insert(keys, pos, { key = "a", action = "<Leader>fp", icon = icon, desc = "All Sessions  " })
        table.insert(keys, pos, { key = "p", action = "<Leader>Sp", icon = icon, desc = "Sessions In This Folder  " })
      end
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      opts.sessions.autosave.cwd = false
      local function sessions_here()
        save_current()
        choose_session(vim.uv.cwd())
      end
      opts.mappings.n["<Leader>Sp"] = { sessions_here, desc = "Sessions of this project" }
      -- also used by the statusline (left click on project / session)
      opts.commands = opts.commands or {}
      opts.commands.ProjectSessions = { sessions_here, desc = "Sessions of this project" }
      opts.mappings.n["<Leader>Sm"] = { session_manager, desc = "Session manager (open, rename, delete)" }

      -- AstroNvim's own save / load / delete keys used other folders ("session": named sessions,
      -- "dirsession" without the lock): a session saved there never showed in the lists above.
      -- They now go through the project sessions.
      local function project_label(session) return vim.fn.fnamemodify(vim.uv.cwd(), ":t") .. " / " .. (session or "default") end
      -- <Leader>Ss: the current buffers become a named session of this project (the session left
      -- is saved first)
      opts.mappings.n["<Leader>Ss"] = {
        function()
          vim.ui.input({ prompt = "Save as session of " .. vim.fn.fnamemodify(vim.uv.cwd(), ":t"), default = vim.g.project_session or "" }, function(name)
            name = name and vim.trim(name) or ""
            if name == "" or name == "default" then return end
            if not vim.iter(vim.api.nvim_list_bufs()):any(is_file_buf) then
              return vim.notify("No file open: nothing to save", vim.log.levels.WARN)
            end
            local pid = locked_by(escape(vim.uv.cwd()) .. SEP .. escape(name), DIR)
            if pid then return warn_locked(project_label(name), pid) end
            save_current()
            release()
            vim.g.project_session = name
            vim.g.project_session_nosave = nil
            acquire(current())
            save_current()
            vim.notify("Session " .. project_label(name) .. " saved")
          end)
        end,
        desc = "Save as a named session of this project",
      }
      -- <Leader>SS: save the active session now (or start this folder's default one)
      opts.mappings.n["<Leader>SS"] = {
        function()
          if not vim.iter(vim.api.nvim_list_bufs()):any(is_file_buf) then
            return vim.notify("No file open: nothing to save", vim.log.levels.WARN)
          end
          if vim.g.project_session_nosave then
            local pid = locked_by(vim.uv.cwd(), "dirsession")
            if pid then return warn_locked(project_label(nil), pid) end
            vim.g.project_session = nil
            vim.g.project_session_nosave = nil
            acquire(current())
          end
          save_current()
          vim.notify("Session " .. project_label(vim.g.project_session) .. " saved")
        end,
        desc = "Save this session now",
      }
      opts.mappings.n["<Leader>Sf"] = { session_manager, desc = "Session manager (open, rename, delete)" }
      opts.mappings.n["<Leader>Sd"] = { session_manager, desc = "Session manager (open, rename, delete)" }
      opts.mappings.n["<Leader>SF"] = false
      opts.mappings.n["<Leader>SD"] = false
      opts.mappings.n["<Leader>St"] = false
      -- AstroNvim's "load this folder's session", through the lock
      opts.mappings.n["<Leader>S."] = {
        function()
          local cwd = vim.uv.cwd()
          if switch(cwd, cwd, "dirsession", nil) then vim.notify("Session " .. vim.fn.fnamemodify(cwd, ":t") .. " / default") end
        end,
        desc = "Load current dirsession",
      }
      -- "Last Session" (<Leader>Sl, start screen "s"): the project session that was active when the
      -- last Neovim quit, opened through the lock. AstroNvim's own "Last Session" was a snapshot
      -- loaded without it, so the same session could end up open twice.
      local last_file = vim.fn.stdpath("state") .. "/last-project-session.json"
      opts.mappings.n["<Leader>Sl"] = {
        function()
          local ok, last = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(last_file), "\n")) end)
          if not ok or type(last) ~= "table" then return vim.notify("No last session yet", vim.log.levels.WARN) end
          if switch(last.cwd, last.name, last.dir, last.session) then
            vim.notify("Session " .. vim.fn.fnamemodify(last.cwd, ":t") .. " / " .. (last.session or "default"))
          end
        end,
        desc = "Load last session",
      }
      opts.autocmds.project_session_autosave = {
        {
          event = "VimLeavePre",
          desc = "Save and free the active project session, remember it as the last one",
          callback = function()
            save_current()
            local name, dir = current()
            local saved = vim.fn.filereadable(require("resession.util").get_session_file(name, dir)) == 1
            if not vim.g.project_session_nosave and not locked_by(name, dir) and saved then
              local last = { cwd = vim.uv.cwd(), name = name, dir = dir, session = vim.g.project_session }
              vim.fn.writefile({ vim.json.encode(last) }, last_file)
            end
            release()
          end,
        },
      }
    end,
  },
}
