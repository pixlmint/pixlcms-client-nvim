local config = {
    opts = {
        token = nil,
        endpoint = nil,
    },
}

function config.setup(user_config)
    config.opts = vim.tbl_deep_extend("force", config.opts, user_config)
end

return config

