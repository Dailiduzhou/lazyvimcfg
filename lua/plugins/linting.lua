return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        -- 将 markdown 的 linter 设置为空表，从而禁用 markdownlint
        markdown = {},
      },
    },
  },
}
