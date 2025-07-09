local M = {}

local session_dir = vim.fn.stdpath("state") .. "/multi-session"

local uv = vim.uv or vim.loop

M.project_list = function()
    local dirs = {}
    local fd = uv.fs_scandir(session_dir)
    if not fd then
        return dirs
    end
    while true do
        local name, type = uv.fs_scandir_next(fd)
        if not name then
            break
        end

        if type == "directory" then
            table.insert(dirs, name)
        end
    end
    return dirs
end

M.pick_project = function()
    vim.ui.select(M.project_list(), { prompt = "Select project" }, function(choice)
        print(choice)
    end)
end

M.path = function()
    local cwd = uv.cwd()
    local current_dir = vim.fn.fnamemodify(cwd, ":t")
end

M.delete = function()
    vim.cmd("silent !rm " .. session_dir .. "/session.vim")
end

M.save = function()
    local cwd = uv.cwd()
    local current_dir = vim.fn.fnamemodify(cwd, ":t")
    local project = session_dir .. "/" .. current_dir
    print(project)
    if not uv.fs_stat(project) then
        vim.fn.mkdir(project, "p")
    end
    vim.cmd("mksession! " .. project .. "/session.vim")
end

M.load = function()
    vim.cmd("source " .. session_dir .. "/session.vim")
end

function M.setup(opts)
    if not vim.loop.fs_stat(session_dir) then
        vim.fn.mkdir(session_dir, "p")
    end
end

return M
