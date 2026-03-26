
local defaults={
	bounciness=0,
	friction=0.03,
	typ='anch',
	gravscale=1,
	frictionscale=1,
	airfrictionscale=1,
	show=true,
	hascollision=true,
	color={1,1,1}
}
local world={}
world.__index=world
local insert=table.insert
local min,max=math.min,math.max
local abs=math.abs
local function getsign(n)
	if n==0 then
		return 0
	else
		return n/abs(n)
	end
end
local function list_iter(t)
	local i = 0
	local n = table.getn(t)
	return function ()
		i = i + 1
		if i <= n then
			return i,t[i]
		end
	end
end
local weak_keys={__mode = "k"}
function newWorld()
	local new={
		objs={},
		gravity=650,
		airfriction=0.0001,
		maxdt=0.1,
		mag=0.3,--minimum collision depth for object positions to be corrected, prevents jitter for resting objects - increase if most of your objects are massive
		correctpercent=0.5, --percentage of position correction, increase if objects sink through each other or get too squigy. 
		touchbegin={},
		touchend={},
		presolve={},
		postsolve={},
		defaults=defaults,
		drawmode='line',
		touching={},
		locked=false
	}
	setmetatable(new,world)
	return new
end
function world:checkPoint(x,y)
	local check={}
	for i=1, #self.objs do
		local o=self.objs[i]
		if x>o.x and x<o.x+o.w and y>o.y and y<o.y+o.h then
			insert(check,o)
		end
	end
	return check
end
function world:body(x,y,w,h,opts)
	local t=opts or {}
	t.x=x
	t.y=y
	t.w=w
	t.h=h
	t.xvol=t.xvol or 0
	t.yvol=t.yvol or 0
	--avoids using metatables so you can write to body properties normally
	for k,v in pairs(self.defaults) do
		if t[k]==nil then
			t[k]=v
		end
	end
	t.tag=t.tag or '_none'
	insert(self.objs,t)
	t.index=#self.objs
	self.touching[t]={}
	return t
end
function world:add(body)
	insert(self.objs,t)
	t.index=#self.objs
	self.touching[t]={}
end
function world:remove(body)
	if self.locked then
		error("Removing bodies inside of touch callbacks is forbidden",2)
	end
	table.remove( self.objs, body.index)
	for i=body.index,#self.objs do
		self.objs[i].index=self.objs[i].index-1
	end
	self.touching[body]=nil
end
local function rectcollision(a,b)
	local x_overlap = min(a.x+a.w, b.x+b.w) - max(a.x, b.x)
	local y_overlap = min(a.y+a.h, b.y+b.h) - max(a.y, b.y)
	local depth = min(x_overlap, y_overlap)
	local xnormal,ynormal
	if x_overlap < y_overlap then
		xnormal = (a.x < b.x) and -1 or 1
		ynormal=0
	else
		ynormal = (a.y < b.y) and -1 or 1
		xnormal=0
	end
--[[	if x_overlap <= 0 or y_overlap <= 0 then
		depth=false
	end]]
	return depth,xnormal,ynormal
end
function world:draw()
	for i,obj in list_iter(self.objs) do
		if obj.show then
			love.graphics.setColor(obj.color)
			love.graphics.rectangle(self.drawmode,obj.x,obj.y,obj.w,obj.h)
		end
	end
end
local function getcollside(xnormal,ynormal)
	local side=xnormal==0 and (ynormal>0 and 'top' or 'bottom')
		or (xnormal>0 and 'left' or 'right')
	return side
end
--bounciness is only the ability to bounce off of anchored objects
local function actualdocallbacks(callbacks,a,b,...)
	local tags1={a.tag,'_any'}
	local tags2={b.tag}
	for i=1,#tags1 do
		tag1=tags1[i]
		for e=1,#tags2 do
			tag2=tags2[e]
			if callbacks[tag1] then
				if callbacks[tag1][tag2] then
					--includes _none tag as it is just the default tag
					callbacks[tag1][tag2](a,b,...)
				end
				if callbacks[tag1]['_any'] then
					callbacks[tag1]['_any'](a,b,...)
				end
				if tag2~='_none' and callbacks[tag1]['_notnone'] then
					callbacks[tag1]['_notnone'](a,b,...)
				end
			end
		end
	end
end
local oppsides={top='bottom',bottom='top',left='right',right='left'}
local function docallbacks(callbacks,a,b,side,coll)
	actualdocallbacks(callbacks,a,b,side,coll)
	actualdocallbacks(callbacks,b,a,oppsides[side],coll)
