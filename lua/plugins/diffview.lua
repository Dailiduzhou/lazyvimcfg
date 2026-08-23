return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  -- cmd 懒加载：只有在输入这些命令时才加载插件
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles", "DiffviewFileHistory" },
  -- 全局快捷键：随时唤出和关闭
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: 当前改动" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: 当前文件历史" },
    { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diffview: 关闭视图" },
    { "<leader>gt", "<cmd>DiffviewToggleFiles<cr>", desc = "Diffview: 切换文件树显示" },
  },
  opts = {
    -- 开启更精细的差异高亮（基于字符级别，非常推荐）
    enhanced_diff_hl = true,
    -- 默认使用并排视图（diff2_horizontal），如果屏幕较窄会自动回退到上下视图
    view = {
      default = {
        layout = "diff2_horizontal",
      },
      merge_tool = {
        -- 解决冲突时的默认布局（三向合并视图）
        layout = "diff3_horizontal",
        disable_diagnostics = true,
      },
      file_history = {
        layout = "diff2_horizontal",
      },
    },
    -- 左侧文件树面板的配置
    file_panel = {
      listing_style = "tree", -- 树状结构显示文件 (可选 "list")
      tree_options = {
        flatten_dirs = true, -- 自动展平空目录
        folder_statuses = "only_folded",
      },
      win_config = {
        position = "left", -- 文件面板在左侧
        width = 35, -- 面板宽度
        win_opts = {
          winhl = "Normal:DiffviewNormal",
        },
      },
    },
  },
}
