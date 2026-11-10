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
        status.component.git_branch({ padding = { left = 1, right = 1 }, surround = { separator = "pl_left" } }),
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
