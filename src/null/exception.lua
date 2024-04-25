local exception = {}

---@param err string|table
function exception.xpcall_cb(err)
    if type(err) == "string" then
        error(err)
    elseif type(err) == "table" and err.exit then
        os.exit(1)
    end
end

return exception
