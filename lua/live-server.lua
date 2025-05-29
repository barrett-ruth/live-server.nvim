local M = {}

local function log(message, level)
    vim.notify(
        string.format('live-server.nvim: %s', message),
        vim.log.levels[level]
    )
end

local job_cache = {}

local function find_cached_dir(dir)
    if not dir then
        vim.notify("live-server.nvim: No directory provided to find_cached_dir()", vim.log.levels.ERROR)
        return
    end

    local cur = dir
    while not job_cache[cur] do
        if cur == '/' or string.match(cur, '^[A-Z]:\\$') then
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

-- Detect if OS is Windows
local function is_windows()
    return vim.loop.os_uname().version:match("Windows")
end

M.config = {
    -- 8080 default is commonly used, here 5555
    args = { '--port=5555' },
}

M.toggle = function(dir)
    local running = is_running(dir)
    if not running then
        M.start(dir)
        return
    end
    M.stop(dir)
end

M.setup = function(user_config)
    M.config = vim.tbl_deep_extend('force', M.config, user_config or {})

    if not vim.fn.executable('live-server') and not (is_windows() and vim.fn.executable('live-server.cmd')) then
        log(
            'live-server is not executable. Ensure the npm module is properly installed',
            vim.log.levels.ERROR
        )
        return
    end

    local function find_dir(args)
        local dir = args ~= '' and args or '%:p:h'
        return vim.fn.expand(vim.fn.fnamemodify(vim.fn.expand(dir), ':p'))
    end

    vim.api.nvim_create_user_command('LiveServerStart', function(opts)
        M.start(find_dir(opts.args))
    end, { nargs = '?' })
    vim.api.nvim_create_user_command('LiveServerStop', function(opts)
        M.stop(find_dir(opts.args))
    end, { nargs = '?' })
    vim.api.nvim_create_user_command('LiveServerToggle', function(opts)
        M.toggle(find_dir(opts.args))
    end, { nargs = '?' })
end

M.start = function(dir)
    local running = is_running(dir)

    if running then
        log('live-server already running', 'INFO')
        return
    end

    local cmd_exe = 'live-server'
    if is_windows() then
        cmd_exe = 'live-server.cmd'
    end

    local cmd = { cmd_exe, dir }
    vim.list_extend(cmd, M.config.args)

    local job_id = vim.fn.jobstart(cmd, {
        on_stderr = function(_, data)
            if not data or data[1] == '' then
                return
            end

            -- Remove color from error if present
            log(data[1]:match('.-m(.-)\27') or data[1], 'ERROR')
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

     -- Extract port from args
    local port = 'unknown'
    for _, arg in ipairs(M.config.args) do
        local p = arg:match('%-%-port=(%d+)')
        if p then
            port = p
            break
        end
    end

    log(string.format('live-server started on 127.0.0.1:%s', port), 'INFO')
    job_cache[dir] = job_id
end

M.stop = function(dir)
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
