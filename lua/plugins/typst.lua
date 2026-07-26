return {
  "chomosuke/typst-preview.nvim",
  ft = "typst", -- 仅在打开 .typ 文件时加载
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- 可选：状态栏/菜单图标
  },
  opts = {
    port = 8080,          -- 预览服务端口（默认 8080）
    open_cmd = "xdg-open", -- macOS 可改为 "open"，Windows 用 "start" 或留空自动检测
    auto_save = true,     -- 保存时自动刷新预览
    -- 更多选项见插件 README
  },
  keys = {
    { "<leader>pt", "<cmd>TypstPreviewToggle<cr>", desc = "Toggle Typst Preview" },
    { "<leader>pf", "<cmd>TypstPreview<cr>", desc = "Start Typst Preview" },
  },
}
