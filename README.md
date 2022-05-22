# ndls

endless and/or noodles

4-track asyncronous looper, delay, loop sampler. pattern memory & performace oriented. and it's ~ bendy ~

## hardware

norns + one or more of the following:
- midi footswitch
- grid
- arc

## grid

![documentation image](doc/ndls.png)

## norns

mixer
- E1: crossfader
- E2-E3: mix parameter
  - level
  - pan
  - crossfader assign
- K2: track focus 1+2 / 3+4
- K3: parameter select

track focus
- K2-3: page
- pages
  - v
    - E1: pan
    - E2: vol
    - E3: old
  - s
    - E1: window
    - E2: start
    - E3: end
  - f
    - E1: tilt
    - E2: freq
    - E3: quality
  - p
    - E1: direction
    - E2: rate
    - E3: bend
  - z
    - E1: zone
    - E2: send
    - E3: return

## notes

sync
- syncronize rec/play keys & pattern recorder keys to clock division
- phase reset softcut *only* when loop length is 100%

arc assignable to first two pages of track parameters
- we can add more later
