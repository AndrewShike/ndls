local voices, zones = ndls.voices, ndls.zones

-- softcut utilities
local sc = {
    phase = {
        { rel = 0, abs = 0 },
        set = function(s, n, v)
            s[n].abs = v
            s[n].rel = reg.rec:phase_relative(n*2, v, 'fraction')
        end
    },
    lvlmx = {
        { vol = 1, play = 0, send = 1, pan = 0 },         
        update = function(s, n)
            local v, p = s[n].vol * s[n].play, s[n].pan
            softcut.level(n, v * ((p > 0) and 1 - p or 1))
            --send
        end
    },
    oldmx = {
        { old = 1, rec = 0 },
        update = function(s, n)
            sc.send('rec_level', n, s[n].rec)
            sc.send('pre_level', n, (s[n].rec == 0) and 1 or s[n].old)
        end
    },
    ratemx = {
            { oct = 1, bnd = 1, dir = 1, rate = 1 },
            update = function(s, n)
                s[n].rate = 2^s[n].oct * 2^(s[n].bnd) * s[n].dir
                sc.send('rate', n, s[n].rate)
            end
    },
    inmx = { 
        { 1, 1 }, --lvl L, lvl R
        update = function(s, n)
            for i = 1,2 do softcut.level_input_cut(i, n, s[n][i]) end
        end
    }
}

--shallow copy first index for each voice for objects above
for k,o in pairs(sc) do
    for i = 2, voices do
        o[i] = {}
        for l,v in pairs(o[1]) do
            o[i][l] = v
        end
    end
end

--softcut buffer regions
local reg = {}
reg.blank = cartographer.divide(cartographer.buffer[1], zones)
reg.rec = cartographer.subloop(reg.blank)
reg.play = cartographer.subloop(reg.rec)

sc.setup = function()
    audio.level_cut(1)
    audio.level_adc_cut(1)

    for i = 1, voices do
        softcut.enable(i, 1)
        softcut.rec(i, 1)
        softcut.play(i, 1)
        softcut.loop(i, 1)
        softcut.level_slew_time(i, 0.1)
        softcut.recpre_slew_time(i, 0.1)
        softcut.rate(i, 1)
        softcut.post_filter_dry(i, 0)
        
        softcut.level_input_cut(1, i, 1)
        softcut.level_input_cut(2, i, 1)
        
        sc.slew(i, 0.2)
    end
    for i = 1, 2 do
        local l, r = i*2 - 1, i*2
        
        softcut.phase_quant(i*2 - 1, 1/60)
        
        --adjust punch_in time quantum based on rate
        reg.rec[i].rate_callback = function() 
            return sc.ratemx[i].rate
        end
    end

    softcut.event_position(function(i, ph)
        sc.phase:set(i, ph)
    end)
end

-- scoot = function()
--     reg.play:position(2, 0)
--     reg.play:position(4, 0)
-- end,

--more utilities

sc.send = function(command, ...)
    softcut[command](...)
end

sc.slew = function(n, t)
    local st = (2 + (math.random() * 0.5)) * (t or 0)
    sc.send('rate_slew_time', n, st)
    return st
end

sc.fade = function(n, length)
    sc.send('fade_time', n, math.min(0.01, length))
end

sc.zone = {
    1, 2, 3, 4, --[voice] = zone
    update = function(s, n)
        cartographer.assign(reg.play[s[n]], n)
    end
}
        
