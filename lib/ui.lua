function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

local pattern, mpat = {}, {}
for i = 1,8 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

local view_matrix = false
local view = {}
local vertical = true
local alt = false

local App = {}

function App.grid(wide, offset)
    local varibright = true
    local shaded = varibright and { 4, 15 } or { 0, 15 }
    local mid = varibright and 4 or 15
    local mid2 = varibright and 8 or 15

    --TODO: only enable when arc is connected AND wide
    view_matrix = wide

    view = view_matrix and {
        { 1, 0, 0, 0 },
        { 1, 0, 0, 0 },
        { 1, 0, 0, 0 },
        { 1, 0, 0, 0 },
    } or { 0, 0, 0, 0 }

    local function Voice(n)
        local top, bottom = n, n + ndls.voices

        local _phase = Components.grid.phase()
        
        local _params = {}
        _params.rec = to.pattern(mpat, 'rec '..n, Grid.toggle, function()
            return {
                x = 1, y = bottom, 
                state = of.param('rec '..n),
            }
        end)
        _params.play = to.pattern(mpat, 'play '..n, Grid.toggle, function()
            return {
                x = 2, y = bottom, lvl = shaded,
                state = {
                    sc.punch_in[ndls.zone[n]].recorded and params:get('play '..n) or 0,
                    function(v)
                        local recorded = sc.punch_in[ndls.zone[n]].recorded
                        local recording = sc.punch_in[ndls.zone[n]].recording

                        if recorded or recording then 
                            params:set('play '..n, v)
                        end
                    end
                },
            }
        end)
        _params.zone = to.pattern(mpat, 'zone '..n, Grid.number, function()
            return {
                x = { 3, 6 }, y = bottom,
                state = {
                    ndls.zone[n],
                    function(v) ndls.zone:set(v, n) end
                }
            }
        end)
        if wide then
            _params.send = to.pattern(mpat, 'send '..n, Grid.toggle, function()
                return {
                    x = 14, y = bottom, lvl = shaded,
                    state = of.param('send '..n),
                }
            end)
            _params.ret = to.pattern(mpat, 'return '..n, Grid.toggle, function()
                return {
                    x = 15, y = bottom, lvl = shaded,
                    state = of.param('return '..n),
                }
            end)
        end
        _params.rev = to.pattern(mpat, 'rev '..n, Grid.toggle, function()
            return {
                x = wide and 5 or 2, y = top, edge = 'falling', lvl = shaded,
                state = { params:get('rev '..n) },
                action = function(v, t)
                    sc.slew(n, (t < 0.2) and 0.025 or t)
                    params:set('rev '..n, v)
                end,
            }
        end)
        do
            local off = wide and 6 or 4
            _params.rate = to.pattern(mpat, 'rate '..n, Grid.number, function()
                return {
                    x = wide and { 6, 13 } or { 3, 8 }, y = top, filtersame = true,
                    state = { params:get('rate '..n) + off },
                    action = function(v, t)
                        sc.slew(n, t)
                        params:set('rate '..n, v - off)
                    end,
                }
            end)
        end

        local _cf_assign = { Grid.toggle(), Grid.toggle() }

        return function()
            _cf_assign[1]{
                x = wide and 14 or 7, y = wide and top or bottom, 
                lvl = shaded,
                state = { params:get('crossfade assign '..n) == 2 and 1 or 0 },
                action = function(v)
                    if v == 1 then
                        params:set('crossfade assign '..n, 2)
                    elseif v == 0 then
                        params:set('crossfade assign '..n, 1)
                    end
                end
            }
            _cf_assign[2]{
                x = wide and 15 or 8, y = wide and top or bottom, 
                lvl = shaded,
                state = { params:get('crossfade assign '..n) == 3 and 1 or 0 },
                action = function(v)
                    if v == 1 then
                        params:set('crossfade assign '..n, 3)
                    elseif v == 0 then
                        params:set('crossfade assign '..n, 1)
                    end
                end
            }

            for _, _param in pairs(_params) do _param() end
            
            if sc.lvlmx[n].play == 1 and sc.punch_in[ndls.zone[n]].recorded then
                _phase{ 
                    x = wide and { 1, 16 } or { 1, 8 }, y = top,
                    phase = sc.phase[n].rel,
                }
            end

        end
    end

    local _view = wide and Components.grid.view() or Grid.toggle()
    
    _voices = {}
    for i = 1, ndls.voices do
        _voices[i] = Voice(i)
    end

    local _patrec = PatternRecorder()

    return function()
        if wide then
            _view{
                x = 1, y = 1, lvl = 15,
                view = view,
                vertical = { vertical, function(v) vertical = v end },
                action = nest.arc.make_dirty
            }
        else
            _view{
                x = 1, y = { 1, 4 }, lvl = 15, count = { 0, 1 },
                state = { 
                    view, 
                    function(v) 
                        view = v 
                        
                        vertical = true
                        for y = 1,ndls.voices do
                            if view[y] > 0 then
                                vertical = false
                            end
                        end
                    end 
                }
            }
        end
        
        for i, _voice in ipairs(_voices) do
            _voice{}
        end
        
        _patrec{
            x = 16, y = { 1, 8 }, pattern = pattern,
        }
    end
