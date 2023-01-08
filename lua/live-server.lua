local M = {}

local function log(message, level)
    vim.notify_once(
        string.format('import-cost.nvim: %s', message),
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
    local bufnr = vim.api.nvim_get_current_buf()

    local cmd = { 'live-server' }
    vim.list_extend(cmd, M.config.args)

    if job_cache[bufnr] then
        log('live-server instance already running', 'INFO')
        return
    end

    local job_id = vim.fn.jobstart(cmd, {
        on_stderr = function(_, data)
            if data[1] == '' then
                return
            end

            log(data[1]:match '.-m(.-)\27', 'ERROR')
        end,
        on_exit = function(_, exit_code)
            job_cache[bufnr] = nil

            if exit_code == 0 then
                return
            end

            log(
                string.format(
                    'live-server stopped unexpectedly with exit code %s',
                    exit_code
                ),
                'ERROR'
            )
        end,
    })

    job_cache[bufnr] = job_id
end

M.stop = function()
    local bufnr = vim.api.nvim_get_current_buf()

    if job_cache[bufnr] then
        vim.fn.jobstop(job_cache[bufnr])
        job_cache[bufnr] = nil
    else
        log('no live-server instance running', 'INFO')
    end
end

return M
