---
sidebar_label: Docker
---

# Doom 3 Docker Container

This Docker container runs a Doom 3 dedicated server. It is built on the base image and runs the dedicated server of [dhewm3](https://dhewm3.org/) (`dhewm3ded`), which the image compiles from the latest dhewm3 release at build time (`DHEWM3_VERSION` pins one). You supply the retail game data.

## Quick Start

```yaml
services:
  doom3:
    image: lancommander/doom3:latest
    container_name: doom3

    ports:
      - 27666:27666/udp

    volumes:
      - "/data/Servers/Doom 3/Deathmatch:/config"

    environment:
      D3_SERVER_NAME: "My Doom 3 Server"
      D3_MAP: "game/mp/d3dm4"
      D3_RCON_PASSWORD: "changeme"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Before the first start, copy the retail `base/` folder (`pak000.pk4` to `pak008.pk4`) into `Server/`, and `d3xp/` too for Resurrection of Evil.

## How It Starts

1. `PostInitialization/30-ConfigureDoom3.ps1` checks for `base/pak000.pk4` and writes the non-empty `D3_*` settings into `<D3_GAME>/lancommander.cfg` as `set` commands. That file starts with `exec server.cfg`, so your own `server.cfg` runs first and the `D3_*` settings override it. The hook writes through `Merged/`, so the file lands in `Overlay/`.
2. `START_EXE` (`/usr/local/bin/d3-server`) runs from `Merged/`:

   ```text
   /opt/dhewm3/dhewm3ded +set fs_basepath /config/Merged +set fs_savepath /config/Merged
       +set fs_configpath /config/Merged [+set fs_game <D3_GAME>] +set net_port 27666
       +set net_LANServer 1 +exec lancommander.cfg <START_ARGS> +spawnServer
   ```

   Base, save and config paths all point at `Merged/`, so the server's `dhewm.cfg` and anything else it writes land in `Overlay/<game>/`. The game libraries (`base.so`, `d3xp.so`) are next to `dhewm3ded` in `/opt/dhewm3`.

The server console prints to `docker logs`.

## Configuration Options

### Ports

- **27666/udp**: game, server info queries and LAN browser (`D3_PORT`). The client's LAN browser broadcasts `getInfo` to ports 27666-27673, so a server on another port in that range is still found.

### Environment Variables

See the [README](../README.md#environment-variables) for the full table.

### server.cfg

`Overlay/<D3_GAME>/server.cfg` is yours to create and edit. Any console command works there, for example `set g_gameReviewPause 5`, `set g_voteFlags 0`, `set g_mapCycle mapcycle` or `set si_serverURL "..."`. `D3_*` variables that are set override the same settings in it; clear a variable (set it to `""`) to control that setting from `server.cfg` instead.

### Map rotation

After each round the server runs the `mapcycle` script (`g_mapCycle`) from `mapcycle.scriptcfg` in the game's `pak000.pk4`. It replays each map twice (Tourney: 3 times, 7 in d3xp) and then moves on to the next stock map. To change the rotation, copy the script out of the pak, edit it and put it in `Overlay/<D3_GAME>/mapcycle.scriptcfg`. `.scriptcfg` files are allowed outside pure paks.

### Maps and game types

| Game | Maps | Game types |
|------|------|------------|
| `base` | `game/mp/d3dm1` to `game/mp/d3dm5` | `deathmatch`, `Tourney`, `Team DM`, `Last Man` |
| `d3xp` | `game/mp/d3xpdm1` to `game/mp/d3xpdm4`, `game/mp/d3ctf1` to `game/mp/d3ctf4` | the above, plus `CTF` (CTF maps only) |

### Hooks

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/` to run at the base image's lifecycle hooks (`PreInitialization`, `PostInitialization`, `ServerStarted`, `ServerStopped`).

## Troubleshooting

- **`base/pak000.pk4 not found`**: the retail game data isn't in `Server/`. Copy `base/` (and `d3xp/`) from a Doom 3 install.
- **Clients get "pure" or checksum errors**: client and server need the same `.pk4` files. Give clients the same paks, or set `D3_PURE=0`.
- **Clients can't connect**: clients need dhewm3 1.5.x. Every 1.5.x release uses network protocol 1.42, so mixed 1.5.x versions should work, but the same version on both sides is the safest. The original Doom 3 executables are untested. `cat /opt/dhewm3/VERSION` in the container shows the server's version.
- **Server not in the LAN browser**: the browser finds servers by UDP broadcast, so the container needs its own LAN address (macvlan/ipvlan) or host networking. With port mapping, clients join by IP (`connect <ip>:27666` in the console).
- **`D3_MAX_PLAYERS` capped at 4**: Doom 3 allows at most 4 players; Resurrection of Evil (`D3_GAME=d3xp`) allows 8.