end
local function doforces(a,b,vrel,bounce,normal,atyp,btyp)
	--for xvol or yvol forces
	local total=abs(vrel)--force transferred	
	local amult,bmult=.5,.5
	if atyp=='anch'then
		amult=0
		bmult=1
		total=total*-(1+bounce)
	elseif btyp=='anch'then
		amult=1
		bmult=0
		total=total*-(1+bounce)
	else
		total=total*-(1+bounce)
	end
	local a=a-total*normal*amult
	local b=b+total*normal*bmult
	return a, b
end
function world:update(dt)
	if dt>self.maxdt then
		local dtdone=0
		for i=1,math.ceil(dt/self.maxdt) do
			local doo=math.min(self.maxdt,dt-dtdone)
			self:update(doo)
			dtdone=dtdone+doo
		end
		return
	end
	self.locked=true
	for i,o in list_iter(self.objs) do
		if o.typ=='dyna' then
			o.yvol=o.yvol+self.gravity/2*dt*o.gravscale
			o.y=o.y+o.yvol*dt
			o.x=o.x+o.xvol*dt
			o.yvol=o.yvol+self.gravity/2*dt*o.gravscale
			o.yvol=o.yvol-o.yvol*self.airfriction*o.airfrictionscale
			o.xvol=o.xvol-o.xvol*self.airfriction*o.airfrictionscale
		end
	end

	local collisions={}
	--get collisions
	for w=1,#self.objs do
		local a=self.objs[w]
		for e=w+1,#self.objs do
			local b=self.objs[e]
			if w~=e then
				local depth,xnormal,ynormal=rectcollision(a,b)
				local side=getcollside(xnormal,ynormal)
				local coll={
					depth=depth,
					xnormal=xnormal,
					ynormal=ynormal,
					a=a,
					b=b,
					--axvol=a.xvol,bxvol=b.xvol,--collisions less squishy without this but works either way
					--ayvol=a.yvol,byvol=b.yvol,
					side=side,
				}
				if depth>0 and (a.typ=='dyna' or b.typ=='dyna') then
					local wastouching=self.touching[a][b]
					self.touching[a][b]=coll
					if not wastouching then
						docallbacks(self.touchbegin,a,b,side,coll)
					end
					docallbacks(self.presolve,a,b,side,coll)
					if a.hascollision and b.hascollision then
						insert(collisions,coll)
					end
				else
					local wastouching=self.touching[a][b]
					self.touching[a][b]=false
					if wastouching then
						docallbacks(self.touchend,a,b,side,wastouching)
					end
				end
			end
		end
	end
	--collide
	for i=1,#collisions do
		local coll=collisions[i]
		local a=coll.a
		local b=coll.b
		local depth,xnormal,ynormal=coll.depth,coll.xnormal,coll.ynormal
		if true then
			--resolve collision ([ab]).([xy]v?o?l?) coll.$1$2
			--coll.([ab])([xy]vol) $1.$2
			local xvolrel=b.xvol-a.xvol
			local yvolrel=b.yvol-a.yvol
			--only do collision when they are moving toward each other
			local correctiondep=max(depth-self.mag,0)*self.correctpercent
			local friction=min(a.friction,b.friction)
			local bounce=(a.bounciness+b.bounciness)/2--you might want the min or max instead, your choice
			if ynormal==0 then
				local dox=xvolrel*xnormal>0
				if dox then
					a.xvol,b.xvol=doforces(a.xvol,b.xvol,xvolrel,bounce,xnormal,a.typ,b.typ)
					local fricforce=getsign(yvolrel)*friction*abs(xvolrel)
					if a.typ=='dyna'then
						a.x=a.x+correctiondep*xnormal
						a.yvol=a.yvol+fricforce*a.frictionscale
					end
					if b.typ=='dyna'then
						b.x=b.x-correctiondep*xnormal
						b.yvol=b.yvol-fricforce*b.frictionscale
					end
				end
			else--xnormal is 0
				local doy=yvolrel*ynormal>0
				if doy then
					a.yvol,b.yvol=doforces(a.yvol,b.yvol,yvolrel,bounce,ynormal,a.typ,b.typ)
					local fricforce=getsign(xvolrel)*friction*abs(yvolrel)
					if a.typ=='dyna'then
						a.y=a.y+correctiondep*ynormal
						a.xvol=a.xvol+fricforce*a.frictionscale
					end
					if b.typ=='dyna'then
						b.y=b.y-correctiondep*ynormal
						b.xvol=b.xvol-fricforce*b.frictionscale
					end
				end
			end
		end
	end
	self.locked=false
	for i=1,#collisions do
		local coll=collisions[i]
		docallbacks(self.postsolve,coll.a,coll.b,coll.side,coll)
	end
end
