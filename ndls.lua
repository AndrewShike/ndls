-- ndls
--
-- -- - -- --- -  ---- -- - ---  -- - - ---
-- -- - --- - --- - -- - --- - - - - - ---
--  --- --- -- - ---- -- - - -- - --- -----
-- -   --- - -- -- -- - -   -- - -- --- --
--
-- endless and/or noodles
--
-- version 0.1.0-schubas @andrew
--

--external libs

cs = require 'controlspec'
pattern_time = require 'pattern_time'

nest = include 'lib/nest/core'
Key, Enc = include 'lib/nest/norns'
Text = include 'lib/nest/text'
Grid = include 'lib/nest/grid'
Arc = include 'lib/nest/arc'

multipattern = include 'lib/nest/util/pattern-tools/multipattern'
of = include 'lib/nest/util/of'
to = include 'lib/nest/util/to'
PatternRecorder = include 'lib/nest/examples/grid/pattern_recorder'

cartographer, Slice = include 'lib/cartographer/cartographer'

--internal files

ndls = include 'ndls/lib/globals'               --shared values & functions
--mpats, mpat = include 'ndls/lib/metapattern'    --multi-scope wrapper around pattern_time
mparams, mparam = include 'ndls/lib/metaparam'  --multi-scope wrapper around params
sc, reg = include 'ndls/lib/softcut'            --softcut utilities
cr = include 'ndls/lib/crow'                    --crow utilities

include 'ndls/lib/params'                       --create params
include 'ndls/lib/ui'                           --grid, arc, & norns UI

function init()
    sc.setup()
    ndls.zone:init()
    mparams:init()
    --for i = 1,2 do mparams.id.rate:set(-1, i+2) end
end
