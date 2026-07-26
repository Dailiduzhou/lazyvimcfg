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
    -- 快捷键配置（仅在 Diffview 窗口内生效）
    keymaps = {
      disable_defaults = false, -- 保持默认快捷键开启
      -- 文件树面板的特定快捷键
      file_panel = {
        ["j"] = "next_entry", -- 选中下一个文件
        ["k"] = "prev_entry", -- 选中上一个文件
        ["<cr>"] = "select_entry", -- 在右侧打开选中文件的 diff
        ["o"] = "select_entry", -- 同上
        ["l"] = "select_entry", -- 打开或展开文件夹
        ["h"] = "close_fold", -- 折叠文件夹
        ["-"] = "toggle_stage_entry", -- 暂存 / 取消暂存当前文件 (git add)
        ["S"] = "stage_all", -- 暂存所有文件
        ["U"] = "unstage_all", -- 取消暂存所有文件
        ["X"] = "restore_entry", -- 丢弃当前文件的修改 (git restore)
        ["R"] = "refresh_files", -- 刷新状态
        ["<tab>"] = "select_next_entry", -- 快速跳到下一个有修改的文件
        ["<s-tab>"] = "select_prev_entry", -- 快速跳到上一个有修改的文件
        ["gf"] = "goto_file_edit", -- 退出 diff 并在新 buffer 中打开当前文件
      },
      -- 在 Diff 视图（代码比对窗口）中的快捷键
      view = {
        ["<tab>"] = "select_next_entry", -- 直接切到下一个文件的 diff
        ["<s-tab>"] = "select_prev_entry",
        ["gf"] = "goto_file_edit",
        ["<leader>e"] = "focus_files", -- 焦点切回左侧文件树
      },
    },
  },
}
