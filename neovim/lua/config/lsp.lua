vim.filetype.add({
    extension = {
        ansible = "yaml.ansible",
    },
    pattern = {
        [".*%.ansible%.ya?ml"] = "yaml.ansible",
        [".*%.ya?ml%.ansible"] = "yaml.ansible",
        [".*/playbook/.*%.ya?ml"] = "yaml.ansible",
        [".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
        [".*/group_vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/host_vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/defaults/.*%.ya?ml"] = "yaml.ansible",
        [".*/tasks/.*%.ya?ml"] = "yaml.ansible",
        [".*/handlers/.*%.ya?ml"] = "yaml.ansible",
        [".*/vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/default/.*%.ya?ml"] = "yaml.ansible",
        [".*/defaults/.*%.ya?ml"] = "yaml.ansible",
    },
})

vim.lsp.config("lua_ls", {
    cmd = { "lua-language-server" },
    filetypes = { "lua" },
    root_markers = {
        { ".luarc.json", ".luarc.jsonc", ".emmyrc.json" },
        { ".stylua.toml", "stylua.toml", ".luacheckrc", "selene.toml", "selene.yml" },
        { ".git" },
    },
    settings = {
        Lua = {
            runtime = {
                version = "LuaJIT",
                path = {
                    "lua/?.lua",
                    "lua/?/init.lua",
                },
            },
            workspace = {
                checkThirdParty = false,
                library = {
                    vim.env.VIMRUNTIME,
                },
            },
            telemetry = {
                enable = false,
            },
        },
    },
})

vim.lsp.config("nushell", {
    cmd = { "nu", "--lsp" },
    filetypes = { "nu" },
    root_dir = function(bufnr, on_dir)
        on_dir(vim.fs.root(bufnr, { ".git" }) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
    end,
})

local powershell_editor_services = "/opt/powershell-editor-services/current"
local powershell_editor_cache = vim.fn.stdpath("cache")

vim.lsp.config("powershell_es", {
    cmd = {
        "/usr/local/bin/pwsh",
        "-NoLogo",
        "-NoProfile",
        "-File",
        powershell_editor_services .. "/PowerShellEditorServices/Start-EditorServices.ps1",
        "-Stdio",
        "-BundledModulesPath",
        powershell_editor_services,
        "-HostName",
        "nvim",
        "-HostProfileId",
        "0",
        "-HostVersion",
        "1.0.0",
        "-LogPath",
        powershell_editor_cache .. "/powershell_es.log",
        "-SessionDetailsPath",
        powershell_editor_cache .. "/powershell_es.session.json",
    },
    filetypes = { "ps1" },
    root_markers = { "PSScriptAnalyzerSettings.psd1", ".git" },
})

vim.lsp.config("pyright", {
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = {
        "pyrightconfig.json",
        "pyproject.toml",
        "setup.py",
        "setup.cfg",
        "requirements.txt",
        "Pipfile",
        ".git",
    },
    settings = {
        pyright = {
            disableTaggedHints = true,
        },
        python = {
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
            },
        },
    },
})

vim.lsp.config("ansiblels", {
    cmd = { "ansible-language-server", "--stdio" },
    filetypes = { "yaml.ansible" },
    root_markers = { "ansible.cfg", ".ansible-lint", ".git" },
    settings = {
        ansible = {
            python = {
                interpreterPath = "python",
            },
            ansible = {
                path = "ansible",
            },
            executionEnvironment = {
                enabled = false,
            },
            validation = {
                enabled = true,
                lint = {
                    enabled = true,
                    path = "ansible-lint",
                },
            },
        },
    },
})

vim.lsp.config("marksman", {
    cmd = { "marksman", "server" },
    filetypes = { "markdown", "markdown.mdx" },
    root_markers = { ".marksman.toml", ".git" },
})

vim.lsp.config("ols", {
    cmd = { "ols" },
    filetypes = { "odin" },
    root_markers = { "ols.json", "odinfmt.json", ".git" },
    init_options = {
        enable_format = false,
    },
})

vim.lsp.config("rust_analyzer", {
    cmd = { "rust-analyzer" },
    filetypes = { "rust" },
    root_markers = { "Cargo.toml", "rust-project.json", ".git" },
    settings = {
        ["rust-analyzer"] = {
            check = {
                command = "clippy",
            },
        },
    },
    before_init = function(init_params, config)
        if config.settings and config.settings["rust-analyzer"] then
            init_params.initializationOptions = config.settings["rust-analyzer"]
        end
    end,
})

vim.lsp.enable({
    "lua_ls",
    "nushell",
    "powershell_es",
    "pyright",
    "ansiblels",
    "marksman",
    "ols",
    "rust_analyzer",
})
