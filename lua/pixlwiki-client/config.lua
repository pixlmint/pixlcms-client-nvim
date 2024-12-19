local config = {
    opts = {
        token = nil,
        endpoint = nil,
        project_links = vim.fn.stdpath('state') .. '/nvim/pixlwiki-client',
        enter_opens_popup = false,
    },
}

function config.setup(user_config)
    config.opts = vim.tbl_deep_extend("force", config.opts, user_config)
    if vim.fn.isdirectory(config.opts.project_links) == 0 then
        vim.fn.mkdir(config.opts.project_links, "p")
    end
    config.opts.project_links = config.opts.project_links .. '/projects.json'
end

return config

