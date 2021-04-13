require("common")

--index of examples to choose from
local examples = {
	"table",
	"functional",
	"math",
	"set",
	"intersect",
	"quit",
}

--colours
local heading_col = {colour.unpack_rgb(0xffffff)}
local heading_bg_col = {colour.unpack_rgb(0x606060)}

local code_col = {colour.unpack_rgb(0xffffa0)}
local comment_col = {colour.unpack_rgb(0x908080)}
local code_bg_col = {colour.unpack_rgb(0x403020)}

local output_col = {colour.unpack_rgb(0xaaffcc)}
local caret_col = {colour.unpack_rgb(0xffaacc)}
local output_bg_col = {colour.unpack_rgb(0x204030)}

local line_height = 16
local margin = 10

--class for loading, running, and drawing the results of an example
local example = class()
function example:new(example_name)
	local src = {}
	for line in love.filesystem.lines(example_name .. ".lua") do
		table.insert(src, line)
	end
	local exe, err = loadstring(table.concat(src, "\n"))
	if exe == nil then
		print(("error loading %s, %s"):format(example_name, err))
		return nil
	end
	
	local output = {}
	--patch the global environment
	local gprint = print
	function print(...)
		table.insert(output, table.map({...}, tostring))
	end

	local result = exe()

	print = gprint

	local output_producing_lines = {"print%(", "print_var%(", "heading%("}
	
	--match print lines to source lines
	local print_lines = {}
	for i, v in ipairs(src) do
		if table.any(output_producing_lines, function(m)
			return v:match(m) ~= nil
		end) then
			print_lines[i] = table.remove(output, 1)
		end
	end

	--todo: parse comments here instead of at draw time so we can properly handle multiline comments, and don't repeat work

	return self:init{
		name = example_name,
		src = src,
		print_lines = print_lines,
		offset = 1,
		result = result or {},
	}
end

function example:scroll(amount)
	--shift enables faster scrolling
	local multiplier = love.keyboard.isDown("lshift") and 3 or 1 
	amount = amount * multiplier
	--clamp scroll within the file source
	self.offset = math.clamp(self.offset + amount, 1, #self.src)
end

function example:draw()
	local code_x = margin
	local output_x = 570

	local total_width_available = love.graphics.getWidth() - margin * 2
	local height_available = love.graphics.getHeight() - margin * 2

	love.graphics.push("all")

	--headings
	love.graphics.translate(margin, margin)
	height_available = height_available - margin
	love.graphics.setColor(heading_bg_col)
	love.graphics.rectangle("fill", 0, 0, total_width_available, line_height * 2 + margin * 2)
	
	love.graphics.translate(0, margin)
	love.graphics.setColor(heading_col)
	love.graphics.print("example: "..self.name, code_x, 0)
	height_available = height_available - line_height
	
	love.graphics.translate(0, line_height)
	love.graphics.print("code:", code_x, 0)
	love.graphics.print("output:", output_x, 0)
	love.graphics.translate(0, line_height + margin)
	height_available = height_available - (line_height + margin)

	love.graphics.setColor(code_bg_col)

	love.graphics.rectangle("fill", code_x - margin, 0, output_x - code_x + margin, height_available)
	love.graphics.setColor(output_bg_col)
	love.graphics.rectangle("fill", output_x, 0, total_width_available - output_x, height_available)

	love.graphics.translate(0, margin / 2)
	local line_count = math.floor(height_available / line_height) - 1
	for line = 0, line_count - 1 do
		local i = self.offset + line
		local v = self.src[i]
		if v then
			--single line comment
			local is_comment = v:match("^%s*%-%-") ~= nil
			love.graphics.setColor(is_comment and comment_col or code_col)
			love.graphics.print(v, code_x, 0)
		end
		local print_line = self.print_lines[i]
		if print_line then
			love.graphics.setColor(caret_col)
			love.graphics.print(">", output_x - 16, 0)
			love.graphics.setColor(output_col)
			for j, p in ipairs(print_line) do
				love.graphics.print(p, output_x + 8 + (j - 1) * 120, 0)
			end
		end
		love.graphics.translate(0, line_height)
	end

	love.graphics.pop()

	if self.result.draw then
		love.graphics.push("all")
		local x = margin + output_x
		local y = margin * 3 + line_height * 2
		local w = total_width_available - output_x
		local h = height_available
		OUTPUT_SIZE = vec2(w, h)

		love.graphics.setScissor(x, y, w, h)
		love.graphics.translate(x, y)
		self.result:draw()
		love.graphics.pop()
	end
end

function example:update(dt)
	if self.result.update then
		return self.result:update(dt)
	end
end

function example:keypressed(k)
	if self.result.keypressed then
		return self.result:keypressed(k)
	end
	--arrows
	if k == "up" then
		self:scroll(-1)
	end
	if k == "down" then
		self:scroll(1)
	end
	--pgup/dn
	local page_amount = 16
	if k == "pageup" then
		self:scroll(-10)
	end
	if k == "pagedown" then
		self:scroll(10)
	end
end

local current 

local menu = {
	selected = 1,
	options = examples,
}

function menu:scroll(amount)
	self.selected = math.floor(math.wrap(self.selected + amount, 1, #self.options + 1))
end

function menu:keypressed(k)
	if k == "up" then
		self:scroll(-1)
	end
	if k == "down" then
		self:scroll(1)
	end
	if k == "space" or k == "return" then
		local name = self.options[self.selected]
		if name == "quit" then
			return love.event.quit()
		end
		current = example:new(name)
	end
end

function menu:draw()
	love.graphics.push("all")
	local w = 200
	love.graphics.translate(margin, margin)
	love.graphics.setColor(heading_bg_col)
	love.graphics.rectangle("fill", 0, 0, w, line_height + margin)
	love.graphics.setColor(heading_col)
	love.graphics.print("select an example:", margin, margin / 2)
	
	love.graphics.translate(0, line_height + margin)
	love.graphics.setColor(code_bg_col)
	love.graphics.rectangle("fill", 0, 0, w, line_height * #self.options + margin * 2)
	love.graphics.setColor(code_col)
	love.graphics.translate(margin, margin)
	for i, v in ipairs(self.options) do
		if i == self.selected then
			love.graphics.print(">", 0, 0)
		end
		love.graphics.print(v, margin, 0)
		love.graphics.translate(0, line_height)
	end
	love.graphics.pop()
end

function love.load()
	love.keyboard.setKeyRepeat(true)
	local font = love.graphics.newFont("font/ProggyClean.ttf", 16)
	love.graphics.setFont(font)
end

function love.update(dt)
	if current then
		current:update(dt)
	end
end

function love.draw()
	if current then
		current:draw()
	else
		menu:draw()
	end
end

function love.keypressed(k)
	--toggle back
	if k == "escape" then
		if current then
			current = nil
		else
			love.event.quit()
		end
		return
	end
	--quit or restart
	if love.keyboard.isDown("lctrl") then
		if k == "r" then
			return love.event.quit("restart")
		elseif k == "q" then
			return love.event.quit()
		end
	end
	--reload current
	if k == "r" and love.keyboard.isDown("lshift") then
		current = example:new(current.name)	
	end
	--pass through
	if current then
		current:keypressed(k)
	else
		menu:keypressed(k)
	end
end
