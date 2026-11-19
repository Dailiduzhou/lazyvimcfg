-- Java / Spring Boot
--
-- 组成
--   1. LazyVim extra `lazyvim.plugins.extras.lang.java`（lazyvim.json 里已开启）
--      → mason 的 jdtls + nvim-jdtls + java-debug-adapter / java-test + treesitter java。
--        attach 后自带 <leader>co（organize imports）、<leader>cx*（extract）、
--        <leader>cg*（goto）；测试键被本文件从 <leader>t* 搬到 <leader>jt*，
--        因为 <leader>t 要留给 toggleterm。
--   2. JavaHello/spring-boot.nvim → Spring Boot Language Server
--      → Bean / RequestMapping 等 Spring 注解检索（:SpringBoot）、application.yml /
--        application.properties 的键补全与跳转、@ConfigurationProperties 提示与 code action。
--
-- 环境前提
--   · jdtls 本体要 Java 21+；mason 的 python wrapper 会先做版本检查，低了直接 exit 1。
--   · Boot LS 是另一个独立 JVM（class 版本 65），同样要 21+。
--   · 编译 / 跑测试 / 调试用的是**项目运行时**，不是 jdtls 的 JVM，两者要分开配。
--   · 本机 archlinux-java 默认 27，但 sdkman 把 JAVA_HOME 设成了 17 → 不能只看 JAVA_HOME。
--
-- 排查
--   :lua =vim.lsp.get_clients()        看 jdtls / spring-boot 在不在
--   :checkhealth  :LazyExtras
--   ~/.local/state/nvim/lsp.log        报错原文都在这，UI 上基本不提示
--
-- 注意：首次打开项目 Boot LS 会重新索引整个工作区，大项目会卡几秒到几十秒。

-- ── 挑一个 jdtls 能用的 JVM ────────────────────────────────────────────────
-- 从 JAVA_HOME 和 /usr/lib/jvm/java-XX 里挑版本最高的 21+，返回 JDK 目录（可直接当
-- JAVA_HOME 用）；一个都没有就返回 nil，让原始报错自己说话。结果缓存，只算一次。
local MIN_JAVA = 21
local java_dir_cache = nil
local function jdtls_java_dir()
  if java_dir_cache ~= nil then
    return java_dir_cache or nil
  end
  java_dir_cache = false

  local function major(bin)
    if vim.fn.executable(bin) ~= 1 then
      return nil
    end
    local out = vim.fn.system({ bin, "-version" })
    return tonumber(out and out:match('version "(%d+)'))
  end

  local candidates = {}
  if vim.env.JAVA_HOME and vim.env.JAVA_HOME ~= "" then
    table.insert(candidates, vim.env.JAVA_HOME)
  end
  -- 只认 java-XX 这种具体目录：default / default-runtime 是软链，会重复算一遍
  for _, dir in ipairs(vim.fn.glob("/usr/lib/jvm/*", false, true)) do
    if vim.fs.basename(dir):match("^java%-%d") then
      table.insert(candidates, dir)
    end
  end

  local best, best_major = nil, nil
  for _, dir in ipairs(candidates) do
    local m = major(dir .. "/bin/java")
    if m and m >= MIN_JAVA and (not best_major or m > best_major) then
      best, best_major = dir, m
    end
  end

  if best then
    java_dir_cache = best
  end
  return best
end

-- ── 项目运行时：让项目用它自己的 JDK ───────────────────────────────────────
-- 不声明 java.configuration.runtimes 时，项目运行时会默认跟着 jdtls 的 JVM 走（本机 27），
-- 于是测试 / 调试跑在 27 上。典型翻车：spring-boot-starter-test 的 Mockito 在 27 上直接
-- 失败（byte-buddy 支持上限 24：`Java 27 (71) is not supported ...`），同测试在 17 上通过。
-- 所以把所有装了 javac 的 JDK 都声明给 jdtls，项目按 pom / build.gradle 的 compile 级别
-- 自动匹配（java.version=17 → JavaSE-17）。DEFAULT_JAVA 只影响没有构建文件的裸 .java。
local DEFAULT_JAVA = 17

