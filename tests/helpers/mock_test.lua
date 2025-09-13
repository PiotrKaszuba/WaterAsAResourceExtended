local mock = require("tests.mock.factorio_runtime")

return function(fn)
    fn()
    print(string.rep("-", 30))
    mock.performance.report()
end
