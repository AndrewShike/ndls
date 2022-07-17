local function App(args)
    local rotated = args.rotated
    local wide = args.grid_wide
    local arc2 = args.arc2

    local function Cut(n, x)
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

        return function() 
            _cut()
            _filt{
                n = tonumber(vertical and n or x),
                x = { 42, 24+64 },
                type = params:get('type '..n),
                cut = params:get('cut '..n),
            }
        end
    end

    local function Win(n, x)
        _st = Components.arc.st(mpat)

        return function() 
            local b = sc.buffer[n]

            _st{
                n = tonumber(vertical and n or x),
                x = { 33, 64+32 }, lvl = { 4, 15 },
                phase = sc.phase[n].rel,
                show_phase = sc.lvlmx[n].play == 1,
                sens = 1/1000,
                st = { get_start(n), get_set_start(n) },
                en = { get_end(n), get_set_end(n) },
                recording = sc.punch_in[b].recording,
                recorded = sc.punch_in[b].recorded,
                reg = reg.rec[b],
                rotated = rotated,
                --rec_flag = params:get('rec '..n)
            }
        end
    end

    local function End(n, x)
        _len = Components.arc.len(mpat)

        return function() 
            local b = sc.buffer[n]

            _len{
                n = tonumber(vertical and n or x),
                x = { 33, 64+32 }, 
                phase = sc.phase[n].rel,
                show_phase = sc.lvlmx[n].play == 1,
                nudge = alt,
                sens = 1/1000,
                lvl_st = alt and 15 or 4,
                lvl_en = alt and 4 or 15,
                lvl_ph = 4,
                st = { get_start(n), get_set_start(n) },
                en = { get_end(n), get_set_end(n) },
                recording = sc.punch_in[b].recording,
                recorded = sc.punch_in[b].recorded,
                reg = reg.rec[b],
                rotated = rotated,
                --rec_flag = params:get('rec '..n)
            }
        end
    end

    local function Vol(n, x)
        local _vol = to.pattern(mpat, 'vol '..n, Arc.number, function() 
            return {
                n = x,
                sens = 0.25, max = 2.5, cycle = 1.5,
                state = of.param('vol '..n),
                lvl = view.track == n and 15 or 4,
            }
        end)

        return function() _vol() end
    end

    local Pages = {}
    function Pages.mix()
        local _vols = {}
        for n = 1,4 do
            _vols[n] = Vol(n, n)
        end

        return function() 
            for _,_vol in ipairs(_vols) do _vol() end
        end
    end

    function Pages.window(n)
        local _vol = Vol(n, 1)
        local _pan = to.pattern(mpat, 'pan '..n, Arc.control, function()
            return {
                n = 2,
                state = of.param('pan '..n),
                controlspec = of.controlspec('pan '..n),
            }
        end)
        local _win = Win(n, 3)
        local _end = End(n, 4)

        return function()
            _vol(); _pan(); _win(); _end()
        end
    end

    function Pages.filter(n)
        local _cut = Cut(n, 1)
        local _q = to.pattern(mpat, 'q '..n, Arc.control, function()
            return {
                n = 2,
                state = of.param('q '..n),
                controlspec = of.controlspec('q '..n),
                lvl = { 4, 4, 15 },
                x = { 42,  56 },
            }
        end)
        local _win = Win(n, 3)
        local _end = End(n, 4)

        return function()
            _cut(); _q(); _win(); _end()
        end
    end

    local _pages = {}
    _pages.mix = Pages.mix()
    _pages.window = {}
    _pages.filter = {}

    for n = 1, voices do
        _pages.window[n] = Pages.window(n)
        _pages.filter[n] = Pages.filter(n)
    end

    return function()
        if not arc2 then
            if view.page == 1 then
                _pages.mix()
            elseif view.page == 2 then
                _pages.window[view.track]()
            elseif view.page == 3 then
                _pages.filter[view.track]()
            elseif view.page == 4 then
            end
        end
    end
end

return App
