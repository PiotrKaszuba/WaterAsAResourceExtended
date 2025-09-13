local mock = require("tests.mock.factorio_runtime")

return function(fn, args)
    fn(args)
    print(string.rep("-", 30))
    mock.performance.report()
    print(string.rep("-", 30))
end
