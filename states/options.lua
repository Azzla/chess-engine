local Opts = {}
local BTN_WIDTH = 350

function Opts:enter(previous)
	self.ui = SUIT.new()

	self.checkboxes = {
		{text = ' AI Plays Black', checked = Options.ai_black},
		{text = ' Click-Moves', checked = Options.click_move},
		{text = ' Allow Undo', checked = Options.allow_undo},
		{text = ' Auto-Queen Promotions', checked = Options.auto_queen}
	}
	self.payload = {
		[1] = 'ai_black',
		[2] = 'click_move',
		[3] = 'allow_undo',
		[4] = 'auto_queen'
	}
end

function Opts:update(dt)
	self.ui.layout:reset(Options.w/2 - BTN_WIDTH/2,250)
	for i,chk in ipairs(self.checkboxes) do
		self.ui:Checkbox(chk, {font=Font_16}, self.ui.layout:row(BTN_WIDTH, 50))
		local opt = self.payload[i]
		if chk.checked then Options[opt] = true else Options[opt] = false end
	end

	self.ui.layout:reset(Options.w/2 - BTN_WIDTH/2,Options.h-300)
	local back_btn = self.ui:Button("BACK", {font=Font_64}, self.ui.layout:row(BTN_WIDTH, 100))
	if back_btn.hit then StateManager:enter(States.menu) end
end

function Opts:draw()
	love.graphics.setFont(Font_64)
	love.graphics.printf("Options", 0, 50, Options.w, "center")
	self.ui:draw()
end

return Opts