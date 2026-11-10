-- Same as the main Neovim config (dotfiles/nvim/lua/core/mappings.lua): ;j = Esc,
-- and leave terminal mode with ;j or C-x (Claude Code, toggleterm...)
---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@param opts AstroCoreOpts
  opts = function(_, opts)
    for _, mode in ipairs({ "n", "i", "v" }) do
      opts.mappings[mode] = opts.mappings[mode] or {}
      opts.mappings[mode][";j"] = { "<Esc>", desc = "Escape" }
    end
    opts.mappings.t = opts.mappings.t or {}
    opts.mappings.t[";j"] = { "<C-\\><C-n>", desc = "Leave terminal mode" }
    opts.mappings.t["<C-x>"] = { "<C-\\><C-n>", desc = "Leave terminal mode" }
    -- no macro recording: q does nothing in normal and visual mode. Buffer-local q mappings
    -- (close help, quickfix, pickers...) take precedence and still work.
    opts.mappings.n.q = { "<Nop>", desc = "which_key_ignore" }
    opts.mappings.x = opts.mappings.x or {}
    opts.mappings.x.q = { "<Nop>", desc = "which_key_ignore" }

    -- <Leader>bl: list of the open buffers (last used first, preview; Enter goes to it, Ctrl-x or dd
    -- closes it). "Close the buffers on the left" moves from <Leader>bl to <Leader>bh.
    opts.mappings.n["<Leader>bl"] = { function() require("snacks").picker.buffers() end, desc = "List of the open buffers" }
    opts.mappings.n["<Leader>bh"] = { function() require("astrocore.buffer").close_left() end, desc = "Close the buffers on the left" }

    -- :q and <Leader>q on the last editing window of the tab page close the file, not the window:
    -- the window was closed, the tree was left alone, closed itself (Neo-tree close_if_last_window)
    -- and Neovim quit. Other windows (splits, help, tree...): closed as usual. Last file of the
    -- tab page: closes the tab page, or quits Neovim when it is the last one. :q! / :qa unchanged.
    opts.commands = opts.commands or {}
    opts.commands.SmartQuit = {
      function()
        local cur = vim.api.nvim_get_current_win()
        local others = vim.tbl_filter(function(win)
          if win == cur or vim.api.nvim_win_get_config(win).relative ~= "" then return false end
          return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
        end, vim.api.nvim_tabpage_list_wins(0))
        if #others > 0 or vim.bo.buftype ~= "" then return vim.cmd("confirm quit") end
        require("astrocore.buffer").close() -- the last file: home screen, see below
      end,
      desc = "Close the window, or the file on the last editing window",
    }
    vim.cmd([[cnoreabbrev <expr> q (getcmdtype() ==# ':' && getcmdline() ==# 'q') ? 'SmartQuit' : 'q']])
    opts.mappings.n["<Leader>q"] = { "<Cmd>SmartQuit<CR>", desc = "Close the window (the file on the last one)" }

    -- Closing the last file (<Leader>c, tab close button, :q, <Leader>q) shows the home screen
    -- instead of closing the window (and Neovim with it). Only with a single tab page: with several,
    -- the tab page closes as before. Patches astrocore.buffer.close.
    local buffer = require("astrocore.buffer")
    local close = buffer.close
    buffer.close = function(bufnr, force)
      if not bufnr or bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
      local others = vim.tbl_filter(function(b) return b ~= bufnr end, vim.t.bufs or {})
      local last = #others == 0
        and #vim.api.nvim_list_tabpages() == 1
        and vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].buflisted
        and vim.bo[bufnr].buftype == ""
      if not last then return close(bufnr, force) end
      if not force and vim.bo[bufnr].modified then
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
        local choice = vim.fn.confirm(("Save changes to %s?"):format(name ~= "" and name or "this file"), "&Yes\n&No\n&Cancel", 3)
        if choice == 1 then
          vim.api.nvim_buf_call(bufnr, function() vim.cmd("write") end)
        elseif choice ~= 2 then
          return
        end
      end
      local wins = vim.fn.win_findbuf(bufnr)
      if #wins > 0 then vim.api.nvim_set_current_win(wins[1]) end
      -- in this window (not as a float): an empty buffer, the dashboard in it
      vim.cmd("enew")
      require("snacks").dashboard({ win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf() })
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end

    -- <Leader>Q: asks before quitting Neovim
    opts.mappings.n["<Leader>Q"] = {
      function()
        vim.ui.select({ "Quit", "Cancel" }, { prompt = "Quit Neovim?" }, function(choice)
          if choice == "Quit" then vim.cmd("confirm qall") end
        end)
      end,
      desc = "Quit Neovim (asks first)",
    }
  end,
}
