-- a toy keyboard

--globals

local pages = 3

local hl = { 4, 15 }
function r() norns.script.load(norns.state.script) end

--includes

tab = require 'tabutil'
cs = require 'controlspec'

include 'orgn/lib/nest/core'
include 'orgn/lib/nest/norns'
include 'orgn/lib/nest/grid'
include 'orgn/lib/nest/txt'

tune, tune_ = include 'orgn/lib/tune/lib/tune' 
tune.setup { presets = 8, scales = include 'orgn/lib/tune/lib/scales' }

mu = require 'musicutil'
orgn = include 'orgn/lib/orgn'
demo = include 'orgn/lib/demo'

engine.name = "Orgn"

--add params

params:add { id = 'none', type = 'control', contolspec = cs.new() }
params:hide 'none'

orgn.params.synth('all', 'asr', 'linked', function() end)
orgn.params.fx('complex')

params:add_separator('tuning')
params:add {
    type='number', name='scale preset', id='scale_preset', min = 1, max = 8,
    default = 1, action = function() redraw() end
}

params:add_separator('map')

local map_name = {}
local map_id = {}

for k,v in pairs(params.params) do --read all params == lazy way
    if v.t == 3 then -- type is control
        table.insert(map_name, v.name or v.id)
        table.insert(map_id, v.id)
    end
end

local name_map = tab.invert(map_name)
-- local id_map = tab.invert(map_id)

local enc_defaults = {
    { name_map['time'], name_map['amp b'], name_map['pm c -> b'] },
    { name_map['span'], name_map['detune'], name_map['pm c -> a'] },
    { name_map['dry/wet'], name_map['samples'], name_map['bits'] },
}
local enc_map_option_id = {}

params:add_group('encoders', pages * 3)
for i = 1, pages do
    enc_map_option_id[i] = {}
    enc_defaults[i] = enc_defaults[i] or {}
    for ii = 1,3 do
        local name = 'page '..i..', E'..ii..''
        local id = string.gsub(string.gsub(name, ' ', '_'), ',', '')
        enc_map_option_id[i][ii] = id
        params:add {
            id = id, name = name, type = 'option',
            options = map_name, default = enc_defaults[i][ii] or name_map['none'],
        }        
        print(i, ii, id, params:get(id), map_name[params:get(id)])
    end
end

params:add_separator('')
params:add {
    id = 'demo start/stop', type = 'binary', behavior = 'toggle',
    action = function(v)
        if v > 0 then 
            params:delta('reset')
            demo.start() 
        else demo.stop() end
        
        grid_redraw()
    end
}

--midi keyboard
midi_device = {} -- container for connected midi devices
midi_device_names = {}
midi_target = 1

function init_midi()
  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
    local full_name = 
    table.insert(midi_device_names,"port "..i..": "..util.trim_string_to_width(midi_device[i].name,40)) -- register its name
  end
  params:add_option("midi target", "midi target",midi_device_names,1)
  params:set_action("midi target", midi_target_fn)
end

function midi_target_fn(x)
  midi_device[midi_target].event = nil
  midi_target = x
  midi_device[midi_target].event = process_midi
end


function process_midi(data)
    local msg = midi.to_msg(data)

    if msg.type == "note_on" then
        orgn.noteOn(msg.note, mu.note_num_to_freq(msg.note), ((msg.vel or 127)/127)*0.2 + 0.85)
    elseif msg.type == "note_off" then
        orgn.noteOff(msg.note)
    end
end

--ui

local pattern_lvl_64 = {
    0, ------------------ 0 empty
    function(s, d) ------ 1 empty, recording, no playback
        while true do
            d(15)
            clock.sleep(0.25)
            d(0)
            clock.sleep(0.25)
        end
    end,
    0, ------------------ 2 filled, paused
    15, ----------------- 3 filled, playback
    function(s, d) ------ 4 filled, recording, playback
        while true do
            d(15)
            clock.sleep(0.1)
            d(0)
            clock.sleep(0.1)
            d(15)
            clock.sleep(0.1)
            d(0)
            clock.sleep(0.3)
        end
    end,
}

