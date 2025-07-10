local M = {}
local utils = require("multi-session.utils")

-- Default picker using vim.ui.select
---@param type string
---@param project? string
---@param opts table
M.default = function(type, project, opts)
	if type == "projects" then
		vim.ui.select(utils.project_list(), {
			prompt = "Select project",
			format_item = function(item)
				local path = item:gsub("%%", "/")
				return opts.project_icon .. " " .. path
			end,
		}, function(choice)
			M.default("sessions", choice, opts)
		end)
	elseif type == "sessions" then
		vim.ui.select(utils.session_list(project), {
			prompt = "Select session",
			format_item = function(item)
				return opts.session_icon .. " " .. item
			end,
		}, function(choice)
			require("multi-session").load(project, choice)
		end)
	else
		return vim.notify("Invalid type in default picker", vim.log.levels.ERROR)
	end
end

---@param type string
---@param project? string
---@param opts table
M.snacks = function(type, project, opts)
	local snacks = require("snacks")
	local items = {}

	local options = {}
	if type == "projects" then
		options = utils.project_list()
	elseif type == "sessions" then
		options = utils.session_list(project)
	else
		return vim.notify("Invalid type in snacks picker", vim.log.levels.ERROR)
	end

	for _, v in ipairs(options) do
		local path = ""
		if type == "projects" then
			path = v:gsub("%%", "/")
		else
			path = utils.session_dir .. "/" .. project .. "/" .. v
		end
		table.insert(items, { text = v, file = path })
	end

	snacks.picker({
		items = items,
		format = function(item)
			if type == "projects" then
				local path = item.text:gsub("%%", "/")
				local base = vim.fn.fnamemodify(path, ":t")
				local dir = path:gsub(base, "")
				return {
					{ opts.project_icon .. " " .. dir, opts.project_hl },
					{ base, opts.project_hl },
				}
			else
				return { { opts.session_icon .. " " .. item.text, opts.session_hl } }
			end
		end,
		layout = opts.layout,
		preview = opts.preview or "directory",
		confirm = function(picker, item)
			picker:close()
			if type == "projects" then
				opts.preview = "file"
				M.snacks("sessions", item.text, opts)
			else
				require("multi-session").load(project, item.text)
			end
		end,
	})
end

return M
