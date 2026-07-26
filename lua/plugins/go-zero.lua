return {
  {
    "fahmiauliarahman/goctl.nvim",
    -- 延迟加载：仅在打开 .api 文件时才启动该插件以提升启动速度
    ft = { "goctl", "api" },
    -- 在插件加载前，强制 Neovim 将 .api 扩展名识别为 api 类型
    init = function()
      vim.filetype.add({
        extension = {
          api = "api",
        },
      })
    end,
    opts = {
      format_on_save = true,         -- 保存文件时自动使用 `goctl api format` 格式化
      goctl_path = "goctl",          -- goctl 二进制文件的路径
      enable_snippets = true,        -- 开启代码片段提示 (需配合 LuaSnip 使用)
      enable_keymaps = true,         -- 开启默认的快捷键映射 (如 gd, gr 等)
      remove_struct_keyword = true,  -- 格式化时自动移除类型定义中不必要的 `struct` 关键字
    },
  },
}
