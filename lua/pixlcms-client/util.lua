local M = {}

function M.urlencode(tbl)
    -- Helper function to encode a single string
    local function encode_char(c)
        return string.format("%%%02X", string.byte(c))
    end

    -- Helper function to encode a single key-value pair
    local function encode_pair(key, value)
        -- Convert key and value to strings and encode special characters
        local encoded_key = string.gsub(tostring(key), "[^%w%-%.%_%~]", encode_char)
        local encoded_value = string.gsub(tostring(value), "[^%w%-%.%_%~]", encode_char)
        return encoded_key .. "=" .. encoded_value
    end

    local result_pairs = {}
    -- Sort the keys to ensure consistent output
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys)

    -- Build the encoded string
    for _, key in ipairs(keys) do
        local value = tbl[key]
        -- Handle nested tables
        if type(value) == "table" then
            for _, v in ipairs(value) do
                table.insert(result_pairs, encode_pair(key .. "[]", v))
            end
        else
            table.insert(result_pairs, encode_pair(key, value))
        end
    end

    return table.concat(result_pairs, "&")
end

return M
