TE = {}

local canvas, controls_width, tile, botscr

local function init()
    init = function() end

    canvas = {}
    canvas.master = Bitmap:new(16, 16)

    local scale = math.floor(Screen.bottom.height / canvas.master.height)
    canvas.draw = Bitmap:new(canvas.master.width*scale, canvas.master.height*scale)
    canvas.draw.scale = scale
    controls_width = Screen.bottom.width - canvas.draw.width

    local scale = math.floor(controls_width / canvas.master.height)
    canvas.bigref = Bitmap:new(canvas.master.width*scale, canvas.master.height*scale)
    canvas.bigref.scale = scale

    header = UI.View:new(0, 0, controls_width, 25)

    back = UI.Button(UI.View:new(0, 0, controls_width/2, 25), function()
        DISPLAY[2] = DebugMenu
        if R and G and B then
            coler(R, G, B)
            R = nil
            G = nil
            B = nil
        end
    end, 'Back')
    header:add_subview(back)

    clear = UI.Button(UI.View:new(controls_width/2, 0, controls_width/2, 25), function()
        TE.colors = nil
        TE.refresh(true)
    end, 'Clear')
    header:add_subview(clear)

    for i=0,canvas.master.width*canvas.master.height-1 do
        canvas.master.pix[i*3 + 0] = i % 0x100
        canvas.master.pix[i*3 + 1] = (i*2) % 0x100
        canvas.master.pix[i*3 + 2] = (i + 50) % 0x100
    end
end

function coler(r, g, b)
    TE.colors[r*0x10000 + g*0x100 + b] = true
    TE.paint()
end


local function gen()
    local redval = 0
    return function()
        local dt
        repeat
            dt = DT*math.random(-300, 300)
        until redval + dt <= 0xaf and redval + dt >= 0
        redval = redval + dt
        return redval
    end
end

local r = gen()
local g = gen()
local b = gen()

local lastx, lasty

function TE.render()
    init()
    ffi.luared.draw_set_color(r(), g(), b())
    Screen.bottom:rect(0, 0, Screen.bottom.width, Screen.bottom.height)

    --local xplayer, yplayer = get_player_coords()
    --Red:render_map(Screen.bottom, Red.wram.wCurMap, X or math.floor(Red.wram.wXCoord/2), Y or math.floor(Red.wram.wYCoord/2), W or xplayer, H or yplayer, true)

    TE.refresh()
    local canvasx = Screen.bottom.width - canvas.draw.width
    local canvasy = (Screen.bottom.height - canvas.draw.height)/2
    canvas.draw:draw(Screen.bottom, canvasx, canvasy)
    --canvas.bigref:draw(Screen.bottom, (controls_width - canvas.bigref.width)/2, Screen.bottom.height - canvas.bigref.height)

    if Mouse.isheld and Mouse.x >= canvasx then
        local x = math.floor((Mouse.x - canvasx)/15)
        local y = math.floor(Mouse.y/15)
        local i = y*16 + x

        local color = TE.colorpick
        if color and not(lastx == x and lasty == y) then
            local r, g, b = math.floor(color / 0x10000) % 0x100, math.floor(color / 0x100) % 0x100, color % 0x100
            if lastx and lasty then
                ffi.luared.draw_set_color(r, g, b)
                Screen.line(canvas.master, lastx, lasty, x, y)
            else
                local pix = canvas.master.pix + i*3
                pix[0] = r
                pix[1] = g
                pix[2] = b
            end
            TE.painttile()
            TE.paintcanvas()
        end
        lastx, lasty = x, y
        ffi.luared.draw_set_color(0xff, 0x44, 0x44)
        Screen.bottom:line(Mouse.x - 5, Mouse.y - 5, Mouse.x + 5, Mouse.y + 5)
        ffi.luared.draw_set_color(0x0a, 0xaa, 0xaa)
        Screen.bottom:line(Mouse.x + 5, Mouse.y - 5, Mouse.x - 5, Mouse.y + 5)
    elseif Mouse.isup then
        lastx, lasty = nil, nil
    end

    header:render(Screen.bottom)
    TE.color:render(Screen.bottom)
