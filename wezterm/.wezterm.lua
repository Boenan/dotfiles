-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configurations
local config = wezterm.config_builder()

config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 20

config.colors = {
	foreground = "#CBE0F0",
	background = "#011423",
	cursor_bg = "#47FF9C",
	cursor_border = "#47FF9C",
	cursor_fg = "#011423",
	selection_bg = "#033259",
	selection_fg = "#CBE0F0",
	ansi = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7" },
	brights = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#A277FF", "#a277ff", "#24EAF7", "#24EAF7" },
}

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.95

config.keys = {
	{ key = "d", mods = "CMD", action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }) },
	{ key = "d", mods = "CMD|SHIFT", action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }) },
	{ key = "w", mods = "CMD", action = wezterm.action({ CloseCurrentPane = { confirm = true } }) },
	{ key = "LeftArrow", mods = "CMD", action = wezterm.action.SendKey({ key = "b", mods = "ALT" }) },
	{ key = "RightArrow", mods = "CMD", action = wezterm.action.SendKey({ key = "f", mods = "ALT" }) },
	{ key = "LeftArrow", mods = "CMD|SHIFT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "CMD|SHIFT", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "CMD|SHIFT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "CMD|SHIFT", action = wezterm.action.ActivatePaneDirection("Down") },
}

--

return config
