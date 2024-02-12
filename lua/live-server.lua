local M = {}

local function log(message, level)
    vim.notify(
        string.format('live-server.nvim: %s', message),
        vim.log.levels[level]
    )
end

local job_cache = {}

local function find_cached_dir(dir)
    local cur = dir

    while not job_cache[cur] do
        if cur == '/' then
            return
        end

        cur = vim.fn.fnamemodify(cur, ':h')
    end

    return cur
end

local function is_running(dir)
    local cached_dir = find_cached_dir(dir)
    return cached_dir and job_cache[cached_dir]
end

M.config = {
    -- 8080 default is commonly used
    args = { '--port=5555' },
}

M.toggle = function()
    local dir = vim.fn.expand '%:p:h'
    local running = is_running(dir)
    if not running then
        M.start()
        return
    end
    M.stop()
end

M.setup = function(user_config)
    M.config = vim.tbl_deep_extend('force', M.config, user_config or {})

    if not vim.fn.executable 'live-server' then
        log(
            'live-server is not executable. Ensure the npm module is properly installed',
            vim.log.levels.ERROR
        )
        return
    end

    vim.api.nvim_create_user_command('LiveServerStart', M.start, {})
    vim.api.nvim_create_user_command('LiveServerStop', M.stop, {})
    vim.api.nvim_create_user_command('LiveServerToggle', M.toggle, {})
end

M.start = function()
    local dir = vim.fn.expand '%:p:h'
    local running = is_running(dir)

    if running then
        log('live-server already running', 'INFO')
        return
    end

    local cmd = { 'live-server', dir }
    vim.list_extend(cmd, M.config.args)

    local job_id = vim.fn.jobstart(cmd, {
        on_stderr = function(_, data)
            if not data or data[1] == '' then
                return
            end

            -- Remove color from error
            log(data[1]:match '.-m(.-)\27', 'ERROR')
        end,
        on_exit = function(_, exit_code)
            job_cache[dir] = nil

            -- instance killed with SIGTERM
            if exit_code == 143 then
                return
            end

            log(string.format('stopped with code %s', exit_code), 'INFO')
        end,
    })

    log('live-server started', 'INFO')
    job_cache[dir] = job_id
end

M.stop = function()
    local dir = vim.fn.expand '%:p:h'
    local running = is_running(dir)

    if running then
        local cached_dir = find_cached_dir(dir)
        if cached_dir then
            vim.fn.jobstop(job_cache[cached_dir])
            job_cache[cached_dir] = nil
            log('live-server stopped', 'INFO')
        end
    end
end

return M
