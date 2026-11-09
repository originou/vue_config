local M = {
  "mfussenegger/nvim-jdtls",
  ft = { "java" },
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()
    local utils = require("core.plugins.lsp.utils")

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function()
        local lombok_jar = ""
        local lombok_bin = vim.fn.exepath("lombok")
        if lombok_bin ~= "" then
          local f = io.open(lombok_bin, "r")
          if f then
            local content = f:read("*a")
            f:close()
            lombok_jar = content:match("/nix/store/[^ :]-lombok[^ :]*/share/java/lombok%.jar") or ""
          end
        end

        -- DAP bundles: find debug/test JARs from nix store
        local bundles = {}
        local debug_jar = vim.fn.glob("/nix/store/*vscode-java-debug*/share/vscode/extensions/vscjava.vscode-java-debug/server/com.microsoft.java.debug.plugin-*.jar", true)
        if debug_jar ~= "" then
          vim.list_extend(bundles, { debug_jar })
        end
        local test_jars = vim.split(
          vim.fn.glob("/nix/store/*vscode-java-test*/share/vscode/extensions/vscjava.vscode-java-test/server/*.jar", true),
          "\n", { plain = true, trimempty = true }
        )
        vim.list_extend(bundles, test_jars)

        local root_dir = vim.fs.root(0, { "pom.xml", "build.gradle", "build.gradle.kts" })
        local project_name = vim.fn.fnamemodify(root_dir or vim.fn.getcwd(), ":t")
        local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name

        local formatter_url = nil
        if root_dir then
          for _, candidate in ipairs({
            root_dir .. "/checkstyle/eclipse-formatter.xml",
            root_dir .. "/eclipse-formatter.xml",
          }) do
            if vim.fn.filereadable(candidate) == 1 then
              formatter_url = candidate
              break
            end
          end
        end

        require("jdtls").start_or_attach({
          cmd = (function()
            local c = { "jdtls", "-data", workspace_dir }
            if lombok_jar ~= "" then
              table.insert(c, "--jvm-arg=-javaagent:" .. lombok_jar)
            end
            return c
          end)(),
          root_dir = root_dir,
          capabilities = capabilities,
          init_options = { bundles = bundles },
          on_attach = function(client, bufnr)
            utils.custom_lsp_attach(client, bufnr)
            if #bundles > 0 then
              require("jdtls").setup_dap({ hotcodereplace = "auto" })
            end
            local wk = require("which-key")
            wk.add({
              { "<leader>dt", function() require("jdtls").test_nearest_method() end, desc = "Debug test under cursor", buffer = bufnr },
              { "<leader>dT", function() require("jdtls").test_class() end,          desc = "Debug test class",        buffer = bufnr },
            })
          end,
          handlers = {
            ["$/progress"] = function(_, result, ctx)
              local value = result.value or {}
              local title = value.title or ""
              local kind = value.kind or ""
              _G._jdtls_skip_tokens = _G._jdtls_skip_tokens or {}
              local skip_patterns = { "validate", "publish diagnostics", "public diagnostics" }
              local should_skip = false
              for _, pattern in ipairs(skip_patterns) do
                if title:lower():find(pattern) then should_skip = true break end
              end
              if kind == "begin" and should_skip then
                _G._jdtls_skip_tokens[result.token] = true
                return
              end
              if _G._jdtls_skip_tokens[result.token] then
                if kind == "end" then
                  _G._jdtls_skip_tokens[result.token] = nil
                end
                return
              end
              vim.lsp.handlers["$/progress"](_, result, ctx)
            end,
          },
          settings = {
            java = {
              format = formatter_url and {
                settings = { url = formatter_url },
              } or nil,
            },
          },
        })
      end,
    })
  end,
}
return M
