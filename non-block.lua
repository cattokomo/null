
function asleep(time, func, ...)
	coroutine.wrap(function(...)
		local now = os.time()
		local thread = coroutine.create(func)
		repeat until (os.time() - now > time)
		coroutine.resume(thread, ...)
	end)(...)
end

local f = assert(io.popen("sleep 10"))

for i = 1, 10 do
	if f:read(1) == nil then
  	break
  end
  cor
end

f:close()
