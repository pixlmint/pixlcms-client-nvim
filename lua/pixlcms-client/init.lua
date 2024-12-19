local M = {}

function M.setup(user_options)
    require("pixlcms-client.config").setup(user_options)
    require("pixlcms-client.commands").register_commands()
end

return M
