local terminals = {
  float = nil,
  horiz = nil,
  vert = nil,
}

return {
  {
    "akinsho/toggleterm.nvim",
    keys = function(_, keys)
      vim.list_extend(keys, {
        {
          "<leader>t",
          desc = "terminal",
        },
        {
          "<leader>tf",
          function()
            local Terminal = require("toggleterm.terminal").Terminal
            terminals.float = terminals.float
              or Terminal:new({
                direction = "float",
                float_opts = { border = "rounded" },
                on_open = function()
                  vim.cmd("startinsert")
                end,
              })
            terminals.float:toggle()
          end,
          mode = { "n", "t" },
          desc = "Toggle floating terminal",
        },
        {
          "<leader>th",
          function()
            local Terminal = require("toggleterm.terminal").Terminal
            terminals.horiz = terminals.horiz
              or Terminal:new({
                direction = "horizontal",
                on_open = function()
                  vim.cmd("startinsert")
                end,
              })
            terminals.horiz:toggle()
          end,
          mode = { "n", "t" },
          desc = "Toggle horizontal terminal",
        },
        {
          "<leader>tv",
          function()
            local Terminal = require("toggleterm.terminal").Terminal
            if not terminals.vert then
              terminals.vert = Terminal:new({
                direction = "vertical",
                on_open = function()
                  vim.cmd("startinsert")
                end,
              })
            end
            terminals.vert:toggle()
          end,
          mode = { "n", "t" },
          desc = "Toggle vertical terminal",
        },
      })
      return keys
    end,
    config = function()
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*",
        callback = function()
          vim.cmd("startinsert")
          -- ESC 直接传递给终端应用（如 opencode），不拦截
          -- 退出终端模式请使用 <C-\><C-n>（Neovim 默认方式）
          vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = 0, silent = true })
        end,
      })
    end,
  },
}
