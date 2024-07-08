io.stdout:setvbuf('no')
local Roomy		= require('lib/roomy')
StateManager	= Roomy.new()
SUIT			= require('lib/suit')
Scribe			= require('lib/scribe')
Class			= require('lib/class')
Timer			= require('lib/timer')
Options			= require('options')
States			= Options.getStates()
ChessFont		= nil
Font_64,Font_32,Font_16,Font_8 = nil,nil,nil,nil
Colors			= {black = {0,0,0,1}, gray = {0.5,0.5,0.5,1}, white = {1,1,1,1}}
Assets			= nil
SFX				= nil
Unit_Info		= require('dicts/units')
Levels			= require('dicts/levels')

local function require_assets()
	return {
		square_light = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/square_light.png'),
		square_dark = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/square_dark.png'),
		square_light_v3 = love.graphics.newImage('assets/chess_set/board_squares/square_light_v3.png'),
		square_dark_v3 = love.graphics.newImage('assets/chess_set/board_squares/square_dark_v3.png'),
		w = { --white pieces
			pawn = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/w_pawn_1x_ns.png'),
			knight = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/w_knight_1x_ns.png'),
			bishop = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/w_bishop_1x_ns.png'),
			rook = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/w_rook_1x_ns.png'),
			king = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/w_king_1x_ns.png'),
			queen = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/w_queen_1x_ns.png')
		},
		b = { --black pieces
			pawn = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/b_pawn_1x_ns.png'),
			knight = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/b_knight_1x_ns.png'),
			bishop = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/b_bishop_1x_ns.png'),
			rook = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/b_rook_1x_ns.png'),
			king = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/b_king_1x_ns.png'),
			queen = love.graphics.newImage('assets/chess_set/PNGs/No Shadow/1x/b_queen_1x_ns.png')
		}
	}
end

local function require_sounds()
	return {
		promote = love.audio.newSource('assets/sfx/promote.mp3', 'static'),
		move = love.audio.newSource('assets/sfx/move-self.mp3', 'static'),
		capture = love.audio.newSource('assets/sfx/capture.mp3', 'static'),
		castle = love.audio.newSource('assets/sfx/castle.mp3', 'static'),
		check = love.audio.newSource('assets/sfx/move-check.mp3', 'static')
	}
end

function love.load()
	Font_64 = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 64)
	Font_32 = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 32)
	Font_16 = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 16)
	Font_8  = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 8)
	ChessFont = love.graphics.newFont('assets/font/CHEQ_TT.ttf', 64)
	Assets = require_assets()
	SFX = require_sounds()

	love.window.setMode(Options.w, Options.h, Options.flags)
	Options.w,Options.h = love.graphics.getDimensions()
	SUIT.theme.color = {
		normal  = {bg = Colors.black, fg = Colors.white},
		hovered = {bg = Colors.gray, fg = Colors.white},
		active  = {bg = Colors.white, fg = Colors.black}
	}
	SUIT.theme.cornerRadius = 0

	StateManager:hook()
	StateManager:enter(States.menu)
end

function love.resize(w,h)
	Options.w = w; Options.h = h;
end