end

local lasttile
function TE.updatetile()
    lasttile = TE.tile

    local x, y = math.floor(Red.wram.wXCoord/2), math.floor(Red.wram.wYCoord/2)
    local map = Red.Map(Red.wram.wCurMap)
    local i = map.blockwidth*y + x
    TE.tile = customtile(Red.wram.wCurMap, x, y) or gettilefromrom(map.tileset, map.wram.blocks[i])
    local vert =  Red.wram.wYCoord % 2 == 0 and 'n' or 's'
    local horiz = Red.wram.wXCoord % 2 == 0 and 'w' or 'e'
    TE.tile = TE.tile[vert..horiz]
    return not(lasttile == TE.tile)
end

function TE.refresh(override)
    if (not override and not TE.updatetile()) or not TE.tile then return end

    TE.colors = TE.colors or {}
    for y=0,16-1 do
        for x=0,16-1 do
            local o = canvas.master.pix + 3*(canvas.master.width*y + x)
            local i = TE.tile.pix + 3*(TE.tile.width*y + x)
            o[0] = i[0]
            o[1] = i[1]
            o[2] = i[2]
            TE.colors[i[0]*0x10000 + i[1]*0x100 + i[2]] = true
        end
    end

    local i = 0
    TE.pick = nil
    for color,_ in pairs(TE.colors) do
        i = i + 1
        if color == TE.colorpick then
            TE.pick = i
            break
        end
    end


    TE.paint()

end

function TE.painttile()
    for y=0,16-1 do
        for x=0,16-1 do
            local i = canvas.master.pix + 3*(canvas.master.width*y + x)
            local o = TE.tile.pix + 3*(TE.tile.width*y + x)
            o[0] = i[0]
            o[1] = i[1]
            o[2] = i[2]
        end
    end
end

function TE.paint()
    TE.color = UI.View:new(0, back.height)
    function TE.color:postdraw(scr, x, y)
        if not TE.pick then return end

        local siz = 16
        local pad = 2
        local i = TE.pick - 1
        local x = x + siz*(i % (controls_width/siz)) + pad
        local y = y + siz*math.floor(i / (controls_width/siz)) + pad
        local color = TE.colorpick
        color = {math.floor(color / 0x10000) % 0x100, math.floor(color / 0x100) % 0x100, color % 0x100}
        if color[1] + color[2] + color[3] > 3*0x55 then
            ffi.luared.draw_set_color(0x00, 0x00, 0x00)
        else
            ffi.luared.draw_set_color(0xff, 0xff, 0xff)
        end
        local s = 16 - pad*2
        Screen.bottom:line(x, y, x + s, y)
        Screen.bottom:line(x, y, x, y + s)
        Screen.bottom:line(x + s, y + s, x + s, y)
        Screen.bottom:line(x + s, y + s, x, y + s)
    end
    local i = 0
    for color,_ in pairs(TE.colors) do
        local x = i % 5
        local y = math.floor(i / 5)
        local pick = i + 1
        local v = UI.Button(UI.View:new(x*16,y*16, 16, 16), function()
            TE.pick = pick
            TE.colorpick = color
        end)
        v.background_color =  {math.floor(color / 0x10000) % 0x100, math.floor(color / 0x100) % 0x100, color % 0x100}
        TE.color:add_subview(v)
        i = i + 1
    end

    TE.paintcanvas()
end
function TE.paintcanvas()
    for k,v in pairs(canvas) do
        if k == 'master' then
        else
            ffi.fill(v.pix, ffi.sizeof(v.pix), 0x66)
            ffi.luared.scalecopy(
                v.pix, canvas.master.pix,
                canvas.master.width, canvas.master.height,
                v.scale
            )
        end
    end
end


TileEditor = TE
return TE
