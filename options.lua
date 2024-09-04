local Options = {}

Options.no_antialiasing 	= true
Options.w 					= 1520
Options.h 					= 1080
Options.window_width		= 1920
Options.full_width			= 2560
Options.flags				= {}
Options.flags.fullscreen	= false
Options.flags.resizable		= false
Options.flags.msaa			= 16
Options.flags.vsync			= false
Options.enable_profiler 	= false
Options.profiler_lines		= 16
Options.profiler_path		= [[K:\Projects\Chess\report.txt]]
Options.enable_save			= false
Options.font_path			= ''
Options.reticle_path		= ''
Options.reticle_scale		= 1
Options.use_custom_reticle	= false
Options.enable_shaders		= false
Options.display_attacks		= false

--Game-Options--
Options.ai_black			= false
Options.click_move			= false
Options.auto_queen			= false
Options.allow_undo			= false

function Options.getStates()
	return {
		menu	= require('states.menu'),
		options	= require('states.options'),
		game	= require('states.game'),
		tests	= require('states.tests')
	}
end

return Options