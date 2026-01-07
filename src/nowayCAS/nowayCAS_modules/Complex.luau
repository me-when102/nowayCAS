local Complex = {}

-------------------------------------------------------
-- Complex Numbers (Numeric Domain)
-- Internal representation:
--   { real = number, imag = number, _complex = true }
-------------------------------------------------------

-- Predicate: checks if a value is a complex number.
function Complex.is(x)
	return type(x) == "table" and x._complex == true
end

-- Constructor: creates a complex number.
function Complex.new(real, imag)
	return { real = real, imag = imag, _complex = true }
end

-- Promotes a Lua number to a complex number.
function Complex.to(x)
	if Complex.is(x) then
		return x
	else
		return Complex.new(x, 0)
	end
end

-------------------------------------------------------
-- Arithmetic Operations
-------------------------------------------------------

function Complex.add(a, b)
	a, b = Complex.to(a), Complex.to(b)
	return Complex.new(a.real + b.real, a.imag + b.imag)
end

function Complex.sub(a, b)
	a, b = Complex.to(a), Complex.to(b)
	return Complex.new(a.real - b.real, a.imag - b.imag)
end

function Complex.mul(a, b)
	a, b = Complex.to(a), Complex.to(b)
	return Complex.new(
		a.real * b.real - a.imag * b.imag,
		a.real * b.imag + a.imag * b.real
	)
end

function Complex.div(a, b)
	a, b = Complex.to(a), Complex.to(b)
	local denom = b.real * b.real + b.imag * b.imag
	return Complex.new(
		(a.real * b.real + a.imag * b.imag) / denom,
		(a.imag * b.real - a.real * b.imag) / denom
	)
end

-- Complex exponentiation (real exponent only for now).
function Complex.pow(a, b)
	a = Complex.to(a)

	if Complex.is(b) then
		error("nowayCAS.Complex: complex exponent not supported yet")
	end

	-- Convert to polar: a = r * e^(iθ), a^b = r^b * e^(i b θ)
	local r = math.sqrt(a.real * a.real + a.imag * a.imag)
	local theta = math.atan2(a.imag, a.real)
	local rb = r ^ b

	return Complex.new(
		rb * math.cos(b * theta),
		rb * math.sin(b * theta)
	)
end

-------------------------------------------------------
-- Square Root
-------------------------------------------------------

function Complex.sqrt(x)
	if Complex.is(x) then
		-- general complex sqrt
		local r = math.sqrt(x.real * x.real + x.imag * x.imag)
		local theta = math.atan2(x.imag, x.real) / 2
		local root = math.sqrt(r)
		return Complex.new(root * math.cos(theta), root * math.sin(theta))
	else
		-- real input
		if x >= 0 then
			return math.sqrt(x)
		else
			-- sqrt(-a) = i * sqrt(a)
			local a = -x
			return Complex.new(0, math.sqrt(a))
		end
	end
end

-- The Complex sub-library.
return Complex