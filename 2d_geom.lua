--
--	interactive intersection example
--
--	bouncing shapes in ~120 lines
--

require("common")

-- level gen

--(helper)
local gen_area = vec2(300, 500)
local function random_point_in_area()
	return vec2(love.math.random(), love.math.random()):vmuli(gen_area)
end

-- generate some circle objects
local circles = functional.generate(20, function()
	return {
		-- circle geometry
		pos = random_point_in_area(),
		rad = love.math.random(5, 20),
		-- movement
		vel = vec2(love.math.randomNormal() * 40, love.math.randomNormal() * 40),
	}
end)

-- generate some random "world" lines
local lines = functional.stitch(
	functional.generate(5, random_point_in_area),
	function(start_pos)
		local chain = {}
		local current_pos = start_pos
		local dir = vec2(1, 0):rotatei(math.tau * love.math.random())
		for i = 1, love.math.random(4, 7) do
			table.insert(chain, current_pos)
			current_pos = current_pos:fma(dir, love.math.random(30, 50))
			dir = dir:rotatei(love.math.randomNormal())
		end
		chain = functional.cycle(chain, function(a, b)
			return {a, b}
		end)
		--break loop randomly, or if too far from start (likely to be a bad looking poly)
		local last_link = table.back(chain)
		if 
			love.math.random() < 0.5
			or last_link[1]:distance(last_link[2]) > 100
		then
			table.remove(chain)
		end
		return chain
	end
)

-- actual logic
return {
	update = function(self, dt)
		--independent update
		for _, v in ipairs(circles) do
			-- integrate position
			v.pos:fmai(v.vel, dt)

			-- pull inside world
			local push = 100 * dt
			if OUTPUT_SIZE then
				if v.pos.x < 0 then v.vel:saddi(push, 0) end
				if v.pos.y < 0 then v.vel:saddi(0, push) end
				if v.pos.x > OUTPUT_SIZE.x then v.vel:saddi(-push, 0) end
				if v.pos.y > OUTPUT_SIZE.y then v.vel:saddi(0, -push) end
			end
		end
		-- inter-dependent update: collide
		for i = 1, #circles do
			local a = circles[i]
			-- (reuse this vector)
			local separating_vector = vec2.pooled()
			--collide against other circles
			for j = i+1, #circles do
				local b = circles[j]
				if intersect.circle_circle_collide(
					a.pos, a.rad,
					b.pos, b.rad,
					separating_vector
				) then
					--resolve collision
					intersect.resolve_msv(a.pos, b.pos, separating_vector)

					--reuse the separating vector as the normal
					local normal = separating_vector:normalisei()

					--transfer velocities
					intersect.mutual_bounce(a.vel, b.vel, normal, 0.8)
				end
			end

			--collide against lines
			for _, line in ipairs(lines) do
				if intersect.line_circle_collide(
					line[1], line[2], 0,
					a.pos, a.rad,
					separating_vector
				) then
					--resolve (we don't want to modify the line)
					a.pos:fmai(separating_vector, -1)
					intersect.bounce_off(a.vel, separating_vector:normalisei())
				end
			end
			--clean up
			separating_vector:release()
		end
	end,
	draw = function(self)
		--draw all the circles
		for _, v in ipairs(circles) do
			love.graphics.circle("fill", v.pos.x, v.pos.y, v.rad)
		end
		--draw all the lines, a bit darker
		local g = 0.7
		love.graphics.setColor(g, g, g, 1)
		for _, v in ipairs(lines) do
			love.graphics.line(v[1].x, v[1].y, v[2].x, v[2].y)
		end
	end,
}
