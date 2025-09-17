local mock = require("tests.mock.factorio_runtime")

return function(fn, fn_args, performance_report_args)
    fn(fn_args)
    print(string.rep("-", 30))
    mock.performance.report(performance_report_args)
    print(string.rep("-", 30))
end
