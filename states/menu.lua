local Menu = {}
local BTN_WIDTH = 350

function Menu:enter(previous)
	self.ui = SUIT.new()
	self.buttons = {'play', 'options', 'quit'}
	self.funcs = {
		[1] = function() StateManager:enter(States.game) end,
		[2] = function() StateManager:enter(States.options) end,
		[3] = function() love.event.quit() end
	}
end

function Menu:update(dt)
	self.ui.layout:reset(Options.w/2 - BTN_WIDTH/2,250)
	for i,btn in ipairs(self.buttons) do
		local button = self.ui:Button(
			btn,
			self.ui.layout:row(BTN_WIDTH, 100)
		)
		if button.hit then self.funcs[i]() end
	end
end

function Menu:draw()
	love.graphics.setFont(Font_64)
	love.graphics.printf("Chess", 0, 50, Options.w, "center")
	self.ui:draw()
end

function Menu:leave(next)

end

return Menu