local nls = require("null-ls")
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

nls.setup({
  sources = {
    nls.builtins.formatting.prettier.with({
      extra_args = { "--single-quote", "false" },
    }),
    nls.builtins.formatting.stylua.with({ extra_args = { "--indent-type", "Spaces", "--indent-width", "2" } }),
    nls.builtins.formatting.terraform_fmt,
    nls.builtins.formatting.shfmt,
    nls.builtins.formatting.goimports,
    nls.builtins.formatting.gofumpt,
    nls.builtins.code_actions.gomodifytags,
    nls.builtins.formatting.google_java_format,
    nls.builtins.diagnostics.checkstyle.with({
      condition = function(utils)
        return utils.root_has_file("checkstyle/checkstyle.xml")
      end,
      extra_args = function(params)
        return { "-c", params.root .. "/checkstyle/checkstyle.xml" }
      end,
    }),
  },
  on_attach = function(client, bufnr)
    local wk = require("which-key")
    wk.add({
      { "<leader>mF", "<cmd>lua require('core.plugins.lsp.utils').toggle_autoformat()<cr>", desc = "Toggle format on save" },
    })
    if client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          if AUTOFORMAT_ACTIVE then -- global var defined in functions.lua
            vim.lsp.buf.format({ bufnr = bufnr })
          end
        end,
      })
    end
  end,
})
