return {
	"williamboman/mason.nvim",
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
	},
	config = function()
		-- import mason
		local mason = require("mason")
		local offline = (vim.env.MASON_OFF == "1" or vim.env.CI == "true")

		-- import mason-lspconfig
		local mason_lspconfig = require("mason-lspconfig")

		local mason_tool_installer = require("mason-tool-installer")

		-- enable mason and configure icons
		mason.setup({
			ui = {
				icons = {
					package_installed = "✓",
					package_pending = "➜",
					package_uninstalled = "✗",
				},
			},
		})

		mason_lspconfig.setup({
			-- list of servers for mason to install
			ensure_installed = offline and {} or {
				"pyright", -- python
				"taplo", -- toml
				"gopls", -- golang
				"yamlls", -- yaml
				"lua_ls", -- lua
				"helm_ls", -- helm
				"tflint", -- terraform
				"docker_compose_language_service", -- docker compose
				"dockerls", -- docker
				"jsonls", -- json
				"markdown_oxide", -- markdown
			},
		})

		mason_tool_installer.setup({
			ensure_installed = offline and {} or {
				"prettier", -- prettier formatter
				"stylua", -- lua formatter
				"isort", -- python formatter
				"snyk", -- docker, go, helm, javascript, python, ruby,rust, terraform, typescript
			},
			run_on_start = not offline,
			auto_update = false,
		})
	end,
}
