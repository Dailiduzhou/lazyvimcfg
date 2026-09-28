-- clangd 命令行。
--
-- 坑：LazyVim 的 `lang.clangd` extra 比你自己的 `plugins/` 晚解析，而 lazy.nvim 合并 opts
-- 时对**列表是整份覆盖**（不是逐项合并），所以 extra 里那份 `servers.clangd.cmd` 会把你
-- 这里写的整份顶掉。这里保持一份方便查看/修改，真正生效由 `config/lazy.lua` 末尾兑底。
--
-- 另外 `--function-arg-placeholders` 在新版 clangd（≥18）必须带值，
-- 只写参数名会报 `invalid value`（功能上会回退到默认值，但日志会脏）。
local CLANGD_CMD = {
  "clangd",
  "--background-index",
  "--clang-tidy",
  "--header-insertion=iwyu",
  "--completion-style=detailed",
  "--function-arg-placeholders=true",
  "--fallback-style=LLVM",
}

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        cmd = CLANGD_CMD,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- 彻底禁用原版 pyright
      opts.servers.pyright = {
        mason = false,     -- 核心：阻止 mason-lspconfig 自动安装
        autostart = false, -- 阻止自动启动
      }

      -- 启用并配置 basedpyright
      opts.servers.basedpyright = {
        -- Arch 用户特供选项：
        -- 如果你计划通过 pacman/yay 在系统层安装 basedpyright，请将其设为 false。
        -- 如果你仍然想让 Mason 帮你管理 basedpyright，请设为 true。
        mason = true,
        settings = {
          basedpyright = {
            analysis = {
              autoSearchPaths = true,
              typeCheckingMode = "standard", -- 推荐："standard" 或 "basic"，"strict" 可能过于严格
              useLibraryCodeForTypes = true,
            },
          },
        },
      }

      -- 阻止 LazyVim 执行原版 pyright 的默认 setup 逻辑
      opts.setup = opts.setup or {}
      opts.setup.pyright = function()
        return true -- 返回 true 意味着 "我已经手动处理过了，LazyVim 请忽略它"
      end
    end,
  },

  -- 2. 清理 Mason 的 ensure_installed 列表，防止从 Extra 中继承安装指令
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      -- 遍历并过滤掉 pyright
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return pkg ~= "pyright"
      end, opts.ensure_installed)

      -- 如果你上面 mason = true，确保 Mason 会自动安装 basedpyright
      table.insert(opts.ensure_installed, "basedpyright")
    end,
  },
}