end

function App.arc(map)
    local Destinations = {}

    function Destinations.vol(n, x)
        local _num = to.pattern(mpat, 'vol '..n, Arc.number, function() 
            return {
                n = tonumber(vertical and n or x),
                sens = 0.25, max = 2.5, cycle = 1.5,
                state = of.param('vol '..n),
            }
        end)

        return function() _num() end
    end

    function Destinations.cut(n, x)
        local _cut = to.pattern(mpat, 'cut '..n, Arc.control, function() 
            return {
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 }, sens = 0.25, 
                redraw_enabled = false,
                controlspec = of.controlspec('cut '..n),
                state = of.param('cut '..n),
            }
        end)

        local _filt = Components.arc.filter()

        local _type = to.pattern(mpat, 'type '..n, Arc.option, function() 
            return {
                n = tonumber(vertical and n or x),
                options = 4, sens = 1/64,
                x = { 27, 41 }, lvl = 12,
                --[[
                state = {
                    params:get('type '..n),
                    function(v) params:set('type '..n, v//1) end
                },
                --]]
                action = function(v) params:set('type '..n, v//1) end
            }
        end)

        return function() 
            _filt{
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 },
                type = params:get('type '..n),
                cut = params:get('cut '..n),
            }

            if alt then 
                _type()
            else
                _cut() 
            end
        end
    end

    function Destinations.st(n, x)
        _st = Components.arc.st(mpat)

        return function() 
            if sc.punch_in[ndls.zone[n]].recorded then
                _st{
                    n = tonumber(vertical and n or x),
                    x = { 33, 64+32 }, lvl = { 4, 15 },
                    reg = sc.get_zoom(n) and reg.zoom or reg.play, 
                    nreg = n,
                    phase = sc.phase[n].rel,
                    show_phase = sc.lvlmx[n].play == 1,
                    nudge = alt,
                    sens = 1/1000,
                }
            end
        end
    end

    function Destinations.len(n, x)
        _len = Components.arc.len(mpat)

        return function() 
            if sc.punch_in[ndls.zone[n]].recorded then
                _len{
                    n = tonumber(vertical and n or x),
                    x = { 33, 64+32 }, 
                    reg = sc.get_zoom(n) and reg.zoom or reg.play, 
                    nreg = n,
                    phase = sc.phase[n].rel,
                    show_phase = sc.lvlmx[n].play == 1,
                    nudge = alt,
                    sens = 1/1000,
                    lvl_st = alt and 15 or 4,
                    lvl_en = alt and 4 or 15,
                    lvl_ph = 4,
                }
            end
        end
    end

    local _params = {}
    for y = 1,4 do --track
        _params[y] = {}

        for x = 1,4 do --map item

            _params[y][x] = Destinations[map[x]](y, x)
        end
    end

    return function()
        if view_matrix then
            for y = 1,4 do for x = 1,4 do
                if view[y][x] > 0 then
                    _params[y][x]()
                end
            end end
        else
            if not vertical then
                for i = 1,ndls.voices do
                    local y = ndls.voices - i + 1
                    if view[i] > 0 then
                        for x = 1,4 do
                            _params[y][x]()
                        end
                        break
                    end
                end
            else
                for y = 1,4 do
                    _params[y][1]()
                end
            end
        end
    end
end

function App.norns()
    local _alt = Key.momentary()

    local _crossfader
    do
        local x, y, width, height = 2, 2, 128 - 4, 3
        local value = params:get('crossfade')
        local min_value = params:lookup_param('crossfade').controlspec.minval
        local max_value = params:lookup_param('crossfade').controlspec.maxval
        local markers = { 0 }
        local direction = 'right'
        _crossfader = Components.norns.slider(
            x, y, width, height, value, min_value, max_value, markers, direction
        )
    end

    return function()
        _alt{
            n = 1, 
            state = {
                alt and 1 or 0,
                function(v)
                    alt = v==1
                    nest.arc.make_dirty()
                end
            }
        }
        _crossfader{
            n = 1,
            state = of.param('crossfade')
        }
    end
end

local _app = {
    grid = App.grid(false, 8),
    arc = App.arc({ 'vol', 'cut', 'st', 'len' }),
    norns = App.norns(),
}

nest.connect_grid(_app.grid, grid.connect(), 60)
nest.connect_arc(_app.arc, arc.connect(), 90)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns)
