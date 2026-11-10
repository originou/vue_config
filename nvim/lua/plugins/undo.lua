-- Persistent undo (AstroNvim turns undofile on): the undo history of a file is written to
-- ~/.local/state/nvim/undo/ on save and comes back when the file is opened again, even after
-- Neovim was closed (<Leader>fu: undo history). Limits:
-- - per file: the last UNDOLEVELS changes
-- - in time: on start, the histories not written for KEEP_DAYS days are deleted
local UNDOLEVELS = 1000
local KEEP_DAYS = 90

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@param opts AstroCoreOpts
  opts = function(_, opts)
    opts.options = opts.options or {}
    opts.options.opt = opts.options.opt or {}
    opts.options.opt.undofile = true
    opts.options.opt.undolevels = UNDOLEVELS

    opts.autocmds = opts.autocmds or {}
    opts.autocmds.undo_cleanup = {
      {
        event = "VimEnter",
        desc = "Delete undo histories older than " .. KEEP_DAYS .. " days",
        callback = function()
          vim.defer_fn(function()
            local dir = vim.fn.stdpath("state") .. "/undo"
            local limit = os.time() - KEEP_DAYS * 24 * 3600
            for name, kind in vim.fs.dir(dir) do
              local path = dir .. "/" .. name
              local stat = kind == "file" and vim.uv.fs_stat(path)
              if stat and stat.mtime.sec < limit then os.remove(path) end
            end
          end, 2000)
        end,
      },
    }
  end,
}
