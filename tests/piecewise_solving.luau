local CAS = require(game.ReplicatedStorage.nowayCAS.nowayCAS)

local function test(expr)
	local x = CAS.new("x").node
	local eq = CAS.new(expr)
	local result = CAS.solveEquation(eq, x)

	print("Equation:", expr)
	print(result)
	print("-----")
end

-- 1. Simple piecewise with one valid branch
test("{x < 0: x+2; x >= 0: x^2} == 4")

-- 2. Two valid solutions
test("{x < 0: x+2; x >= 0: x^2 - 4} == 0")

-- 3. Branch solution rejected by condition
test("{x < 0: x+2; x >= 0: x} == 2")

-- 4. No solutions
test("{x < 0: x+1; x >= 0: x+2} == 10")

-- 5. Infinite solutions on one branch
test("{x < 0: 0; x >= 0: x} == 0")

-- 6. Piecewise on RHS
test("3 == {x < 0: x+2; x >= 0: x}")

-- 7. Nested piecewise
test("{x < 0: {x < -1: x+3; x >= -1: x+1}; x >= 0: x^2} == 1")

-- 8. Symbolic condition simplifies to true
test("{x^2 > 1: x; x^2 <= 1: 0} == 0")

-- 9. Symbolic condition simplifies to false
test("{x^2 > 1: x; x^2 <= 1: x+1} == 0")

-- 10. UnknownSolve propagation
test("{x < 0: sin(x); x >= 0: x} == 0")