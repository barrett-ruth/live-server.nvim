local M = {}

local function log(message, level)
    vim.notify(
        string.format('live-server.nvim: %s', message),
        vim.log.levels[level]
    )
end

M.config = {
    -- let live-server handle the defaults
    args = {},
}

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
end

local job_cache = {}

M.start = function()
    local dir = vim.fn.expand '%:p:h'

    local cmd = { 'live-server' }
    vim.list_extend(cmd, M.config.args)

    if job_cache[dir] then
        log('live-server instance already running', 'INFO')
        return
    end

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

            if exit_code == 0 then
                return
            end

            log(string.format('stopped with code %s', exit_code), 'INFO')
        end,
    })

    log('live-server running', 'INFO')
    job_cache[dir] = job_id
end

M.stop = function()
    local dir = vim.fn.expand '%:p:h'

    if job_cache[dir] then
        vim.fn.jobstop(job_cache[dir])
        job_cache[dir] = nil
    else
        log('no live-server instance running', 'INFO')
    end
end

return M
