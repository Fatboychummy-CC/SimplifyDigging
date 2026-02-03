# SimplifyDigging 2.0

SimplifyDigging is a ComputerCraft program designed to make digging various shapes with a turtle easy and efficient.

## Features
- Dig cuboids, tunnels, staircases, spheres, and quarries.
- User-friendly interface.
- Customizable dimensions for each shape.
- Efficient digging algorithms. In particular, it uses all three diggable directions (forward, up, down).
- Optimized for fuel consumption and inventory management.
- Error handling for obstacles such as gravel.
- Automatically resumes digging after interruptions (chunk unloads, etc).
- Returns home when it runs low on fuel or inventory space.

## Installation
1. Run `wget run https://raw.githubusercontent.com/Fatboychummy-CC/SimplifyDigging/refs/heads/main/installer.lua` in a turtle to download and run the installer.
2. Follow the on-screen instructions to complete the installation.
3. After installation, you can start the program by running `dig.lua` in the turtle.

## Usage
1. Start the program by running `dig.lua`.
2. Select the shape you want to dig from the menu.
3. Input the required dimensions when prompted.
4. Confirm the settings and start digging.
5. The turtle will return to the surface and wait if any issues arise. You can go do whatever while it works.

## Usage (advanced/command-line)
This program internally uses a command-line interface, running itself with specific arguments in order to accomplish its main tasks.

For example, upon starting digging, the turtle writes a file to the `startup` folder which runs the program with arguments to start digging the selected shape with the specified dimensions, with a given state file to track/resume progress.

You can also run the program directly with arguments to skip the menu and start digging immediately. For example:

```
dig.lua cuboid 10 5 3 --right --up --save="/state.txt"
```

This command would start digging a cuboid of dimensions 10x5x3, oriented to the right and upwards, using `/state.txt` to track progress.

> [!NOTE]

> Both `--save` and `--file` flags are used to specify the state file path, but `--save` tells the turtle to **create** a new state file, while `--file` tells it to **load** an existing state file.
> They are mutually exclusive; you should only use one or the other.

### Command Reference

- `dig.lua cuboid <forward length> <height> <width> [flags] [options=values]`
  - Digs a cuboid with the specified dimensions.
  - Alias: `tunnel`
- `dig.lua staircase <steps> [flags] [options=values]`
  - Digs a staircase with the specified number of steps.
- `dig.lua sphere <radius> [flags] [options=values]`
  - Digs a sphere with the specified radius.
- `dig.lua quarry <length> <width> [max-depth] [flags] [options=values]`
  - Digs a quarry with the specified dimensions.
  - Max depth is optional; if not provided, it will dig until it can no longer dig down.
  - If max-depth is provided, the turtle will return to the surface after reaching that depth, or when it can no longer dig down, whichever comes first.

#### Flag Reference
- `--left`/`-l`
  - Orient the shape to the left.
- `--right`/`-r`
  - Orient the shape to the right.
- `--down`/`-d`
  - Orient the shape downwards.
- `--up`/`-u`
  - Orient the shape upwards.

#### Option Reference
- `--file="<path>"`
  - Specifies the path to an existing state file to load.
- `--save="<path>"`
  - Specifies the path to create a new state file for saving progress.
- `--broadcast="</path/to/handler>"`
  - Specifies a path to a file that will handle broadcasting status updates from the turtle.
  - A basic handler can be found in [`lib/broadcast_handler.lua`](lib/broadcast_handler.lua), but you can specify your own for security or customization reasons.