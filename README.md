# BeamMP Environment Sync

This is a work-in-progress BeamNG.drive mod and BeamMP plugin to synchronize an environment defined on the server with connected players.

## Requirements

- https://github.com/rxi/json.lua

See the wiki for additional information.

## Features

### Time of day sync

- Synchronizes the following time of day settings:
    - `dayLength`
    - `time`
    - `dayScale`
    - `nightScale`
    - `azimuthOverride`
    - `play`
- Server admin configures these settings in the `timeOfDay` property of `envsync.json`
