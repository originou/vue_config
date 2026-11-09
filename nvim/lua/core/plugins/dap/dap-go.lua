local M = {
  "leoluz/nvim-dap-go",
  ft = { "go" },
  dependencies = { "mfussenegger/nvim-dap" },
  config = function()
    require("dap-go").setup({
      dap_configurations = {
        {
          type = "go",
          name = "Debug",
          request = "launch",
          program = "${file}",
        },
        {
          type = "go",
          name = "Debug (test)",
          request = "launch",
          mode = "test",
          program = "${file}",
        },
      },
      delve = {
        path = "dlv",
        initialize_timeout_sec = 20,
        port = "${port}",
        args = {},
        build_flags = "",
      },
    })

    local wk = require("which-key")
    wk.add({
      { "<leader>dt", function() require("dap-go").debug_test() end,      desc = "Debug test under cursor" },
      { "<leader>dT", function() require("dap-go").debug_last_test() end, desc = "Debug last test" },
    })
  end,
}

return M
