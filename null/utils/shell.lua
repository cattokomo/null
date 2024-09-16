local shell = {}

function shell.quote(s)
	return "'" .. s .. "'"
end

return shell
