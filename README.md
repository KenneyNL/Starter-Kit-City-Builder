<p align="center"><img src="icon.png"/></p>

# Starter Kit City Builder

This package includes a basic template for a 3D city builder in Godot 4.5 (stable). Includes features like;

- Building and removing structures
- Smooth camera controls
- Dynamic MeshLibrary creation
- Saving/loading
- Sprites and 3D Models _(CC0 licensed)_

### Screenshot

<p align="center"><img src="screenshots/screenshot.png"/></p>

### Controls

| Key | Command |
| --- | --- |
| <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> | Move camera |
| <kbd>F</kbd> | Camera to center |
| <kbd>Middle mouse button</kbd> | Hold to rotate camera |
| <kbd>Scroll wheel</kbd> | Zoom |
| <kbd>Left mouse button</kbd> | Place building |
| <kbd>DEL</kbd> | Remove building |
| <kbd>Right mouse button</kbd> | Rotate building |
| <kbd>Q</kbd> <kbd>E</kbd>  | Toggle between buildings |
| <kbd>F1</kbd> | Save |
| <kbd>F2</kbd> | Load |

### Instructions

#### 1. How to add more buildings?

Duplicate one of the existing resources in the 'structures' folder, adjust the properties in the inspector. Select the 'Builder' node in the scene and add your new resources to the 'Structures' array.

#### 2. How to adjust building models?

Select the resource of the building you'd like to change in the 'structures' folder, adjust the model in the inspector.

#### 3. How to save and load cities?

Pressing F1 during gameplay will save the current city to disk, F2 will load it from the same location. The file is saved as 'map.res' in the user folder (see below). You can adjust this in the 'action_save' and 'action_load' functions found in the 'builder.gd' script.

User data folder:

> Windows: `%APPDATA%/Godot/app_userdata/Starter Kit City Builder/`

> Linux: `~/.local/share/godot/app_userdata/Starter Kit City Builder/`

> MacOS: `~/Library/Application Support/Godot/app_userdata/Starter Kit City Builder/`

#### 4. How to include city data in the project and load this?

You'll find a sample map in the 'sample map' folder, to load this during gameplay press F3. You can find the function that handles this as 'action_load_resources' found in the 'builder.gd' script.

### License

MIT License

Copyright (c) 2025 Kenney

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Assets included in this package (2D sprites, 3D models and sound effects) are [CC0 licensed](https://creativecommons.org/publicdomain/zero/1.0/)
