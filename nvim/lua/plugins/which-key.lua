-- While a key sequence is pending (which-key popup), a key that matches nothing must not reach
-- the editor. which-key feeds unmatched keys back to Neovim: "grR" (references are grr) became
-- Vim's "gr{char}" and replaced the character under the cursor with R. Here, in normal mode, an
-- unmatched key after a mapping-only prefix (<Leader>, <LocalLeader>, gr = Neovim's LSP keys) is
-- ignored: the popup stays open, Esc (or Ctrl-c) cancels. Other prefixes (g, z, ], d...) keep the
-- default: many Vim commands (gJ, ]]...) are not in which-key's tree.
-- Patches which-key's internal State.check (which-key v3).
---@type LazySpec
return {
  "folke/which-key.nvim",
  config = function(_, opts)
    require("which-key").setup(opts)

    -- Record the buffer a key tree is being built for, as Config.building_buf: opts.filter only gets
    -- the mapping (see which-key-neotree.lua). Mode is a local of which-key.buf, reached through an
    -- upvalue of Buf:get.
    local Buf = require("which-key.buf").Buf
    for i = 1, 30 do
      local name, Mode = debug.getupvalue(Buf.get, i)
      if not name then break end
      if name == "Mode" then
        local update = Mode.update
        Mode.update = function(self, ...)
          require("which-key.config").building_buf = self.buf.buf
          local ok, err = pcall(update, self, ...)
          require("which-key.config").building_buf = nil
          if not ok then error(err, 0) end
        end
        break
      end
    end

    local State = require("which-key.state")
    local Config = require("which-key.config")
    local check = State.check
    local pass = { "<Esc>", "<C-C>", "<BS>" }
    local function strict(keys)
      for _, prefix in ipairs({ vim.g.mapleader or "\\", vim.g.maplocalleader or "\\", "gr" }) do
        if vim.startswith(keys, vim.fn.keytrans(prefix)) then return true end
      end
    end
    State.check = function(state, key)
      if
        key
        and state.mode.mode == "n"
        and state.node.parent -- a prefix was typed (not the root of the tree)
        and strict(state.node.keys)
        and not vim.tbl_contains(pass, key)
        and key ~= Config.keys.scroll_down
        and key ~= Config.keys.scroll_up
        and not state.node:find(key, { expand = true })
      then
        vim.notify(state.node.keys .. key .. ": no mapping (Esc to cancel)", vim.log.levels.WARN)
        return state.node -- same node: which-key keeps waiting for a key
      end
      if key == "<C-C>" then key = "<Esc>" end
      return check(state, key)
    end
  end,
}