local function grid_note(s, v, t, d, add, rem)
    local k = add or rem
    local id = k.x + (k.y * 16)
    local vel = math.random()*0.2 + 0.85

    local hz = 440 * tune.hz(params:get('scale_preset'), k.x, k.y)

    if add then orgn.noteOn(id, hz, vel)
    elseif rem then orgn.noteOff(id) end
end

local kb_lvl = function(s, x, y)
    return tune.is_tonic(params:get('scale_preset'), x, y) and { 4, 15 } or { 0, 15 }
end

local scale_focus = false

local mar = { left = 2, top = 4, right = 0, bottom = 1 }
local gap = 4
local split = { y = 64 * 3/4 }
local div = { x = { ctl = 3, gfx = 2 }, y = { ctl = 1, gfx = 2 } }
local mul = { 
    ctl = { x = (128 - mar.left - mar.right - (div.x.ctl - 1)*gap) / div.x.ctl }, 
    gfx = { 
        x = (128 - mar.left - mar.right - (gap * (div.x.gfx - 1))) / div.x.gfx,
        y = (split.y - mar.top - mar.bottom - (gap * (div.y.gfx - 1))) / div.y.gfx,
    }
}
local x = { 
    ctl = { mar.left, mar.left + mul.ctl.x, mar.left + mul.ctl.x*2, 128 - mar.right },
    gfx = { mar.left, mar.left + mul.gfx.x }
}
local y = {
    ctl = { split.y, 64 - mar.bottom },
    gfx = { mar.top, mar.top + mul.gfx.y }
}
local w = { 
    gfx = ((128 - mar.left - mar.right) / div.x.gfx) - gap*2, 
    ctl = ((128 - mar.left - mar.right) / div.x.ctl) - gap*2
}
local h = { gfx = (split.y - mar.left - mar.right) / div.y.gfx - gap*2 }

orgn.gfx.env:init(x.gfx[2], y.gfx[2], mul.gfx.x, mul.gfx.y, 'asr')
orgn.gfx.osc:init(
    { x = x.ctl[1], y = y.gfx[1], w = w.ctl, h = h.gfx }, 
    { x = x.ctl[2], y = y.gfx[1], w = w.ctl, h = h.gfx }, 
    { x = x.ctl[3], y = y.gfx[1], w = w.ctl, h = h.gfx }
)
orgn.gfx.samples:init(x.ctl[2] - gap, y.gfx[2] + gap, h.gfx)

local g = grid.connect()

local g64 = function()
    return g and g.device and g.device.cols < 16 or false
end

