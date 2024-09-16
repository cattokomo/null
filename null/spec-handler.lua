local specfunc = require("null.specfuncs")

local handler = {
	dephandler = {}
}

function handler.dephandler.git(spec)
	
end

function handler.load()
	Deps = {}
  local specfuncs = specfunc()
  assert(loadfile("null.spec", "t", specfuncs))()
end

return handler
