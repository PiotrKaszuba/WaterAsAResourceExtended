-- Same shared suite and arguments, with the test-only guard/index bypass.
require("tests.performance.guard_mode").set(false)
dofile("tests/performance/run.lua")
