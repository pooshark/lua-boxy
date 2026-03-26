# lua-boxy
Basic Lua AABB collision and response library, ideal for platformers. designed and tested in LÖVE2D 11.5.

Features touch callbacks, bounciness (restitution), friction, anchored or dynamic bodies, and collision-less bodies.

## Usage
put physics.lua in your project.

```require('physics')```

physics.lua puts one function as a global variable: `newWorld`. All other functions are methods of World objects.

```local world=newWorld()```

**main.lua in this repository is a full platformer example, and it's well commented to explain everything. please read it.**
