-- AI switcher state (copilot | none)
-- <leader>ii: open picker to switch, <leader>is: show current, <leader>ix: disable
-- (<leader>i = AI inline: <leader>a is Claude Code's, claudecode.lua)
-- Off on startup (vim.g.current_ai = "none"). Once picked, suggestions show up as you type
-- (auto_trigger), Alt+Tab accepts them.

local function disable_all()
  require("copilot.suggestion").dismiss()
  vim.cmd("Copilot disable")
end

local function enable_ai(name)
  disable_all()
  if name == "copilot" then
    vim.cmd("Copilot enable")
  end
  -- "none" keeps everything disabled
  vim.g.current_ai = name
  local msg = name == "none" and "AI: disabled (LSP only)" or ("AI: switched to " .. name)
  vim.notify(msg, vim.log.levels.INFO)
end

return {
  "zbirenbaum/copilot.lua",
  event = "InsertEnter",
  cmd = "Copilot",
  -- In keys (not set in config): they work before the first InsertEnter, and load the plugin
  keys = {
    {
      "<leader>ii",
      function()
        local choices = { "copilot", "none" }
        vim.ui.select(choices, {
          prompt = "Select AI assistant:",
          format_item = function(item)
            return item .. (item == vim.g.current_ai and "  [active]" or "")
          end,
        }, function(choice)
          if choice then enable_ai(choice) end
        end)
      end,
      desc = "AI: select assistant",
    },
    {
      "<leader>ix",
      function()
        disable_all()
        vim.g.current_ai = "none"
        vim.notify("AI: disabled (LSP only)", vim.log.levels.INFO)
      end,
      desc = "AI: disable all assistants",
    },
    {
      "<leader>is",
      function() vim.notify("Active AI: " .. vim.g.current_ai, vim.log.levels.INFO) end,
      desc = "AI: show active assistant",
    },
  },
  init = function()
    vim.g.current_ai = "none" -- no AI active on startup
  end,
  config = function()
    require("copilot").setup({
      suggestion = {
        enabled = true,
        auto_trigger = true, -- suggestions as you type, while Copilot is enabled (<leader>ii)
        keymap = {
          accept      = "<M-Tab>", -- Alt+Tab: accept full suggestion
          accept_word = "<M-w>",   -- Alt+w:   accept next word
          next        = "<M-m>",   -- Alt+m:   next suggestion
          prev        = "<M-[>",   -- Alt+[:   previous suggestion
          dismiss     = "<M-e>",   -- Alt+e:   dismiss
        },
      },
      -- Panel of alternative completions: off, the current Copilot server (1.561) answers its
      -- requests with no solution (getPanelCompletions: 0, copilotPanelCompletion: the same single
      -- one as the inline suggestion), tested 2026-10-26
      panel = { enabled = false },
    })

    -- Off unless picked: synchronous, so a <leader>ii that loaded the plugin isn't undone
    -- afterwards (it runs enable_ai once this config is done)
    if vim.g.current_ai ~= "copilot" then
      vim.cmd("Copilot disable")
    end
  end,
}
