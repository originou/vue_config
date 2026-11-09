local M = {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
  },
  ft = { "go", "java" },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dapui.setup()

    -- Open/close UI automatically with debug sessions
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end

    local wk = require("which-key")
    wk.add({
      { "<leader>d",  group = "Debug" },
      { "<leader>db", function() dap.toggle_breakpoint() end,                    desc = "Toggle breakpoint" },
      { "<leader>dB", function() dap.set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional breakpoint" },
      { "<leader>dc", function() dap.continue() end,                             desc = "Continue / Start" },
      { "<leader>di", function() dap.step_into() end,                            desc = "Step into" },
      { "<leader>do", function() dap.step_over() end,                            desc = "Step over" },
      { "<leader>dO", function() dap.step_out() end,                             desc = "Step out" },
      { "<leader>dr", function() dap.repl.open() end,                            desc = "Open REPL" },
      { "<leader>du", function() dapui.toggle() end,                             desc = "Toggle UI" },
      { "<leader>dq", function() dap.terminate() end,                            desc = "Quit" },
    })
  end,
}

return M
