require('physics')
local world=newWorld()
world.defaults.bounciness=0.5
world.defaults.color={0.3,0.4,0.9}
world.gravity=800

player={
    grounded=false,
    movespeed=800,
    maxspeed=250,
    jumpvel=-0.7*world.gravity--800 is default gravity
}

--when provided, the options table is used as the object's table
--so we can use the player table for other things too
player.tag='player'--the tag is used in touch callbacks
player.typ='dyna'--typ='dyna' means it is a dynamic object and can move
world:body(0,0,80,80,player)
ground=world:body(0,400,800,100,{typ='anch',tag='ground'})--typ='anch' means the object is anchored and cannot move

boxy=world:body(400,310,100,90,{color={1,0,0},tag='boxy'})--by default, typ='anch'
dynaboxy=world:body(200,0,80,80,{typ='dyna',yvol=0,tag='dynaboxy'})



--touch callbacks are functions that will be called when objects with the specified tags collide
world.touchbegin={
    ['player']={--this is what the 'tag' option is for
        --the '_any' tag matches any object
        ['_any']=function(A,B,side,coll)
            --callback tags match one-way, so A.tag=='player', B==anything
            --A is the player table we made before
            if side=='bottom' then
                --side is relative to A (when the bottom of A is touching B)
                --side can be 'left','right','top', or 'bottom'
                player.grounded=true
                --OR A.grounded=true, same thing
                player.justgrounded=true
            end
        end,
        ['boxy']=function(a,b,side)
            print('You touched the box? how dare you')
        end,
        ['ceiling']=function()
            print('You touch the ceiling')
        end
    }
}
--if you want to add more callbacks later without deleting previous ones:
world.touchend['player']={
    ['_any']=function(a,b,side,coll)
        if side=='bottom' then
            player.grounded=false
        end
    end,
    ['boxy']=function(a,b,side)
        --we need side=='bottom' because the player could jump off the ground 
        -- while touching the side of the box
        if side=='bottom' and player.jumped then
            print('You jump on top of the box? you insolent pig')
        end
    end
}
--note that touchbegin, touchend, and presolve are all called before the collision is resolved, while postsolve is called after
--presolve and postsolve callbacks are called every frame that two objects are touching
world.presolve['_any']={
    ['_any']=function(a,b,side,coll)
        --both _any's can match either object in the collision, 
        -- so this callback would fire twice per touching pair of objects
        -- a and b would be switched on the second callback call
        --the same thing can happen whenever the two tags can match either object
    end,
}
--removing a callback:
world.presolve['_any']['_any']=nil

world.postsolve.player={--yeah you don't need the [''] obv
    _any=function(a,b,side,coll)
        if player.justgrounded then
            player.yvol=0
            player.justgrounded=false
        end
        --stops player from bouncing on the ground, but can bounce on other sides.
    end,
    dynaboxy=function(a,b,side,coll)
        --print(a.xvol,b.xvol)
    end,
    ground=function(a,b,side,coll)
        --print(coll.xnormal,coll.ynormal)
    end
    --note that objects may or may not be still overlapping after collision resolution
}
--other special tags are '_none'(the default tag), and 
--  '_notnone', which matches any tag except '_none'
function love.load()
end
function love.keypressed(key,scancode)
    if scancode=='space' and player.grounded then
        player.yvol=-400
        player.jumped=true
    end
end
local min,max=math.min,math.max
local abs=math.abs
local lastspace=false
local lastdt
function love.update(dt)
    lastdt=dt
    --touch callbacks actually fire every single frame while two objects are touching, 
    -- so player.grounded will be set to true every frame while it is touching something.
    -- (and we can't do player.grounded=false in the touch callback)
    local isdown=love.keyboard.isScancodeDown
    local function num(bool)
        return bool and 1 or 0
    end
    --wasd controls
    local movedir=num(isdown('d'))-num(isdown('a'))--a movement direction of -1, 0, or 1
    --smooth movement
    player.xvol=player.xvol+movedir*player.movespeed*dt--yeah, dont forget dt
    --limit to max speed
    player.xvol=min(max(player.xvol,-player.maxspeed),player.maxspeed)
    local space=isdown('space')
    if space and not lastspace and player.grounded then
        player.yvol=-400
        player.jumped=true
    end
    print(world.touching[player][dynaboxy])--prints a collision table if they are touching, otherwise nil (and yes world.touching is indexed with the body tables themselves)
    lastspace=space
    world:update(dt)
    player.jumped=false
end
function love.mousepressed()
    local x,y=love.mouse.getPosition()
    local touched=world:checkPoint(x,y)--returns a list of bodies
    for i=1,#touched do
        print(touched[i].tag)
    end
end
--world.drawmode='fill'
function love.draw()
    love.graphics.print(math.floor(1/lastdt))--fps
    love.graphics.setLineWidth(2)
    world:draw()
end