local M = {}

function M.setup(user_options)
    require("pixlwiki-client.config").setup(user_options)
    require("pixlwiki-client.commands").register_commands()
end

return M
