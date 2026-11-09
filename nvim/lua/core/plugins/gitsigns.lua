local M = {
  "lewis6991/gitsigns.nvim",
  event = "BufReadPre",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local function mappings()
      local wk = require("which-key")
      local default_options = { silent = true }
      local gs = package.loaded.gitsigns
      local map = require("core.utils.functions").map

      wk.add({
        { "<leader>g",       group = "Git" },
        { "<leader>gM",      desc = "Hydra move" },
        { "<leader>g<Enter>","<cmd>lua require('neogit').open()<cr>", desc = "Neogit" },
        { "<leader>gh",      "<cmd>Telescope git_branches<cr>",       desc = "Branches" },
        { "<leader>gc",      "<cmd>G commit %<cr>",                   desc = "Commit buffer" },
        { "<leader>gP",      "<cmd>G push<cr>",                       desc = "Push" },
        { "<leader>gg",      "<cmd>Telescope git_status<cr>",         desc = "Status" },
        { "<leader>gm",      "<cmd>Telescope git_commits<cr>",        desc = "Commits" },
        { "<leader>gS",      gs.stage_buffer,                         desc = "Stage buffer" },
        { "<leader>gu",      gs.undo_stage_hunk,                      desc = "Undo stage hunk" },
        { "<leader>gr",      group = "Reset" },
        { "<leader>grR",     gs.reset_buffer,                         desc = "Reset buffer" },
        { "<leader>gp",      gs.preview_hunk,                         desc = "Preview hunk" },
        { "<leader>gB",      function() gs.blame_line({ full = true }) end, desc = "Blame full" },
        { "<leader>gb",      gs.toggle_current_line_blame,            desc = "Blame line" },
        { "<leader>gD",      gs.diffthis,                             desc = "Diff" },
        { "<leader>gd",      gs.toggle_deleted,                       desc = "Show deleted" },
      })

      -- TODO: with german qwertz this bindings are awful
      map("n", "]c", function()
        if vim.wo.diff then
          return "]c"
        end
        vim.schedule(function()
          gs.next_hunk()
        end)
        return "<Ignore>"
      end, { desc = "Next hunk", expr = true })

      map("n", "[c", function()
        if vim.wo.diff then
          return "[c"
        end
        vim.schedule(function()
          gs.prev_hunk()
        end)
        return "<Ignore>"
      end, { desc = "Previous hunk", expr = true })

      map({ "n", "v" }, "<leader>grr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset hunk" })
      map({ "n", "v" }, "<leader>gs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage hunk" })
      map({ "o", "x" }, "gH", "<cmd><C-U>Gitsigns select_hunk<cr>", { desc = "Select hunk" })
    end
    require("gitsigns").setup({
      -- keymaps = {
      --   -- Default keymap options
      --   noremap = false,
      -- },
      -- signs = {
      --   add = { hl = "GitSignsAdd", text = "│", numhl = "GitSignsAddNr", linehl = "GitSignsAddLn" },
      --   change = { hl = "GitSignsChange", text = "│", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
      --   delete = { hl = "GitSignsDelete", text = "_", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
      --   topdelete = { hl = "GitSignsDelete", text = "‾", numhl = "GitSignsDeleteNr", linehl = "GitSignsDeleteLn" },
      --   changedelete = { hl = "GitSignsChange", text = "~", numhl = "GitSignsChangeNr", linehl = "GitSignsChangeLn" },
      -- },
      signcolumn = true, -- Toggle with `:Gitsigns toggle_signs`
      numhl = false, -- Toggle with `:Gitsigns toggle_numhl`
      linehl = false, -- Toggle with `:Gitsigns toggle_linehl`
      word_diff = false, -- Toggle with `:Gitsigns toggle_word_diff`
      watch_gitdir = {
        interval = 1000,
        follow_files = true,
      },
      attach_to_untracked = true,
      current_line_blame = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
        delay = 0,
        ignore_whitespace = false,
      },
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
      sign_priority = 6,
      update_debounce = 100,
      status_formatter = nil, -- Use default
      max_file_length = 40000, -- Disable if file is longer than this (in lines)
      preview_config = {
        -- Options passed to nvim_open_win
        border = "single",
        style = "minimal",
        relative = "cursor",
        row = 0,
        col = 1,
      },
      -- yadm = {
      --   enable = false,
      -- },
      on_attach = mappings(),
    })
  end,
}

return M
