local M = {
  "coder/claudecode.nvim",
  config = function()
    require("claudecode").setup({
      split_side = "right",
      split_width_percentage = 0.4,
      terminal_cmd = "claude",
    })

    local wk = require("which-key")
    wk.add({
      { "<leader>a",  group = "Claude" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>",           desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>",      desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>",  desc = "Resume conversation" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>",       desc = "Send selection",      mode = "v" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>",   desc = "Reject diff" },
    })
  end,
}
return M
