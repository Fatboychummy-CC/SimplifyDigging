# SimplifyDigging 2.0

> [!WARNING]
> This program is still in development, and may outright not work or have major bugs. Use at your own risk.

SimplifyDigging is a ComputerCraft program designed to make digging various shapes with a turtle easy and efficient.

## Features
- Dig cuboids, staircases, and quarries.
- Place bridges across gaps.
- User-friendly interface.
- Customizable dimensions for each shape.
- Efficient digging algorithms. In particular, it uses all three diggable directions (forward, up, down).
- Optimized for fuel consumption and inventory management.
- Error handling for obstacles such as gravel.
- Automatically resumes digging after interruptions (chunk unloads, etc).
- Returns home when it runs low on fuel or inventory space.
- Broadcast status updates over a modem or to discord -- Or, implement your own broadcaster!

## Installation
[![Download on PineStore](https://raster.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpinestore.cc%2Fapi%2Fproject%2F222&query=%24.project.downloads&suffix=%20downloads&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB3aWR0aD0iNzYuOTA0IiBoZWlnaHQ9Ijg5LjI5NSIgcHJlc2VydmVBc3BlY3RSYXRpbz0ieE1pZFlNaWQiIHZlcnNpb249IjEuMSIgdmlld0JveD0iMCAwIDc2OS4wNCA4OTIuOTUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI%2BCiA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMTQuNzQgLTQuNjgyNikiIGZpbGw9IiM5YWIyZjIiPgogIDxwYXRoIGQ9Im00MTAgODUxYzAtMTIgMjYtMjEgNTgtMjEgMTUgMCAyMiA0IDE3IDktMTQgMTItNzUgMjItNzUgMTJ6Ii8%2BCiAgPHBhdGggZD0ibTU4NSA3NDJjLTEtNDkgNC03MiAxNi04NSAyMi0yNCAzMC02OCAxNi04Ni0xMi0xNC0yNy0zOS00OC03OC0xMC0xOS05LTI2IDQtNDEgMjItMjQgMjEtNjctMi0xNDQtMjEtNjktMzktMTQ0LTQ4LTE5NS00LTI2LTItMzMgMTEtMzMgMzEgMCAxMTIgMzMgMTQxIDU4IDI4IDIzIDgxIDkyIDcxIDkyLTIgMCA1IDI2IDE2IDU3IDI4IDc5IDI5IDIyNCAzIDMwOC0xMCAzMy0xOSA2Mi0xOSA2NS00IDI2LTEzMiAxNTAtMTU1IDE1MC0zIDAtNi0zMC02LTY4eiIvPgogIDxwYXRoIGQ9Im02OCA2NzNjLTcyLTEwOS03MS0yNzggMy00MjMgMzYtNzEgNjItMTAwIDEyOC0xNDAgNDMtMjcgNjUtMzQgMTE4LTM2IDEwMC00IDk4IDExLTE5IDEzNi0zNCAzNy03OCA4OC05NiAxMTMtMjggMzktMzEgNDgtMjEgNjUgMTEgMTcgNiAyNy0zMyA3OS00MCA1My00NCA2Mi0zMiA3OCAxNyAyMyAxOCA1NyAyIDczLTYgNi0xNCAzMS0xNyA1NC02IDQyLTYgNDItMzMgMXoiLz4KIDwvZz4KIDxnIHRyYW5zZm9ybT0idHJhbnNsYXRlKC0xNC43NCAtNC42ODI2KSIgZmlsbD0iIzU5YTY0ZiI%2BCiAgPHBhdGggZD0ibTM2NSA4MTNjLTUzLTYtMTM5LTMzLTE5Mi02MS02OC0zNS04My02Ny01OC0xMjIgMjYtNTkgNDAtNjcgNzgtNDkgNjggMzMgMTY3IDU4IDI2NiA2OSA1OCA1IDEwNiAxMiAxMDkgMTQgMiAzIDYgMzIgOSA2NSA4IDg1IDAgOTEtMTAxIDkwLTQ0LTEtOTQtNC0xMTEtNnoiLz4KICA8cGF0aCBkPSJtNDEwIDQ1OWMtNjctNy0xNjAtMjktMTk5LTQ4LTI3LTE0LTM0LTM2LTIwLTYzIDIxLTM4IDk3LTEzNiAxNTAtMTkzIDI1LTI3IDU4LTcxIDczLTk3IDI1LTQzIDMxLTQ3IDU0LTQyIDQwIDEwIDQyIDEyIDQyIDUyIDAgMjAgNiA1NyAxNCA4MiAyNCA3MyA1NCAxOTIgNjIgMjM2IDUgMzUgMyA0NS0xNSA2My0yMyAyMy0zNiAyNC0xNjEgMTB6Ii8%2BCiA8L2c%2BCiA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMTQuNzQgLTQuNjgyNikiIGZpbGw9IiM3ZWNiMjUiPgogIDxwYXRoIGQ9Im01NTggNjc0Yy0yLTItNTEtOS0xMDktMTQtMTAyLTExLTIwNC0zNy0yNjQtNjktMTYtOC0zMi0xNC0zNC0xMi00IDMtMzEtNDgtMzEtNjEgMC01IDIxLTMxIDQ2LTU4IDUxLTU0IDcxLTYwIDEzMC0zNSAxOSA4IDgzIDE5IDE0MiAyNSA1OCA2IDEwNyAxMiAxMDcgMTNzMTUgMjYgMzMgNTZjMjcgNDMgMzIgNjMgMzAgOTktMiAzNS04IDQ3LTI1IDUzLTExIDQtMjMgNi0yNSAzeiIvPgogPC9nPgogPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTE0Ljc0IC00LjY4MjYpIiBmaWxsPSIjZWNlZGVmIj4KICA8cGF0aCBkPSJtMjYwIDg5MGMtMzQtOC03MC00MS03MC02NSAwLTYtOS0yMC0yMC0zMHMtMjAtMjItMjAtMjctMTMtMjEtMzAtMzVjLTM1LTI5LTQxLTgzLTEzLTEyMiAxNS0yMiAxNS0yNi0xLTU2LTE4LTMzLTE4LTMzIDI3LTkxIDI4LTM2IDQyLTYzIDM2LTY4LTIzLTI1IDktNzggMTIwLTE5NyAzNi0zOCA3Mi04MSA4Mi05NiAxMC0xNCAyNS0zMCAzMy0zNSAzNi0yMCA3IDMyLTUzIDk3LTQ4IDUxLTEyNiAxNTAtMTQ5IDE4OS0xMCAxOC05IDI0IDEwIDQwIDIzIDE5IDIzIDE5LTI5IDcxLTUzIDUyLTUzIDUyLTM4IDgyIDE0IDI4IDE0IDMzLTEwIDc2LTMyIDU3LTIzIDgxIDQ2IDEyMCAzNCAxOSA0OSAzMyA0NSA0Mi0xNCAzNyAzNiA3NSA5OCA3NSAyNSAwIDQwLTcgNTQtMjUgMTgtMjMgMjctMjUgOTUtMjUgOTQgMCAxMDItOCA5My04OS02LTUzLTUtNTkgMTQtNjQgMzItOCAyNi02NC0xNS0xMzItMzUtNTgtMzUtNTgtOS04MiAyMS0xOSAyNC0yOSAxOS01Ni0xMC00Ny00NC0xNzUtNjEtMjI3LTgtMjUtMTQtNjItMTQtODMgMC0yNy01LTM5LTE3LTQzLTEwLTMtMjUtOC0zMy0xMC0xMi00LTEyLTYtMS0xNCAyNy0xNiA1NiA1IDY5IDUxIDM1IDExNyA0MyAxNDggNDYgMTcwIDIgMTMgMTEgNTEgMjEgODQgMjEgNzEgMjEgMTIxIDAgMTQ1LTE0IDE1LTEzIDE5IDUgNDMgMTEgMTQgMjAgMzAgMjAgMzVzNyAxNSAxNSAyMmMyMSAxNyAxNiA3NS0xMCAxMDItMTggMTktMjAgMzItMTcgNzkgNCA1MCAyIDU4LTE5IDcyLTEyIDktNTAgMTktODMgMjMtNDUgNS02NSAxMy04MyAzMi0yNiAyOC05MiAzOC0xNTMgMjJ6Ii8%2BCiA8L2c%2BCiA8ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMTQuNzQgLTQuNjgyNikiIGZpbGw9IiM3ZTY3NGQiPgogIDxwYXRoIGQ9Im0yNDggODU0Yy0zMC0xNi00Ny01OS0zMC03NiA4LTggMjMtNyA1NCAyIDI0IDcgNjEgMTQgODMgMTcgNTQgNyA1OSAxNSAzNSA0Ni0xOCAyMy0yOSAyNy02OCAyNy0yNi0xLTU5LTctNzQtMTZ6Ii8%2BCiA8L2c%2BCjwvc3ZnPgo%3D&label=PineStore)](https://pinestore.cc/projects/222/simplifydig-2-0)

1. Run the following command in a turtle:

```
wget run https://raw.githubusercontent.com/Fatboychummy-CC/SimplifyDigging/refs/heads/better/installer.lua
```

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

> [!IMPORTANT]
> Both `--save` and `--file` flags are used to specify the state file path, but `--save` tells the turtle to **create** a new state file, while `--file` tells it to **load** an existing state file.
> They are mutually exclusive; you should only use one or the other.

### Command Reference

- `dig.lua cuboid <forward length> <width> [height] [flags] [options=values]`
  - Digs a cuboid with the specified dimensions.
  - If height is not specified, it will dig until it hits bedrock.
  - The turtle will dig to the right and downwards by default.
  - Alias: `cube`
  - Alias: `box`
  - Alias: `tunnel`
  - Alias: `quarry`
- `dig.lua staircase <steps> [passage height=3] [flags] [options=values]`
  - Digs a staircase with the specified number of steps.
  - The staircase will go downwards by default, and is only one block wide.
  - Alias: `stair`
  - Alias: `stairs`
- `dig.lua bridge <length> [flags] [options=values]`
  - Sets a bridge with the specified length.
  - The turtle will only go straight, stopping when it hits any block in the way
    or the specified length, whatever comes first.

#### Flag Reference
- `--left`/`-l`
  - Orient the shape to the left.
- `--right`/`-r`
  - Orient the shape to the right.
- `--down`/`-d`
  - Orient the shape downwards.
- `--up`/`-u`
  - Orient the shape upwards.
- `--fuel`/`-f`
  - Allows the turtle to refuel itself automatically on items it finds underground (like coal, etc.).
  - By default, the turtle will not refuel itself to avoid consuming valuable items.
  - If the turtle has an empty bucket in its inventory, it will also use that to collect lava for refueling.
- `--no-inv`/`-n`
  - Disables automatic inventory management. Instead, the turtle will dump every item it collects.

#### Option Reference
- `--file="<path>"`
  - Specifies the path to an existing state file to load.
- `--save="<path>"`
  - Specifies the path to create a new state file for saving progress.
- `--broadcast="</path/to/handler>"`
  - Specifies a path to a file that will handle broadcasting status updates from the turtle.
  - A basic handler can be found in [`lib/broadcast_handler.lua`](lib/broadcast_handler.lua), but you can specify your own for security or customization reasons.
  - Broadcasts are useful for monitoring the turtle's progress remotely, especially if it gets stuck or needs attention.
- `--loglevel="<level>"`
  - Sets the logging level for the program. Valid levels are:
    - `debug`
    - `info`
    - `warning`
    - `error`
  - The default logging level is `info`.