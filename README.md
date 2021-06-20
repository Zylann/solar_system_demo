Solar System Game Demo
=======================

This is a 3D space game demo taking, with procedurally-generated planets. It is a technical demo for one use of the [Voxel Tools module](https://github.com/Zylann/godot_voxel).

[![Video](https://img.youtube.com/vi/8OrZX347MoE/0.jpg)](https://www.youtube.com/watch?v=8OrZX347MoE)

Features
-----------

- Procedurally-generated planets and moon (1 to 2 Km in radius)
- Deterministic, non-realistic celestial motion at all times
- Simple atmospheres
- Fully editable terrain using voxels
- Persistent changes with save files per planet
- Ravines
- Cave systems deep underground (not easy to reach, most entries are in ravines)
- Spaceship flight from ground to space
- Motion trails
- Sound effects and ambiances
- Origin shifting allowing the whole system to be around 50Km in size (takes place only once when close enough to a planet)
- Third-person character
- Simple environment props such as rocks and grass
- Basic waypoint system to pin locations
- Lens flares from [SIsilicon](https://github.com/SIsilicon/Godot-Lens-Flare-Plugin)

Note:
This is a demo project, so any lack of gameplay, placeholders or absence of roadmap is intentional. It is meant to showcase an example of how to start making a game like this. There is no plan to make it a fully-fledged space game, but bug-fixes or small improvements may be welcome.

You need a computer with a powerful CPU to run this. It may run on low-end/mobile supporting GLES3 but it might have slow loading issues.

Textures are from https://ambientcg.com/
Sound effects are partly from https://sonniss.com/gameaudiogdc


Controls
----------

In spaceship mode:
- The mouse orientates the ship
- A and D rolls left or right
- W goes forward
- S goes backward
- Spacebar activates super-speed. Only works when far enough from a planet.
- E to jump off the ship. Only works when properly landed on the ground.

In character mode:
- Mouse to orientate the head and camera
- Left Mouse Button to dig
- Right Mouse Button to place blobs of ground (WARNING, there is no check if you dig yourself in)
- W,A,S,D to move
- Spacebar to jump
- F to toggle flashlight
- T to place a waypoint


Dependencies
--------------

You need to use a custom version of [Godot Engine](https://godotengine.org/) including the [Voxel Tools](https://github.com/Zylann/godot_voxel) module. See how to get one here: https://voxel-tools.readthedocs.io/en/latest/getting_the_module/

