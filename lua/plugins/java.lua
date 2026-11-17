-- Java / Spring Boot 支持
--
-- 组成：
--   1. LazyVim 内置 extra `lazyvim.plugins.extras.lang.java`（已在 lazyvim.json 开启）
--      → mason 的 jdtls + mfussenegger/nvim-jdtls + java-debug-adapter / java-test
--        + treesitter java。attach 后自带 <leader>co（organize imports）、
--        <leader>cx*（extract）、<leader>cg*（goto），以及 <leader>tt / <leader>tr / <leader>tT 跑测试。
--        测试键在下面被搬到了 <leader>jt*，因为 extra 用的是 <leader>t，和你 toggleterm
--        （<leader>tf/th/tv）的 <leader>t = terminal 组撞车。
--   2. JavaHello/spring-boot.nvim
--      → Spring Boot Language Server（vmware.vscode-spring-boot 里抽出来的那个）：
--        · Bean / RequestMapping / Spring 注解检索（:SpringBoot，走 vim.ui.select，snacks 接管 UI）
--        · application.yml / application.properties 的键补全与跳转
--        · @ConfigurationProperties、注解依赖提示、code action
--
-- ⚠ 系统侧依赖（本机现状：只有 jre21 + jdk17，/usr/bin/javac 是断链，也没有 mvn/gradle）：
--   sudo pacman -S jdk-openjdk maven gradle      # jdk-openjdk = JDK 27，顺带修好 javac
--   sudo archlinux-java set java-27-openjdk      # 让它成为默认（archlinux-java status 可查看）
--
--   为什么必须 25+：mason 装的 jdtls 1.63 的 bundle 声明了 Require-Capability osgi.ee=JavaSE 25，
--   用 JDK 21 起会直接 exit code 13（只在 lsp.log 里留一行 incubator 警告，很难看出原因）。
--   如果不想动系统默认 java，用文件末尾「方案 B」给 jdtls 单独指定 JVM。
--
-- 实测（用 Temurin 25 跑通）：jdtls bundles 里能看到 5 个 spring-boot jdtls 扩展 jar；
--   workspace/symbol "@+" 能列出 @SpringBootApplication 的 bean，"@/" 能列出 GET /hello。
--
-- 排查：:checkhealth spring_boot / :checkhealth jdtls / :LazyExtras
-- 注意：首次打开项目 Spring Boot LS 会重新索引整个工作区，大项目会卡几秒到几十秒。
return {
  -- ── Spring Boot Language Server ──────────────────────────────────────────
  {
    "JavaHello/spring-boot.nvim",
    -- 和 LazyVim 的 yaml/java 文件类型对齐；jproperties 是 nvim 0.12 给 *.properties 的 filetype
    ft = { "java", "yaml", "jproperties" },
    dependencies = { "mfussenegger/nvim-jdtls" },
    keys = {
      { "<leader>j", group = "java", mode = { "n", "v" } },
      { "<leader>js", "<cmd>SpringBoot<CR>", desc = "Spring symbols (beans/endpoints)" },
    },
    ---@type bootls.Config
    opts = {
      -- 只在真·Spring Boot 项目里启动 LS。默认策略是「打开任意 .java / application*.yml 就拉起
      -- 一个 -Xmx1G 的 JVM」，普通 Java 库项目里纯属浪费。判断会读 pom.xml / build.gradle(.kts)，
      -- 多模块的聚合 pom 也会往下找（最多 3 层、50 个构建文件，跳过 target/、build/）。
      project_filter = function(root_dir)
        return require("spring_boot.util").has_spring_boot_dependency(root_dir)
      end,
      -- 日志默认丢进 /dev/null。查 LS 起不来的问题时指到文件 + log_level = "debug"，
      -- 再 :checkhealth spring_boot 看解析出来的 java / LS jar / jdtls 扩展 jar 路径。
      log_level = "warn",
    },
  },

  -- ── 把 Spring Boot 的 jdtls 扩展 jar 塞进 jdtls 的 bundles ────────────────
  -- java extra 在 nvim-jdtls 的 config 里自己算 `init_options.bundles`
  -- （java-debug-adapter + java-test 的 jar），然后用 extend_or_override(config, opts.jdtls)
  -- 合并；那个函数支持 opts.jdtls 是**函数**，所以这里包一层把 spring-boot 的扩展 jar 追加进去，
  -- 而不是整份覆盖掉 extra 算好的结果（lazy 合并 opts 时列表是整份替换的）。
  -- 少了这一步：yml/properties 补全照旧能用，但 .java 里的注解依赖提示 / code action 没有。
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      -- ── 测试键从 <leader>t* 搬到 <leader>jt* ──────────────────────────────
      -- extra 的 LspAttach 里是用 wk.add({ ... rhs = function ... }) 注册的，which-key
      -- 会真的建出 buffer-local keymap，所以必须先 vim.keymap.del 再重建。
      -- 另外它把 <leader>t 这个组的标签改写成了 "test"（会盖住 toggleterm 的 "terminal"）；
      -- which-key 里后加的 group 覆盖先加的，所以这里补一条把它还原。
      opts.on_attach = function(args)
        local buf = args.buf
        local overrides = type(opts.test) ~= "boolean" and opts.test.config_overrides or nil

        for _, lhs in ipairs({ "<leader>tt", "<leader>tr", "<leader>tT" }) do
          pcall(vim.keymap.del, "n", lhs, { buffer = buf })
        end

        local ok, jdtls_dap = pcall(require, "jdtls.dap")
        if not ok then
          return
        end

        require("which-key").add({
          { "<leader>t", group = "terminal" },
          { "<leader>j", group = "java" },
          {
            mode = "n",
            buffer = buf,
            { "<leader>jt", group = "test" },
            {
              "<leader>jtt",
              function()
                jdtls_dap.test_class({ config_overrides = overrides })
              end,
              desc = "Run All Test",
            },
            {
              "<leader>jtr",
              function()
                jdtls_dap.test_nearest_method({ config_overrides = overrides })
              end,
              desc = "Run Nearest Test",
            },
            { "<leader>jtT", jdtls_dap.pick_test, desc = "Run Test" },
          },
        })
      end

      -- 方案 A（默认）：jdtls 走系统默认 java，装了 jdk-openjdk 就什么都不用改。
      -- 方案 B：系统默认 java 想留在 21 的话，把下面一行解注释：
      --   opts.cmd = { vim.fn.exepath("jdtls"), "--java-executable", "/usr/lib/jvm/java-27-openjdk/bin/java" }
      -- （mason 的 jdtls 是个 python wrapper，认 --java-executable / --jvm-arg，不会把它漏给 LS）
      local extend_jdtls = opts.jdtls
      opts.jdtls = function(config)
        if type(extend_jdtls) == "function" then
          config = extend_jdtls(config) or config
        elseif type(extend_jdtls) == "table" then
          config = vim.tbl_deep_extend("force", config, extend_jdtls)
        end

        local ok, spring_boot = pcall(require, "spring_boot")
        if ok then
          config.init_options = config.init_options or {}
          -- mason 里的 vscode-spring-boot-tools 还没装好时这里返回空表，装完重启 nvim 即可。
          local bundles = config.init_options.bundles or {}
          for _, jar in ipairs(spring_boot.java_extensions()) do
            if not vim.tbl_contains(bundles, jar) then
              table.insert(bundles, jar)
            end
          end
          config.init_options.bundles = bundles
        end
        return config
      end
    end,
  },

  -- ── 保存时格式化：google-java-format ────────────────────────────────────
  -- LazyVim 的 conform 默认保存即格式化（<leader>cf 手动格式化也走这里）。
  -- 换风格的话把 "google-java-format" 改成 "spring-javaformat"（mason 里也有）。
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        java = { "google-java-format" },
      },
    },
  },

  -- ── mason：自动安装 Spring Boot LS + 格式化器 ────────────────────────────
  -- 用函数形式（而不是 ensure_installed = {...}）追加，避免盖掉 extra 与 lsp.lua
  -- 里已经攒好的 ensure_installed 列表。
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for _, pkg in ipairs({ "vscode-spring-boot-tools", "google-java-format" }) do
        if not vim.tbl_contains(opts.ensure_installed, pkg) then
          table.insert(opts.ensure_installed, pkg)
        end
      end
    end,
  },
}
