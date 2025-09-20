local depth = 16
local current_depth = 0
local sum = 0

function num_tiles_per_depth(n)
    return n == 1 and 1 or ((2 * (n-1))) * 4
end

function sum_n(n)
--    local side = 1 + 2*(n-1)
--    return side*side
    return 4 * (n * n - n) + 1

end

while current_depth < depth do
    current_depth = current_depth + 1
    local val = num_tiles_per_depth(current_depth)
    sum = sum + val
    local sum2 = sum_n(current_depth)
    print(current_depth, val, sum, sum2)
end