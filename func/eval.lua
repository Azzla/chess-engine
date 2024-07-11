local Evaluation = {}

function Evaluation:init(x,y,h,board)
	self.x,self.y = x,y
	self.bar_height = h
	self.bar_width = 20
	self.bar_bg = {1,1,1,1}--background is white, we adjust black based on the eval
	self.bar_fg = {0,0,0,1}

	self.b_height = h/2
	self.b_target_height = h/2
	self.tween_t = 0.5
	
	self:eval(board)
end

function Evaluation:update(dt)
	self.tween:update(dt)
end

function Evaluation:draw()
	love.graphics.setColor(self.bar_bg)
	love.graphics.rectangle(
		'fill',
		self.x,self.y,
		self.bar_width,
		self.bar_height
	)
	love.graphics.setColor(self.bar_fg)
	love.graphics.rectangle(
		'fill',
		self.x,self.y,
		self.bar_width,
		self.b_height
	)
end

function Evaluation:eval(board)
	local white_eval = 0
	local black_eval = 0

	for i,piece in ipairs(board) do
		if piece ~= 0 then --its not a blank square
			if piece.color == 1 then white_eval = white_eval + piece.info.value
			else black_eval = black_eval + piece.info.value end
		end
	end

	--rough, naive evaluation here
	self.b_target_height = math.floor(black_eval/white_eval*self.bar_height/2)
	if white_eval > black_eval + 200 then self.b_target_height = self.b_target_height - 30 end
	if white_eval > black_eval + 400 then self.b_target_height = self.b_target_height - 50 end
	if white_eval > black_eval + 600 then self.b_target_height = self.b_target_height - 70 end
	if white_eval > black_eval + 800 then self.b_target_height = self.b_target_height - 90 end
	if self.b_target_height <= 0 then self.b_target_height = 0 end
	if self.b_target_height >= self.bar_height then self.b_target_height = self.bar_height end

	self.tween = Tween.new(self.tween_t, self, {b_height=self.b_target_height})
end

return Evaluation