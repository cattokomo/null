local console = require('nelua.utils.console')

local colors = console.colors

-- forward declaration
local module

---@param ... string
local function err(...)
    console.logex(io.stderr, colors.error, '[null] ' .. colors.reset .. table.concat({ ... }, ' '))
end

---@param ... string
local function warn(...)
    console.logex(io.stderr, colors.warn, '[null] ' .. colors.reset .. table.concat({ ... }, ' '))
end

---@param ... string
local function info(...)
    console.logex(io.stdout, colors.cyan .. colors.bright, '[null] ' .. colors.reset .. table.concat({ ... }, ' '))
end

---@param name string
---@param ... string
local function err_dep(name, ...)
    err(colors.cyan .. name .. ':' .. colors.reset, ...)
end

---@param name string
---@param ... string
local function warn_dep(name, ...)
    warn(colors.cyan .. name .. ':' .. colors.reset, ...)
end

---@param name string
---@param ... string
local function info_dep(name, ...)
    info(colors.cyan .. name .. ':' .. colors.reset, ...)
end

return {
    err = err,
    warn = warn,
    info = info,
    err_dep = err_dep,
    warn_dep = warn_dep,
    info_dep = info_dep,
}
