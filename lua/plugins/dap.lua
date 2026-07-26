return {
  "mfussenegger/nvim-dap",
  config = function(_, opts)
    local dap = require("dap")

    -- 1. 配置 GDB 适配器
    dap.adapters.gdb = {
      type = "executable",
      command = "gdb",
      args = { "-i", "dap" }, -- 启动 GDB 的 DAP 模式
    }

    -- 2. 配置 C/C++ 的调试配置
    local gdb_config = {
      {
        name = "Run executable (GDB)",
        type = "gdb",
        request = "launch",
        -- 启动调试时，提示输入可执行文件的路径
        program = function()
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopAtBeginningOfMainSubprogram = false,
      },
    }

    dap.configurations.c = gdb_config
    dap.configurations.cpp = gdb_config
    dap.configurations.rust = gdb_config
  end,
}
