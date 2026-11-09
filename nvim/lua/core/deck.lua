-- Stream deck (OpenDeck) Neovim profile. OpenDeck switches profiles on the focused window's X
-- class only (applications.json), and nvim runs inside Alacritty (+ tmux): while nvim has the
-- focus, its terminal window gets the X class "nvim" (applications.json: nvim -> Neovim), and its
-- own class (Alacritty, AlacrittyPopup...) back when nvim loses the focus, is suspended or exits.
-- Needs X11, xdotool and the terminal's focus events (tmux: focus-events on).
if vim.fn.executable("xdotool") == 0 or (vim.env.DISPLAY or "") == "" or (vim.env.WAYLAND_DISPLAY or "") ~= "" then
  return
end

local api = vim.api
local CLASS = "nvim"
local FALLBACK = "Alacritty" -- if the window already says "nvim" (another nvim of the same window)
local win, original           -- X window taken and its class before

local function restore(sync)
  if not win then return end
  local cmd = { "xdotool", "set_window", "--class", original, win }
  if sync then vim.fn.system(cmd) else vim.fn.jobstart(cmd) end
  win, original = nil, nil
end

local function take()
  -- Focus events come from the focused window: the active one is this nvim's terminal
  vim.fn.jobstart({ "sh", "-c", 'w=$(xdotool getactivewindow) && echo "$w $(xdotool getwindowclassname "$w")"' }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local id, class = (data[1] or ""):match("^(%d+) (%S+)$")
      if not id then return end
      win, original = id, (class ~= CLASS and class or FALLBACK)
      vim.fn.jobstart({ "xdotool", "set_window", "--class", CLASS, id })
    end,
  })
end

local group = api.nvim_create_augroup("DeckFocus", { clear = true })
-- Moving between two nvim tmux panes of one window: the other one's FocusLost restores first
api.nvim_create_autocmd({ "VimEnter", "FocusGained", "VimResume" }, {
  group = group,
  callback = function() vim.defer_fn(take, 100) end,
})
api.nvim_create_autocmd({ "FocusLost", "VimSuspend" }, { group = group, callback = function() restore(false) end })
api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function() restore(true) end })
