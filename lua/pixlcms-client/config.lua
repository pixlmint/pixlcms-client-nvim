local config = {
    opts = {
        token = nil,
        endpoints = {},
        default = nil,
        project_links = vim.fn.stdpath('state') .. '/nvim/pixlcms-client',
        enter_opens_popup = false,
    },
}

function config.setup(user_config)
    config.opts = vim.tbl_deep_extend("force", config.opts, user_config)
    if vim.fn.isdirectory(config.opts.project_links) == 0 then
        vim.fn.mkdir(config.opts.project_links, "p")
    end
    config.opts.project_links = config.opts.project_links .. '/projects.json'
    if config.opts.default ~= nil then
        config.opts.endpoint = config.opts.endpoints[config.opts.default].domain
        config.opts.token = config.opts.endpoints[config.opts.default].token
    end
end

return config

