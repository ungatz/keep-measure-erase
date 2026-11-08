local sheet = {}
local facets, arrows, projection

function sheet.panel(dx, dy)
    projection = {dx, dy}
    facets, arrows = {}, {}
end

local function points(path)
    local result = {}
    for x, y in path:gmatch("%(%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)%s*%)") do
        result[#result + 1] = {tonumber(x), tonumber(y)}
    end
    return result
end

local function sample(path)
    local controls = type(path) == "string" and points(path) or path
    if #controls == 2 then return controls end
    assert(#controls >= 4 and (#controls - 1) % 3 == 0, "Incomplete cubic sheet path")
    local result = {controls[1]}
    for i = 1, #controls - 1, 3 do
        local p, q, r, s = table.unpack(controls, i, i + 3)
        for step = 1, 16 do
            local t = step / 16
            local a = 1 - t
            local function coordinate(j)
                return a^3*p[j] + 3*a^2*t*q[j] + 3*a*t^2*r[j] + t^3*s[j]
            end
            result[#result + 1] = {coordinate(1), coordinate(2)}
        end
    end
    return result
end

local function project(p, depth)
    return {p[1] + (depth - .5)*projection[1], p[2] + (depth - .5)*projection[2]}
end

local function tikz(command, options, vertices, closed)
    local coordinates = {}
    for i, p in ipairs(vertices) do
        coordinates[i] = string.format("(%.4f,%.4f)", p[1], p[2])
    end
    return "\\" .. command .. "[" .. options .. "] " .. table.concat(coordinates, " -- ")
        .. (closed and " -- cycle;" or ";")
end

function sheet.surface(color, path, wire_list, arrow_positions)
    local spine = type(path) == "string" and sample(path) or path
    local wires, marks, lengths = {}, {}, {}
    for depth, ink in wire_list:gmatch("([%d%.]+)/([%a]+)") do
        wires[#wires + 1] = {tonumber(depth), ink}
    end
    for mark in arrow_positions:gmatch("[%d%.]+") do marks[#marks + 1] = tonumber(mark) end
    local total = 0
    for i = 1, #spine - 1 do
        local a, b = spine[i], spine[i+1]
        lengths[i] = math.sqrt((b[1]-a[1])^2 + (b[2]-a[2])^2)
        total = total + lengths[i]
    end

    local travelled, next_arrow = 0, 1
    for i, length in ipairs(lengths) do
        local a, b = spine[i], spine[i+1]
        local dx, dy = b[1]-a[1], b[2]-a[2]
        local near_a, near_b = project(a, 0), project(b, 0)
        local far_a, far_b = project(a, 1), project(b, 1)
        local tint = math.floor(17 + 11*math.abs(dy/length) + 6*math.max(dx/length, 0) + .5)
        local fill = color .. "!" .. tint .. "!white"
        local edge = color .. "!67!black,line width=.38pt"
        local commands = {
            tikz("path", "fill="..fill..",draw="..fill..",line width=.16pt", {near_a,near_b,far_b,far_a}, true),
            tikz("draw", edge, {near_a,near_b}),
            tikz("draw", edge, {far_a,far_b})
        }
        for _, wire in ipairs(wires) do
            commands[#commands + 1] = tikz("draw", wire[2]..",line width=.57pt",
                {project(a,wire[1]), project(b,wire[1])})
        end
        while marks[next_arrow] and total*marks[next_arrow] <= travelled + length do
            local wire = wires[#wires]
            local t = (total*marks[next_arrow] - travelled)/length
            local tip = project({a[1]+t*dx, a[2]+t*dy}, wire[1])
            local tx, ty = dx/length, dy/length
            local x, y = tip[1]-.20*tx, tip[2]-.20*ty
            arrows[#arrows + 1] = tikz("fill", wire[2],
                {tip, {x-.073*ty,y+.073*tx}, {x+.073*ty,y-.073*tx}}, true)
            next_arrow = next_arrow + 1
        end
        travelled = travelled + length
        local rim = color .. "!65!black,line width=.4pt"
        if i == 1 then commands[#commands + 1] = tikz("draw", rim, {near_a,far_a}) end
        if i == #lengths then commands[#commands + 1] = tikz("draw", rim, {near_b,far_b}) end
        local depth = projection[1]*(a[1]+b[1])/2 + projection[2]*(a[2]+b[2])/2
        facets[#facets + 1] = {depth=depth, order=#facets, drawing=commands}
    end
end

function sheet.external(color, wires, x, y, height)
    local h = height/2
    sheet.surface(color, sample({
        {x-.75,y-h}, {x-.75,y-.32*h}, {x-.18,y-.32*h}, {x,y}
    }), wires, ".23")
    sheet.surface(color, sample({
        {x,y}, {x-.18,y+.32*h}, {x-.75,y+.32*h}, {x-.75,y+h}
    }), wires, ".80")
end

function sheet.returning(color, wires, x, y, w, h)
    local loop = sample({
        {x,y}, {x+.21*w,y+.32*h}, {x+.40*w,y+h}, {x+.64*w,y+h},
        {x+.89*w,y+h}, {x+w,y+.57*h}, {x+w,y},
        {x+w,y-.57*h}, {x+.89*w,y-h}, {x+.64*w,y-h},
        {x+.40*w,y-h}, {x+.21*w,y-.32*h}, {x,y}
    })
    sheet.surface(color, loop, wires, ".13,.61")
end

function sheet.paint()
    table.sort(facets, function(a, b)
        if a.depth == b.depth then return a.order < b.order end
        return a.depth < b.depth
    end)
    for _, facet in ipairs(facets) do tex.sprint(facet.drawing) end
    tex.sprint(arrows)
end

return sheet