sc.punch_in = {
    --indexed by zone
    { recording = false, recorded = false, manual = false, play = 0, t = 0, tap_blink = 0, tap_clock = nil, tap_buf = {}, big = false },

    update_play = function(s, buf)
        sc.lvlmx[buf].play = s[buf].play
        sc.lvlmx:update(buf)
    end,
    big = function(s, n, v)
        local buf = sc.buf[n]
        if v > 0.2 then s[buf].big = true end
    end,
    toggle = function(s, n, v)
        local buf = sc.buf[n]
        local i = buf

        if n ~= buf then
            sc.oldmx[n].rec = v; sc.oldmx:update(n)
        elseif s[buf].recorded then
            sc.oldmx[buf].rec = v; sc.oldmx:update(buf)
        elseif v == 1 then
            reg.blank[buf]:set_length(16777216 / 48000 / 2)
            reg.rec[buf]:punch_in()

            sc.oldmx[buf].rec = 1; sc.oldmx:update(buf)

            s[buf].manual = false
            wrms.preset:set('manual '..buf, s[buf].manual)

            s[buf].recording = true
        elseif s[buf].recording then
            sc.oldmx[buf].rec = 0; sc.oldmx:update(buf)
            s[buf].play = 1; s:update_play(buf)
        
            reg.rec[buf]:punch_out()

            s[buf].recorded = true
            s[buf].big = true
            s[buf].recording = false

            wrms.gfx:wake(buf)
        end
    end,
    manual = function(s, n)
        local buf = sc.buf[n]
        if not s[buf].recorded then
            reg.blank[buf]:set_length(s.delay_size)
            reg.rec[buf]:set_length(1, 'fraction')
            
            s[buf].manual = true
            wrms.preset:set('manual '..buf, s[buf].manual)

            sc.oldmx[buf].rec = 1; sc.oldmx:update(buf)
            s[buf].play = 1; s:update_play(buf)

            s[buf].recorded = true
            wrms.gfx:wake(buf)
        end
    end,
    untap = function(s, n)
        local buf = sc.buf[n]

        s[buf].tap_buf = {}
        if s[buf].tap_clock then clock.cancel(s[buf].tap_clock) end
        s[buf].tap_clock = nil
        s[buf].tap_blink = 0
    end,
    tap = function(s, n, t)
        local buf = sc.buf[n]

        if t < 1 and t > 0 then
            table.insert(s[buf].tap_buf, t)
            if #s[buf].tap_buf > 2 then table.remove(s[buf].tap_buf, 1) end
            local avg = 0
            for i,v in ipairs(s[buf].tap_buf) do avg = avg + v end
            avg = avg / #s[buf].tap_buf

            reg.play:set_length(n*2, avg)
            sc.punch_in:big(n, avg)

            if s[buf].tap_clock then clock.cancel(s[buf].tap_clock) end
            s[buf].tap_clock = clock.run(function() 
                while true do
                    s[buf].tap_blink = 1
                    clock.sleep(avg*0.5)
                    s[buf].tap_blink = 0
                    clock.sleep(avg*0.5)
                end
            end)
        else s:untap(n) end
    end,
    clear = function(s, n)
        local buf = sc.buf[n]
        local i = buf * 2

        s[buf].play = 0; s:update_play(buf)
        reg.rec[buf]:position(0)
        reg.rec[buf]:clear()
        reg.rec[buf]:punch_out()


        s[buf].recorded = false
        s[buf].recording = false
        s[buf].big = false
        s[buf].manual = false
        s:untap(n)

        reg.rec[buf]:set_length(1, 'fraction')
        for j = 1,2 do
            reg.play[buf][j]:set_length(0)
        end
            
        wrms.gfx:sleep(buf)
    end,
    save = function(s)
        local data = {}
        for i,v in ipairs(s) do data[i] = s[i].manual end
        return data
    end,
    load = function(s, data)
        for i,v in ipairs(data) do
            s[i].manual = v
            if v==true then 
                s:manual(i)
                s:big(i, reg.play[1][1]:get_length())
            else 
                --s:clear(i) 
                if sc.buf[i]==i then params:delta('clear '..i) end
            end
        end
    end
}

--punch_in shallow copy first index for each zone
for i = 2, zones do
    sc.punch_in[i] = {}
    for l,v in pairs(sc.punch_in[1]) do
        sc.punch_in[i][i][l] = v
    end
end

return sc, reg
