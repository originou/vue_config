local M = {
  "anuvyklack/hydra.nvim",
  dependencies = {
    "anuvyklack/keymap-layer.nvim",
  },
  commit = "ea91aa820a6cecc57bde764bb23612fff26a15de",
  build = function()
    -- hydra/layer/init.lua uses vim.tbl_deep_extend on getfenv() which
    -- crashes Neovim 0.11 (islist calls startswith on integer keys).
    -- Replace with setmetatable-based proxy that avoids the deep extend.
    local path = vim.fn.stdpath("data") .. "/lazy/hydra.nvim/lua/hydra/layer/init.lua"
    local lines = vim.fn.readfile(path)
    local out = {}
    local i = 1
    while i <= #lines do
      if lines[i]:find("vim%.tbl_deep_extend%('force', getfenv%(%)") then
        table.insert(out, "      -- patched: tbl_deep_extend on getfenv() crashes Neovim 0.11")
        table.insert(out, "      local env = setmetatable(")
        table.insert(out, "        { vim = setmetatable({ o = {}, go = {}, bo = {}, wo = {} }, { __index = vim }) },")
        table.insert(out, "        { __index = getfenv() }")
        table.insert(out, "      ) --[[@as table]]")
        i = i + 3 -- skip: tbl_deep_extend line + "vim = {...}" line + "}) --[[@as table]]" line
      else
        table.insert(out, lines[i])
        i = i + 1
      end
    end
    vim.fn.writefile(out, path)
  end,
  config = function()
    require("core.plugins.hydra.hydra")
  end,
}

return M
