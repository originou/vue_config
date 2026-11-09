local Hydra = require("hydra")
local gitsigns = require("gitsigns")

local hint = [[
 _J_: next hunk _K_: prev hunk
^^^^
 _q_: exit
]]

Hydra({
  name = "Git",
  hint = hint,

  config = {
    color = "pink",
    invoke_on_body = true,
    hint = {
      position = "bottom",
      border = "rounded",
    },
  },

  mode = { "n", "x" },
  body = "<leader>gM",

  heads = {
    {
      "J",
      function()
        if vim.wo.diff then
          return "]c"
        end
        vim.schedule(function()
          gitsigns.next_hunk()
        end)
        return "<Ignore>"
      end,
      { expr = true, desc = "Next hunk" },
    },

    {
      "K",
      function()
        if vim.wo.diff then
          return "[c"
        end
        vim.schedule(function()
          gitsigns.prev_hunk()
        end)
        return "<Ignore>"
      end,
      { expr = true, desc = "Prev hunk" },
    },

    {
      "q",
      nil,
      { exit = true, nowait = true, desc = "Quit" },
    },
  },
})
