-- OpenCode next to the code, like Claude Code (claudecode.lua): opencode in a terminal split on
-- the right, prompts with editor context (@this = selection or cursor, @buffer, @diagnostics...).
-- Its edits reload in the buffers. <leader>o = OpenCode

-- One opencode terminal, kept alive when hidden: <leader>oo shows / hides it, like <leader>ac
local term = { buf = nil, win = nil }

local function is_open()
  return term.win ~= nil and vim.api.nvim_win_is_valid(term.win)
end

local function is_running()
  return term.buf ~= nil and vim.api.nvim_buf_is_valid(term.buf)
end

-- Shows the terminal on the right (40 %), starting opencode the first time; the focus stays
-- where it was unless focus is set
local function show(focus)
  if is_open() then
    if focus then vim.api.nvim_set_current_win(term.win) end
    return
  end
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("botright vsplit")
  term.win = vim.api.nvim_get_current_win()
  vim.cmd("vertical resize " .. math.floor(vim.o.columns * 0.4))
  if is_running() then
    vim.api.nvim_win_set_buf(term.win, term.buf)
  else
    vim.cmd("terminal opencode --port")
    term.buf = vim.api.nvim_get_current_buf()
    vim.bo[term.buf].buflisted = false
    -- opencode quit: forget the buffer, the next toggle starts a new one
    vim.api.nvim_create_autocmd("TermClose", {
      buffer = term.buf,
      once = true,
      callback = function()
        term.buf = nil
        vim.schedule(function()
          if is_open() then vim.api.nvim_win_close(term.win, true) end
        end)
      end,
    })
  end
  if focus then
    vim.cmd("startinsert")
  else
    vim.api.nvim_set_current_win(prev)
  end
end

local function toggle()
  if is_open() then
    vim.api.nvim_win_hide(term.win) -- the buffer (and opencode) keeps running
    term.win = nil
  else
    show(true)
  end
end

return {
  "nickjvandyke/opencode.nvim",
  version = "*", -- latest release: OpenCode v1 (main branch = OpenCode v2)
  keys = {
    { "<leader>oo", toggle, desc = "OpenCode: toggle (terminal on the right)" },
    { "<leader>oa", function() require("opencode").ask("@this: ") end, mode = { "n", "x" }, desc = "OpenCode: ask about this (selection / cursor)" },
    { "<leader>ob", function() require("opencode").ask("@buffer: ") end, desc = "OpenCode: ask about the buffer" },
    { "<leader>od", function() require("opencode").ask("@diagnostics: ") end, desc = "OpenCode: ask about the diagnostics" },
    { "<leader>os", function() require("opencode").select() end, mode = { "n", "x" }, desc = "OpenCode: prompts, commands, servers" },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- A prompt with no opencode running: the same terminal, shown without taking the focus
      server = { start = function() show(false) end },
    }
  end,
}
