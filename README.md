# BeamMP Environment Sync

This is a work-in-progress BeamNG.drive mod and BeamMP plugin to synchronize an environment defined on the server with connected players.

## Installation

See the wiki.

## Features

### Time of day sync

- Synchronizes the following time of day settings:
    - `dayLength`
    - `time`
    - `dayScale`
    - `nightScale`
    - `azimuthOverride`
    - `play`
- Server admin configures startup settings in the `timeOfDay` property of `envsync.json`

### Set time of day via chat command

- Configured admins can use the `/env set time` command via multiplayer chat to set the server's time of day and trigger a sync