---@return { name: string, path: string, default: boolean|nil }[]
local function java_runtimes()
  local seen, out = {}, {}
  for _, dir in ipairs(vim.fn.glob("/usr/lib/jvm/*", false, true)) do
    -- 跳过软链目录；跳过纯 JRE 目录（没有 javac 的 java-21-openjdk 这类）
    if
      vim.fs.basename(dir):match("^java%-%d")
      and vim.fn.executable(dir .. "/bin/java") == 1
      and vim.fn.executable(dir .. "/bin/javac") == 1
    then
      local major = tonumber(vim.fn.system({ dir .. "/bin/javac", "-version" }):match("(%d+)"))
      if major and not seen[major] then
        seen[major] = true
        table.insert(out, { name = "JavaSE-" .. major, path = dir, default = major == DEFAULT_JAVA or nil })
      end
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  -- 没装 DEFAULT_JAVA 那版时退回最低的一个，保证总有一个 default
  if out[1] and not vim.tbl_filter(function(rt)
    return rt.default
  end, out)[1] then
    out[1].default = true
  end
  return out
end

-- ── 清理 jdtls 的 init_options.bundles ─────────────────────────────────────
-- LazyVim 用 `glob("$MASON/share/java-test/*.jar")` 一把抓，里面混了三种不该注册的 jar，
-- 每次 initialize 都会抛 `Failed to load extension bundles`（只进 lsp.log，UI 不提示）：
--   1. 非 OSGi bundle：runner-jar-with-dependencies.jar、jacocoagent.jar（给测试子进程当
--      classpath 用的，没有 bundle 头）
--   2. 和 jdtls 自带 bundle 撞名：org.objectweb.asm
--   3. 同名同版本两份：com.microsoft.java.test.plugin 的 -0.43.1.jar 和 .jar
-- 但同名**不同版本**要都留着：java-test 同时带 junit 5 和 6，junit6.runtime 只认 6.x，
-- 砍掉 6.x 会让整条 junit 依赖链解析失败。所以去重键是 SymbolicName + Version。
local function bundle_id(jar)
  local ok, out = pcall(vim.fn.system, { "unzip", "-p", jar, "META-INF/MANIFEST.MF" })
  if not ok or type(out) ~= "string" then
    return nil
  end
  local name = out:match("Bundle%-SymbolicName:%s*([^%s;,]+)")
  if not name then
    return nil
  end
  return name .. "@" .. (out:match("Bundle%-Version:%s*([^%s;,]+)") or "0")
end

local function filter_bundles(bundles)
  -- 没有 unzip 就读不到 MANIFEST，宁可原样传（jdtls 顶多打一行 bundle 警告）
  if vim.fn.executable("unzip") ~= 1 then
    return bundles
  end
  -- jdtls 自带的 bundle 不能再注册一遍；文件名就是 <SymbolicName>_<version>.jar，
  -- 省一次 unzip。
  -- 注意 $MASON 指 mason/share（放 extension jar 的），jdtls 本体在 mason/packages 下，
  -- 所以从 mason/bin/jdtls 往上两级反推，别直接拼 $MASON。
  local mason_root = vim.fs.dirname(vim.fs.dirname(vim.fn.exepath("jdtls") or ""))
  local plugins_dir = mason_root .. "/packages/jdtls/plugins"
  local taken = {}
  for _, jar in ipairs(vim.fn.glob(plugins_dir .. "/*.jar", false, true)) do
    local name, version = vim.fs.basename(jar):match("^(.*)_([^_]+)%.jar$")
    if name and version then
      taken[name .. "@" .. version] = true
    end
  end

  local out = {}
  for _, jar in ipairs(bundles) do
    local id = bundle_id(jar)
    if id and not taken[id] then
      taken[id] = true
      table.insert(out, jar)
    end
  end
  return out
end

