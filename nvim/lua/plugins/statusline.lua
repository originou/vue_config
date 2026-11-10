-- LazyVim (lualine) look for AstroNvim's statusline, same components as AstroNvim's default:
-- mode name in a colored block, powerline arrows, branch and position on the lualine theme's
-- "b" color, clock in the mode color on the right

-- Tabline (1st line) and winbar (2nd line, breadcrumbs) on a background slightly lighter than the
-- code, so they stand out from it
-- git root of a folder, cached (a buffer's root does not change while it is open)
local roots = {}
local function git_root(dir)
  if roots[dir] == nil then roots[dir] = vim.fs.root(dir, ".git") or false end
  return roots[dir] or nil
end

-- Statusline path of a buffer: relative to the root of its git repository, else to the current
-- folder, else from ~. Special buffers (Neo-tree, terminal, help, gitsigns://…) keep their name.
-- Long paths: folders shortened to their first letter, but the last one.
local function statusline_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or vim.bo[bufnr].buftype ~= "" or name:match("^%a[%w+.-]*://") then return vim.fn.fnamemodify(name, ":t") end
  local root = git_root(vim.fs.dirname(name))
  local rel
  if root and vim.startswith(name, root .. "/") then
    rel = name:sub(#root + 2)
  else
    rel = vim.fn.fnamemodify(name, ":~:.")
  end
  if #rel > math.floor(vim.o.columns * 0.35) then
    local dir, file = vim.fs.dirname(rel), vim.fs.basename(rel)
    if dir ~= "." then
      local parent, last = vim.fs.dirname(dir), vim.fs.basename(dir)
      rel = (parent ~= "." and vim.fn.pathshorten(parent) .. "/" or "") .. last .. "/" .. file
    end
  end
  return rel
end

-- Repository state for the statusline: branch, whether there are changes, and the lines added (+)
-- / removed (-) over the whole repository (`git diff --numstat HEAD`, plus the lines of the
-- untracked files). Runs in the background, cached per repository; refreshed on save, buffer /
-- focus change, after a terminal (lazygit) and every 10 s.
local repos = {} -- root -> { branch, dirty, added, removed, running, at }

local function repo_root()
  local name = vim.api.nvim_buf_get_name(0)
  local dir = (name ~= "" and vim.bo.buftype == "" and not name:match("^%a[%w+.-]*://")) and vim.fs.dirname(name) or vim.uv.cwd()
  return dir and git_root(dir)
end

-- lines of a text file (untracked files: at most 1 MB each, binary files ignored)
local function count_lines(path)
  local f = io.open(path, "rb")
  if not f then return 0 end
  local data = f:read(1024 * 1024) or ""
  f:close()
  if data:find("\0", 1, true) then return 0 end
  local _, n = data:gsub("\n", "")
  if #data > 0 and data:sub(-1) ~= "\n" then n = n + 1 end
  return n
end

local function refresh_repo(root)
  if not root then return end
  local r = repos[root] or {}
  repos[root] = r
  if r.running or (r.at and vim.uv.now() - r.at < 1000) then return end
  r.running = true
  vim.system({ "git", "-C", root, "status", "--porcelain=v1", "--branch", "--untracked-files=all" }, { text = true }, function(st)
    if st.code ~= 0 then r.running = false; return end
    local branch, dirty, untracked = nil, false, {}
    for line in (st.stdout or ""):gmatch("[^\n]+") do
      if line:sub(1, 2) == "##" then
        local head = line:sub(4)
        branch = head:match("^No commits yet on (.+)$") or head:match("^(.-)%.%.%.") or head:match("^(%S+)")
        if head:match("^HEAD %(no branch%)") then branch = "detached" end
      else
        dirty = true
        if line:sub(1, 2) == "??" and #untracked < 500 then table.insert(untracked, (line:sub(4):gsub('^"(.*)"$', "%1"))) end
      end
    end
    vim.system({ "git", "-C", root, "diff", "--numstat", "HEAD" }, { text = true }, function(df)
      local added, removed = 0, 0
      if df.code == 0 then
        for a, d in (df.stdout or ""):gmatch("(%S+)\t(%S+)\t[^\n]*") do
          added, removed = added + (tonumber(a) or 0), removed + (tonumber(d) or 0)
        end
      end
      for _, path in ipairs(untracked) do
        added = added + count_lines(root .. "/" .. path)
      end
      r.branch, r.dirty, r.added, r.removed = branch, dirty, added, removed
      r.running, r.at = false, vim.uv.now()
      vim.schedule(function() vim.cmd.redrawstatus() end)
    end)
  end)
end

local function repo_state()
  local root = repo_root()
  if not root then return end
  local r = repos[root]
  if not r then refresh_repo(root) end
  return r and r.branch and r or nil
end

local function dirty(r) return r.dirty end

-- dark text on the green / yellow background: the editor background
local function dark_fg() return string.format("#%06x", vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg or 0) end

vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "FocusGained", "TermClose", "TermLeave", "DirChanged" }, {
  group = vim.api.nvim_create_augroup("statusline_git", { clear = true }),
  callback = function() refresh_repo(repo_root()) end,
})
vim.api.nvim_create_autocmd("User", {
  group = "statusline_git",
  pattern = { "GitSignsUpdate", "GitSignsChanged" },
  callback = function() refresh_repo(repo_root()) end,
})
local git_timer = vim.uv.new_timer()
if git_timer then git_timer:start(10000, 10000, vim.schedule_wrap(function() refresh_repo(repo_root()) end)) end

local function bar_bg(amount)
  local color = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg or 0
  local function up(c) return math.floor(c + (255 - c) * amount) end
  local r, g, b = math.floor(color / 65536) % 256, math.floor(color / 256) % 256, color % 256
  return string.format("#%02x%02x%02x", up(r), up(g), up(b))
end

---@type LazySpec
return {
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = {
      -- set on the highlight groups themselves (applied with the colorscheme, before AstroNvim
      -- computes its statusline colors from them)
      highlights = {
        init = function()
          local ret = {}
          for _, group in ipairs({ "WinBar", "WinBarNC", "TabLineFill" }) do
            ret[group] = vim.api.nvim_get_hl(0, { name = group, link = false })
            ret[group].bg = bar_bg(0.07)
          end
          return ret
        end,
      },
      status = {
        -- file icon in its own color on visible tabs, but not on the current one: a green icon
        -- would vanish on the neon background
        icon_highlights = {
          file_icon = { tabline = function(self) return self.is_visible and not self.is_active end },
        },
        separators = {
          pl_left = { "", "" },
          pl_right = { "", "" },
        },
        colors = function(colors)
          local ok, theme = pcall(require, "lualine.themes." .. (vim.g.colors_name or ""))
          local normal = ok and type(theme) == "table" and theme.normal
          if normal and normal.a and normal.b and normal.c then
            colors.mode_fg = normal.a.fg
            colors.git_branch_bg, colors.git_branch_fg = normal.b.bg, normal.b.fg
            colors.nav_bg, colors.nav_fg = normal.b.bg, normal.b.fg
            colors.bg, colors.fg = normal.c.bg, normal.c.fg
            colors.section_bg, colors.section_fg = normal.c.bg, normal.c.fg
            -- sections already resolved from the old section color by AstroNvim
            for _, s in ipairs({ "file_info", "git_diff", "diagnostics", "lsp", "macro_recording", "cmd_info", "treesitter", "virtual_env" }) do
              colors[s .. "_bg"] = normal.c.bg
            end
          end

          -- current buffer tab (and current tab page, right of the tabline): neon green, dark text
          local neon = "#39ff14"
          local dark = string.format("#%06x", vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg or 0)
          colors.buffer_active_bg, colors.tab_active_bg = neon, neon
          colors.buffer_active_fg, colors.buffer_active_path_fg, colors.buffer_active_close_fg = dark, dark, dark
          colors.tab_active_fg = dark

          -- tabline (1st line) and winbar (2nd line): see bar_bg() at the top
          local bar = bar_bg(0.07)
          for _, key in ipairs({ "winbar_bg", "winbarnc_bg", "tabline_bg", "buffer_bg", "buffer_overflow_bg", "tab_close_bg" }) do
            colors[key] = bar
          end
          colors.buffer_visible_bg = bar_bg(0.12)
          return colors
        end,
      },
    },
  },
  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      local status = require("astroui.status")
      opts.statusline = {
        hl = { fg = "fg", bg = "bg" },
        status.component.mode({
          mode_text = { padding = { left = 1, right = 1 } },
          hl = { bold = true },
          surround = { separator = "pl_left" },
        }),
        -- git: branch on a green background when the repository is clean, git yellow with changes,
        -- then the lines added (+) / removed (-) over the repository. Left click: lazygit
        status.component.builder({
          {
            provider = function()
              local r = repo_state()
              return r and (require("astroui").get_icon("GitBranch", 1, true) .. r.branch)
            end,
            hl = function() return { fg = dark_fg(), bold = true } end,
          },
          on_click = {
            name = "heirline_git_repo",
            callback = function() vim.schedule(function() require("snacks").lazygit() end) end,
          },
          padding = { left = 1, right = 1 },
          surround = {
            separator = "pl_left",
            color = function()
              local r = repo_state()
              return (r and dirty(r)) and "git_changed" or "git_added"
            end,
            condition = function() return repo_state() ~= nil end,
          },
        }),
        -- lines added / removed over the repository, next to the branch: dark text on a green (+) /
        -- red (-) background, shown when not 0
        status.component.builder({
          { provider = function() return "+" .. repo_state().added end, hl = function() return { fg = dark_fg(), bold = true } end },
          padding = { left = 1, right = 1 },
          surround = {
            separator = "pl_left",
            color = "git_added",
            condition = function()
              local r = repo_state()
              return r and dirty(r) and r.added > 0
            end,
          },
        }),
        status.component.builder({
          { provider = function() return "-" .. repo_state().removed end, hl = function() return { fg = dark_fg(), bold = true } end },
          padding = { left = 1, right = 1 },
          surround = {
            separator = "pl_left",
            color = "git_removed",
            condition = function()
              local r = repo_state()
              return r and dirty(r) and r.removed > 0
            end,
          },
        }),
        -- file path relative to its git repository root (else to the current folder, else ~/…)
        status.component.file_info({ filename = { fname = statusline_path, modify = "" }, filetype = false }),
        status.component.git_diff(),
        status.component.diagnostics(),
        status.component.fill(),
        status.component.cmd_info(),
        status.component.fill(),
        status.component.lsp(),
        status.component.virtual_env(),
        status.component.treesitter(),
        -- project (current folder) › active session (see plugins/projects.lua), as a rounded pill;
        -- left click: list the sessions of this project to switch
        { provider = " " },
        status.utils.surround({ "", "" }, "git_branch_bg", {
          on_click = {
            name = "heirline_project_session",
            callback = function(_, _, _, button)
              if button == "l" then vim.schedule(function() vim.cmd("ProjectSessions") end) end
            end,
          },
          {
            provider = function() return require("astroui").get_icon("Session", 1, true) end,
            hl = { fg = "normal" },
          },
          {
            provider = function() return vim.fn.fnamemodify(vim.fn.getcwd(), ":t") end,
            hl = { fg = "normal", bold = true },
          },
          { provider = "  ", hl = { fg = "buffer_fg" } },
          {
            provider = function() return vim.g.project_session or "default" end,
            hl = { fg = "git_added", italic = true },
          },
        }),
        { provider = " " },
        status.component.nav({ padding = { left = 1, right = 1 }, surround = { separator = "pl_right" } }),
        status.component.builder({
          { provider = function() return " " .. os.date("%R") end, hl = { fg = "mode_fg", bold = true } },
          padding = { left = 1, right = 1 },
          surround = { separator = "pl_right", color = status.hl.mode_bg },
        }),
      }
    end,
  },
}
