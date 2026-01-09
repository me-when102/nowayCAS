local nowayCAS = require(game.ReplicatedStorage.nowayCAS.nowayCAS)

local tests = {
	-- Common factor
	{ "4*x*f*a^2 + 4*y*f*a^2 + 8*z*f*a^2", "4*a^2*f*(x + y + 2*z)" },

	-- Bilinear grouping
	{ "x*y*t + x*z*t + w*y*d + w*z*d", "(d*w + t*x)*(y + z)" },
	{ "a*b + a*c + d*b + d*c", "(a + d)*(b + c)" },

	-- Binomial
	{ "x^2 - 9", "(x - 3)*(x + 3)" },

	-- Perfect squares
	{ "x^2 + 2*x*y + y^2", "(x + y)^2" },
	{ "x^2 - 2*x*y + y^2", "(x - y)^2" },

	-- More cases
	{ "9*x^2 - 25*y^2", "(3*x - 5*y)*(3*x + 5*y)" },
	{ "4*x^2 + 12*x + 9", "(2*x + 3)^2" },
	{ "49*a^2 - 14*a*b + b^2", "(7*a - b)^2" },
	{ "m^2 + 5*m*n + 6*n^2", "(m + 2*n)*(m + 3*n)" },
	{ "2*x^2 + 8*x", "2*x*(x + 4)" },
	{ "6*a^2*b + 9*a*b^2", "3*a*b*(2*a + 3*b)" },
	
	{ "12*x*y + 18*x*z", "6*x*(2*y + 3*z)" },
	{ "15*a*b*c + 20*a*b*d", "5*a*b*(3*c + 4*d)" },
	{ "7*m*n - 14*m*p", "7*m*(n - 2*p)" },
	
	{ "p*q + p*r + s*q + s*r", "(p + s)*(q + r)" },
	{ "u*v - u*w - x*v + x*w", "(u - x)*(v - w)" },
	{ "a*b - a*c + d*b - d*c", "(a + d)*(b - c)" },
	
	{ "x^2 - 16", "(x - 4)*(x + 4)" },
	{ "25*y^2 - z^2", "(5*y - z)*(5*y + z)" },
	{ "9*a^2 - 4*b^2", "(3*a - 2*b)*(3*a + 2*b)" },
	
	{ "9*x^2 + 12*x + 4", "(3*x + 2)^2" },
	{ "16*y^2 - 40*y + 25", "(4*y - 5)^2" },
	{ "49*m^2 + 14*m + 1", "(7*m + 1)^2" },
	
	{ "x^2 + 7*x + 12", "(x + 3)*(x + 4)" },
	{ "x^2 - x - 6", "(x - 3)*(x + 2)" },
	{ "2*x^2 + 7*x + 3", "(2*x + 1)*(x + 3)" },
	{ "3*x^2 - 8*x + 4", "(3*x - 2)*(x - 2)" },
	
	{ "2*x^2 + x - 1", "(2*x - 1)*(x + 1)" },
	{ "6*y^2 + 11*y - 35", "(3*y - 5)*(2*y + 7)" },
	{ "4*a^2 - a - 3", "(4*a + 3)*(a - 1)" },
	
	{ "x^2 + x*y - 2*y^2", "(x + 2*y)*(x - y)" },
	{ "a^2 - 5*a*b + 6*b^2", "(a - 2*b)*(a - 3*b)" },
	{ "m^2 + 4*m*n + 3*n^2", "(m + n)*(m + 3*n)" },
	
	{ "-x^2 - 5*x - 6", "-(x + 2)*(x + 3)" },
	{ "-4*a^2 + 12*a - 9", "-(2*a - 3)^2" },
	{ "-9*y^2 + 25", "-(3*y - 5)*(3*y + 5)" },
	
	{ "3*(x^2 + 5*x + 6)", "3*(x + 2)*(x + 3)" },
	{ "2*(4*y^2 - 9)", "2*(2*y - 3)*(2*y + 3)" },
	{ "5*(a^2 - 4*a + 4)", "5*(a - 2)^2" },
	
	{ "x + y", "x + y" },
	{ "x*y + 1", "x*y + 1" },
	{ "a^2 + b^2", "a^2 + b^2" },
	{ "x^3 + 1", "x^3 + 1" }, -- no factorization over integers
}

local function canonicalNode(expr)
	local obj = nowayCAS.new(expr)
	local ast = obj.node
	return nowayCAS.Canon.canonical(ast)
end

local function runTests()
	print("=== FACTORIZATION TESTS ===")

	for i, case in ipairs(tests) do
		local input = case[1]
		local expected = case[2]

		-- Factor the input
		local resultObj = nowayCAS.new(input):factor()
		local resultNode = nowayCAS.Canon.canonical(resultObj.node)

		-- Canonicalize expected
		local expectedNode = canonicalNode(expected)

		-- Compare canonical ASTs
		local ok = nowayCAS.Util.nodeEquals(resultNode, expectedNode)

		if ok then
			print(("PASS %02d: %s → %s"):format(i, input, resultObj:toString()))
		else
			print(("FAIL %02d: %s"):format(i, input))
			print("  got:     ", resultObj:toString())
			print("  expect:  ", expected)
			print("  got(c):  ", nowayCAS.Print._toString(resultNode))
			print("  exp(c):  ", nowayCAS.Print._toString(expectedNode))
		end
	end
end

runTests()