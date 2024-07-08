local Timer = {}
Timer.__index = Timer

local function next_loop(f)
	f.count = f.count - 1
	f.elapsed = 0
	f.co = coroutine.create(function()
		f.func()
	end)
end

function Timer:after(t, lambda)
	local handle = {
		co = coroutine.create(function()
			lambda()
		end),
		count = 0,
		time = t,
		elapsed = 0
	}
	self.suspended[handle] = handle
	return handle
end

function Timer:every(t, lambda, count)
	local handle = {
		co = coroutine.create(function()
			lambda()
		end),
		count = count or math.huge, --optional number of execution repeats
		func = lambda,
		time = t,
		elapsed = 0
	}
	self.suspended[handle] = handle
	return handle
end

function Timer:update(dt)
	for f in pairs(self.suspended) do
		f.elapsed = f.elapsed + dt

		if f.elapsed >= f.time then
			local ran, error = coroutine.resume(f.co)
			assert(ran, error) --propogates and throws error if something went wrong during thread execution.

			if f.count > 1 then next_loop(f)
			else
				self.suspended[f] = nil
			end
		end
	end
end

function Timer:cancel(handle)
	self.suspended[handle] = nil
end

function Timer:clear()
	self.suspended = {}
end

function Timer.new()
	return setmetatable({suspended = {}}, Timer)
end

return Timer.new()