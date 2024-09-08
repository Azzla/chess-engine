io.stdout:setvbuf('no')
local Roomy		= require('lib/roomy')
StateManager	= Roomy.new()
SUIT			= require('lib/suit')
Scribe			= require('lib/scribe')
Class			= require('lib/class')
Timer			= require('lib/timer')
Tween			= require('lib/tween')
Profiler		= require('lib/profile')
				  require('lib/slam')
Options			= require('options')
States			= nil
ChessFont		= nil
Font_64,Font_32,Font_16,Font_8 = nil,nil,nil,nil
Colors			= {
	light = {love.math.colorFromBytes(235,236,208,255)},
	dark = {.2,.25,.2,1},
	highlight_r = {love.math.colorFromBytes(235,97,80,204)},
	highlight_y = {love.math.colorFromBytes(255,255,51,127)}
}
Assets			= nil
SFX				= nil
Positions		= require('dicts/positions')

local function require_assets()
	return {
		w = { --white pieces
			pawn = love.graphics.newImage('assets/pieces/No Shadow/1x/w_pawn_1x_ns.png'),
			knight = love.graphics.newImage('assets/pieces/No Shadow/1x/w_knight_1x_ns.png'),
			bishop = love.graphics.newImage('assets/pieces/No Shadow/1x/w_bishop_1x_ns.png'),
			rook = love.graphics.newImage('assets/pieces/No Shadow/1x/w_rook_1x_ns.png'),
			king = love.graphics.newImage('assets/pieces/No Shadow/1x/w_king_1x_ns.png'),
			queen = love.graphics.newImage('assets/pieces/No Shadow/1x/w_queen_1x_ns.png')
		},
		b = { --black pieces
			pawn = love.graphics.newImage('assets/pieces/No Shadow/1x/b_pawn_1x_ns.png'),
			knight = love.graphics.newImage('assets/pieces/No Shadow/1x/b_knight_1x_ns.png'),
			bishop = love.graphics.newImage('assets/pieces/No Shadow/1x/b_bishop_1x_ns.png'),
			rook = love.graphics.newImage('assets/pieces/No Shadow/1x/b_rook_1x_ns.png'),
			king = love.graphics.newImage('assets/pieces/No Shadow/1x/b_king_1x_ns.png'),
			queen = love.graphics.newImage('assets/pieces/No Shadow/1x/b_queen_1x_ns.png')
		}
	}
end

local function require_sounds()
	return {
		promote = love.audio.newSource('assets/sfx/promote.mp3', 'static'),
		move = love.audio.newSource('assets/sfx/move-self.mp3', 'static'),
		capture = love.audio.newSource('assets/sfx/capture.mp3', 'static'),
		castle = love.audio.newSource('assets/sfx/castle.mp3', 'static'),
		check = love.audio.newSource('assets/sfx/move-check.mp3', 'static'),
		checkmate = love.audio.newSource('assets/sfx/checkmate.mp3', 'static')
	}
end

--debugging tool
function dump(o)
if type(o) == 'table' then
local s = '{ '
for k,v in pairs(o) do
if type(k) ~= 'number' then k = '"'..k..'"' end
s = s .. '['..k..'] = ' .. dump(v) .. ','
end
return s .. '} '
else
return tostring(o)
end
end

--utils
function table_shallow_copy(t) return {unpack(t)} end
function table_contains(table, element)
	for _, value in pairs(table) do
		if value == element then return true end
	end
	return false
end

function table_add(table, val)
	for i,value in ipairs(table) do table[i] = value + val end
	return table
end

function generate_report(report)
  local path = Options.profiler_path
  local file = io.open(path, 'w')
  file:write(report)
  file:close()
end

function love.load()
	Font_64 = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 64)
	Font_32 = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 32)
	Font_16 = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 16)
	Font_8  = love.graphics.newFont('assets/font/LEMONMILK-Bold.otf', 8)
	ChessFont = love.graphics.newFont('assets/font/CHEQ_TT.ttf', 64)
	Assets = require_assets()
	SFX = require_sounds()
	States = Options.getStates()

	love.window.setMode(Options.w, Options.h, Options.flags)
	Options.w,Options.h = love.graphics.getDimensions()
	SUIT.theme.color = {
		normal  = {bg = Colors.dark, fg = Colors.light},
		hovered = {bg = Colors.light, fg = Colors.dark},
		active  = {bg = Colors.light, fg = Colors.highlight_r}
	}
	SUIT.theme.cornerRadius = 0

	StateManager:hook()
	StateManager:enter(States.menu)
end

function love.resize(w,h)
	Options.w = w; Options.h = h;
end