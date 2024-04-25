local fs = require("nelua.utils.fs")
local logger = require("null.logger")
local sha = require("sha2")

local utils = {}

---@param file string
---@param hash string
---@return boolean
---@return string
function utils.check_sha256sum(file, hash)
    local content = fs.readfile(file, true)
    ---@cast content string
    return sha.sha256(content) == hash, content
end

---@param t string[]
function utils.absolute_all(t)
    for i, v in pairs(t) do
        t[i] = fs.abspath(v)
    end
end

---@param cmd string
---@return boolean
function utils.has_command(cmd)
    local found = not not fs.findbinfile(cmd)
    if not found then
        logger.err("command not found: '" .. cmd .. "'")
    end
    return found
end

return utils
