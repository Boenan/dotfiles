return {
	"ojroques/nvim-osc52",
	config = function()
		local ok, osc52 = pcall(require, "osc52")
		if not ok then
			return
		end
		osc52.setup({})
		local function copy(lines, _)
			osc52.copy(table.concat(lines, "\n"))
		end
		local function paste()
			return { vim.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
		end
		vim.g.clipboard = {
			name = "osc52",
			copy = { ["+"] = copy, ["*"] = copy },
			paste = { ["+"] = paste, ["*"] = paste },
		}
		vim.opt.clipboard = "unnamedplus"
	end,
}
