return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  -- Diffview owns these mappings. Remove the competing LazyVim/Snacks
  -- picker mappings so their final owner does not depend on load order.
  keys = {
    { "<leader>gd", false },
    { "<leader>gD", false },
  },
  opts = {
    picker = {
      -- 1. 在 actions 区域统一定义你的自定义函数
      actions = {
        -- 定义一个名为 "explorer_cd" 的新动作
        explorer_cd = function(picker, item)
          -- 获取当前选中的文件路径
          local path = item and item.file
          
          -- 如果选中的是目录
          if path and vim.fn.isdirectory(path) == 1 then
            vim.cmd("cd " .. path) -- 1. 改变 Vim 的全局工作目录 (CWD)
            picker:set_cwd(path)   -- 2. 改变 Snacks Picker 的浏览根目录
            picker:find()          -- 3. 刷新视图
          else
            -- 如果选中的不是目录，给个提示或者不做任何事
            vim.notify("请选择一个目录", vim.log.levels.WARN)
          end
        end,
      },
      
      sources = {
        explorer = {
          win = {
            list = {
              keys = {
                -- 2. 在这里只需要引用动作的名字（字符串），避免复杂的嵌套导致语法错误
                ["."] = "explorer_cd",
              },
            },
          },
        },
      },
    },
  },
}
