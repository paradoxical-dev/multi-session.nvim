local M = {}
local utils = require("multi-session.utils")

-- Default picker using vim.ui.select
---@param type string
---@param project? string
M.default = function(type, project)
	if type == "projects" then
		vim.ui.select(utils.project_list(), { prompt = "Select project" }, function(choice)
			M.default("sessions", choice)
		end)
	elseif type == "sessions" then
		vim.ui.select(utils.session_list(project), { prompt = "Select session" }, function(choice)
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

	for i, v in ipairs(options) do
		table.insert(items, { text = v })
	end

	snacks.picker({
		items = items,
		format = function(item)
			if type == "projects" then
				return { { opts.project_icon .. " " .. item.text, opts.project_hl } }
			else
				return { { opts.session_icon .. " " .. item.text, opts.session_hl } }
			end
		end,
		layout = opts.layout,
		preview = "directory",
		confirm = function(picker, item)
			picker:close()
			if type == "projects" then
				M.snacks("sessions", item.text, opts)
			else
				require("multi-session").load(project, item.text)
			end
		end,
	})
end

return M