orgn_ = nest_ {
    -- grid = (g.device.cols==8 and grid64_ or grid128_):connect { g = g },
    play = nest_ {
        grid = g64() and nest_ {
            ratio = nest_ {
                c = _grid.number { x = { 1, 8 }, y = 1 } :param('ratio_c'),
            },
            lower = _grid.trigger { 
                x = 3, y = 2, action = function() params:delta('oct', -1) end
            },
            higher = _grid.trigger { 
                x = 4, y = 2, action = function() params:delta('oct', 1) end
            },
            mode = _grid.toggle { x = 5, y = 2, lvl = hl } :param('mode'),
            ramp = _grid.control { x = { 6, 8 }, y = 2 } :param('ramp'),
            keyboard = _grid.momentary { 
                x = { 1, 8 }, y = { 3, 8 }, 
                count = function() return params:get('voicing') == 2 and 1 or 8 end, 
                action = grid_note, lvl = kb_lvl,
                enabled = function() return not (scale_focus or demo.playing()) end,
            },
        } or nest_ {
            ratio = nest_ {
                c = _grid.number { x = { 1, 16 }, y = 1 } :param('ratio_c'),
                b = _grid.number { x = { 1, 16 }, y = 2 } :param('ratio_b'),
                a = _grid.number { x = { 1, 5 }, y = 3 } :param('ratio_a'),
            },
            lower = _grid.trigger { 
                x = 10, y = 3, action = function() params:delta('oct', -1) end
            },
            higher = _grid.trigger { 
                x = 11, y = 3, action = function() params:delta('oct', 1) end
            },
            voicing = _grid.toggle { x = 12, y = 3, lvl = hl } :param('voicing'),
            mode = _grid.toggle { x = 13, y = 3, lvl = hl } :param('mode'),
            ramp = _grid.control { x = { 14, 16 }, y = 3 } :param('ramp'),
            keyboard = _grid.momentary { 
                x = { 1, 15 }, y = { 4, 8 }, 
                count = function() return params:get('voicing') == 2 and 1 or 8 end, 
                action = grid_note, lvl = kb_lvl,
                enabled = function() return not (scale_focus or demo.playing()) end,
            },
        },
        screen = (not orgn_noscreen) and nest_ {
            page = nest_(pages):each(function(i)
                return nest_(3):each(function(ii) 
                    local id = function() return map_id[params:get(
                        enc_map_option_id[i][ii]
                    )] end
                    local xx = { x.gfx[1], x.gfx[1], x.gfx[2] }
                    local yy = { y.gfx[2] + gap, y.ctl[1], y.ctl[1] }
                    
                    return _txt.enc.control {
                        n = ii, x = xx[ii], y = yy[ii], flow = 'y',
                        value = function() return params:get(id()) end,
                        action = function(s, v) params:set(id(), v) end,
                        controlspec = function() return params:lookup_param(id()).controlspec end,
                        label = function() return map_name[
                            params:get(enc_map_option_id[i][ii])
                        ] end,
                        step = 0.001
                    }
                end):merge { enabled = function() return orgn_.screen.tab.value == i end }
            end),
            enabled = function() return not scale_focus end,
        }
    },
    scale = (not g64()) and _grid.number { 
        y = 3, x = { 6, 9 }, edge = 'both',
        lvl = function() return scale_focus and { 0, 8 } or hl end,
        v = function() return params:get('scale_preset') end,
        clock = true,
        action = function(s, v, t, d, add, rem)
            print(add, rem)
            params:set('scale_preset', v)
            grid_redraw()

            if add then clock.sleep(0.2) end
            scale_focus = add ~= nil
            redraw()
        end
    } or nil,
    screen = (not orgn_noscreen) and nest_ {
        gfx = _screen {
            redraw = function() 
                orgn.gfx:draw()
                return true -- return high dirty flag to redraw every frame
            end
        },
        tab = _txt.key.option {
            n = { 2, 3 }, x = { { 118 }, { 122 }, { 126 } }, y = 52, 
            align = { 'right', 'bottom' },
            font_size = 16, margin = 3,
            options = { '.', '.', '.' },
        },
        enabled = function() return not scale_focus end,
    },
    tune = tune_ {
        left = 2, top = 4,
    } :each(function(i, v) 
        v.enabled = function() 
            return (not demo.playing()) and scale_focus and (i == params:get('scale_preset'))
        end
    end),
    demo = _grid.affordance {
        input = false,
        redraw = demo.redraw,
        enabled = demo.playing
    },
    pattern = g64() and _grid.pattern {
        x = { 1, 2 }, y = 2, target = function(s) return s.p.play end,
        lvl = pattern_lvl_64
    } or _grid.pattern {
        x = 16, y = { 4, 8 }, target = function(s) return s.p.play end,
    },
    focus = _key.momentary {
        n = 1, 
        action = function(s, v) 
            scale_focus = v > 0 
            redraw(); grid_redraw()
        end,
    },
} :connect { g = g, screen = screen, key = key, enc = enc }

function init()
    orgn.init()
    init_midi()
    params:read()
    params:set('demo start/stop', 0)
    params:bang()
    orgn_:init()
end

function cleanup() 
    params:write()
end
