local ValuePrint = {}

local tostring = tostring

-------------------------------------------------------
-- Value Pretty Printer
-------------------------------------------------------

-- Assuming { complex = boolean, imag = num, real = num },
-- Returns a string of the complex number representation
local function prettyComplex(z)
	local r = z.real
	local i = z.imag

	-- Pure real
	if i == 0 then
		return tostring(r)
	end

	-- Pure imaginary
	if r == 0 then
		if i == 1 then return "i" end
		if i == -1 then return "-i" end
		return tostring(i) .. "i"
	end

	-- Mixed real + imaginary
	local sign = i >= 0 and " + " or " - "
	local imagAbs = math.abs(i)

	if imagAbs == 1 then
		return tostring(r) .. sign .. "i"
	else
		return tostring(r) .. sign .. tostring(imagAbs) .. "i"
	end
end

-- Converts a value (including complex numbers) into a human-readable string.
function ValuePrint._value(v)
	if type(v) == "table" and v._complex then
		return prettyComplex(v)
	else
		return tostring(v)
	end
end

return ValuePrint
