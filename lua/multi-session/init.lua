local M = {}

local session_dir = vim.fn.stdpath("state") .. "/multi-session"

local uv = vim.uv or vim.loop

M.config = {}

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

M.session_list = function(project)
    local files = {}
    local fd = uv.fs_scandir(session_dir .. "/" .. project)
    if not fd then
        return files
    end
    while true do
        local name, type = uv.fs_scandir_next(fd)
        if not name then
            break
        end
        if type == "file" then
            table.insert(files, name)
        end
    end
    return files
end

M.pick_session = function(project)
    if M.config.picker == "snacks" then
        local sel = M.snacks_picker("sessions")
        return sel
    else
        local co = coroutine.running()
        vim.ui.select(M.session_list(project), { prompt = "Select session" }, function(choice)
            coroutine.resume(co, choice)
        end)
        return coroutine.yield()
    end
end

M.pick_project = function()
    if M.config.picker == "snacks" then
        local sel = M.snacks_picker("projects")
        return sel
    else
        local co = coroutine.running()
        vim.ui.select(M.project_list(), { prompt = "Select project" }, function(choice)
            coroutine.resume(co, choice)
        end)
        return coroutine.yield()
    end
end

M.test = function()
    coroutine.wrap(function()
        local project = M.pick_project()
        print(project)
    end)()
end

M.load = function()
    coroutine.wrap(function()
        local project = M.pick_project()
        local session = M.pick_session(project)

        vim.cmd("source " .. session_dir .. "/" .. project .. "/" .. session)
    end)()
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

function M.setup(opts)
    if not vim.loop.fs_stat(session_dir) then
        vim.fn.mkdir(session_dir, "p")
    end
end

return M