return {
  -- ── Spring Boot Language Server ──────────────────────────────────────────
  {
    "JavaHello/spring-boot.nvim",
    -- 和 LazyVim 的 java / yaml 文件类型对齐；jproperties 是 nvim 0.12 给
    -- *.properties 的 filetype
    ft = { "java", "yaml", "jproperties" },
    dependencies = { "mfussenegger/nvim-jdtls" },
    keys = {
      { "<leader>j", group = "java", mode = { "n", "v" } },
      { "<leader>js", "<cmd>SpringBoot<CR>", desc = "Spring symbols (beans/endpoints)" },
    },
    ---@type bootls.Config
    opts = {
      -- Boot LS 要一个 21+ 的 JVM，用 java_cmd 单独指定。
      -- 不要为此改全局 JAVA_HOME：那个值要留给 mvn / gradle / 测试 / 调试（见 java_runtimes）。
      java_cmd = (function()
        local dir = jdtls_java_dir()
        return dir and (dir .. "/bin/java") or nil
      end)(),
      -- 只在真·Spring Boot 项目里启动 LS。默认策略是「打开任意 .java / application*.yml
      -- 就拉起一个 -Xmx1G 的 JVM」，普通 Java 库项目里纯浪费。判断会读 pom.xml /
      -- build.gradle(.kts)，多模块聚合 pom 会往下找（最多 3 层、50 个构建文件，
      -- 跳过 target/、build/）。
      project_filter = function(root_dir)
        return require("spring_boot.util").has_spring_boot_dependency(root_dir)
      end,
      -- 日志默认丢进 /dev/null。查 LS 起不来时指到文件 + log_level = "debug"，
      -- 再看解析出来的 java / LS jar / jdtls 扩展 jar 路径。
      log_level = "warn",
    },
  },

  -- ── jdtls 的扩展 jar、JVM 与项目运行时 ───────────────────────────────────
  -- java extra 会在 nvim-jdtls 的 config 里算好 `init_options.bundles`（java-debug-adapter +
  -- java-test），再用 extend_or_override(config, opts.jdtls) 合并。那个函数支持 opts.jdtls
  -- 是**函数**，所以这里包一层往里追加，而不是整份覆盖（lazy 合并 opts 时列表是整份替换）。
  -- 少了这一步：yml / properties 补全照旧，但 .java 里的注解依赖提示和 code action 没有。
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      -- 测试键从 <leader>t* 搬到 <leader>jt*。
      -- extra 是用 which-key 的 wk.add 注册的，which-key 会真建出 buffer-local keymap，
      -- 所以得先 vim.keymap.del 再重建。extra 还把 <leader>t 的组标签改成了 "test"
      -- （会盖掉 toggleterm 的 "terminal"），后加的 group 覆盖先加的，这里补一条还原。
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

      local extend_jdtls = opts.jdtls
      opts.jdtls = function(config)
        -- 只给 jdtls 这个进程换 JVM。刻意不动 vim.env.JAVA_HOME：
        -- nvim 里的 mvn / gradle / 测试 / 调试 / spring-boot:run 都读它，
        -- 必须保持跟项目 JDK 一致（见 java_runtimes）。
        local java_dir = jdtls_java_dir()
        if java_dir and config.cmd then
          -- mason 的 jdtls 是 python wrapper，认 --java-executable / --jvm-arg，不会漏给 LS
          config.cmd = vim.list_extend(
            { config.cmd[1], "--java-executable", java_dir .. "/bin/java" },
            vim.list_slice(config.cmd, 2)
          )
        end
        if type(extend_jdtls) == "function" then
          config = extend_jdtls(config) or config
        elseif type(extend_jdtls) == "table" then
          config = vim.tbl_deep_extend("force", config, extend_jdtls)
        end

        local ok, spring_boot = pcall(require, "spring_boot")
        if ok then
          config.init_options = config.init_options or {}
          -- vscode-spring-boot-tools 还没装好时这里返回空表，装完重启 nvim 即可
          local bundles = config.init_options.bundles or {}
          for _, jar in ipairs(spring_boot.java_extensions()) do
            if not vim.tbl_contains(bundles, jar) then
              table.insert(bundles, jar)
            end
          end
          config.init_options.bundles = bundles
        end
        -- 声明本机 JDK 列表，项目按自己的 compile 级别匹配运行时（见 java_runtimes）
        config.settings = config.settings or {}
        config.settings.java = config.settings.java or {}
        config.settings.java.configuration = vim.tbl_extend("force", config.settings.java.configuration or {}, {
          runtimes = java_runtimes(),
        })
        -- 丢掉非 bundle / 撞名 / 同版本的 jar（见 filter_bundles）
        config.init_options.bundles = filter_bundles(config.init_options.bundles or {})
        return config
      end
    end,
  },

  -- ── 保存时格式化：google-java-format ─────────────────────────────────────
  -- LazyVim 的 conform 默认保存即格式化（<leader>cf 手动格式化也走这里）。
  -- 想换风格就把 "google-java-format" 改成 "spring-javaformat"（mason 里也有）。
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        java = { "google-java-format" },
      },
    },
  },

  -- ── mason：自动安装 Boot LS + 格式化器 ───────────────────────────────────
  -- 用函数形式（而不是 ensure_installed = {...}）追加，避免盖掉 extra 和 lsp.lua
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
