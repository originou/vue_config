-- References to ./lua/
vim.env.NVIM_LOG_LEVEL = "debug"
vim.opt.termguicolors = true

-- Function to reload the config
function _G.reload_config()
  for name, _ in pairs(package.loaded) do
    if name:match("^user_config") then
      package.loaded[name] = nil
    end
  end
  dofile(vim.fn.stdpath("config") .. "/init.lua")
  print("Configuration reloaded!")
end

-- Create a command to reload the config
vim.api.nvim_create_user_command("ReloadConfig", "lua _G.reload_config()", {})

-- Load global functions
require("core.globals")
-- Plugin management via lazy
require("core.lazy")
-- Plugin management via Packer
-- require("core.packer")
-- "Global" Keymappings
require("core.mappings")
-- All non plugin related (vim) options
require("core.options")
-- Vim autocommands/autogroups
require("core.autocmd")
-- Stream deck Neovim profile: X class "nvim" on the terminal while focused
require("core.deck")
