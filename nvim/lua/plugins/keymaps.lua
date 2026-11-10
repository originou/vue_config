-- ;j = Esc,
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
  end,
}
