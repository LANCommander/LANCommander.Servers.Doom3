# Doom 3 Server (Docker)

This repository provides a Dockerized **Doom 3** dedicated server. It runs the dedicated server of [dhewm3](https://dhewm3.org/) 1.5.2 (`dhewm3ded`), built from source into the image, with your retail Doom 3 game data. Resurrection of Evil (`d3xp`) is supported.
The image builds on [`lancommander/base`](https://github.com/LANCommander/LANCommander.Servers.Base). It supports file overlaying using OverlayFS.

---

## Features

- dhewm3 1.5.2 dedicated server and `base`/`d3xp` game libraries for Linux, built from the pinned and SHA256-verified source release
- The server's name, map, game type, limits and passwords are environment variables, written into a config file the server execs at startup
- LAN mode by default (`net_LANServer 1`): the server answers LAN browser broadcasts and never contacts the id master server
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  doom3:
    image: lancommander/doom3:latest
    container_name: doom3

    ports:
      - "27666:27666/udp"

    volumes:
      - ./config:/config

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

The in-game LAN browser finds servers by broadcast. That needs the container on the LAN itself (macvlan/ipvlan, or `network_mode: host`); with port mapping, clients join by IP (`connect <ip>` in the console).

---

## Game Files

The image contains only the dhewm3 binaries. Copy the `base/` folder of a retail Doom 3 install (`pak000.pk4` to `pak008.pk4`, patched to 1.3.1) into `config/Server/`, and also `d3xp/` (`pak000.pk4`, `pak001.pk4`) for Resurrection of Evil. Nothing else from the install is needed. The server stops with an error if `base/pak000.pk4` is missing.

Clients must run dhewm3 1.5.2 with the same paks. With `D3_PURE=1` (the default), the server makes clients use its pak files only.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Retail game data: base/pak00*.pk4, d3xp/pak00*.pk4
    ├── Overlay/           # Your files, layered on top of Server/ (base/server.cfg, generated lancommander.cfg, dhewm.cfg)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [base image's variables](https://github.com/LANCommander/LANCommander.Servers.Base#environment).
The settings are written into `<D3_GAME>/lancommander.cfg` on every start. Settings left empty are left out, so you can set them in `<D3_GAME>/server.cfg` instead.

| Variable | Description | Default |
|----------|-------------|---------|
| `D3_GAME` | Game folder: `base` (Doom 3) or `d3xp` (Resurrection of Evil), or a mod folder (`fs_game`) | `base` |
| `D3_PORT` | `net_port` (game port) | `27666` |
| `D3_LAN` | `net_LANServer`: `true` is LAN only; `false` also registers with the id master server | `true` |
| `D3_SERVER_NAME` | `si_name` | `Doom 3 Server` |
| `D3_MAP` | `si_map`, the first map (`game/mp/d3dm1` to `game/mp/d3dm5`; d3xp adds `game/mp/d3xpdm1` to `d3xpdm4` and `game/mp/d3ctf1` to `d3ctf4`) | `game/mp/d3dm1` |
| `D3_GAME_TYPE` | `si_gameType`: `deathmatch`, `Tourney`, `Team DM`, `Last Man`, and with d3xp `CTF` | `deathmatch` |
| `D3_MAX_PLAYERS` | `si_maxPlayers` (up to 4 for Doom 3, 8 for d3xp) | `4` |
| `D3_FRAG_LIMIT` | `si_fragLimit` | `10` |
| `D3_TIME_LIMIT` | `si_timeLimit` in minutes (0 = none) | `10` |
| `D3_PASSWORD` | `g_password`; also sets `si_usePass 1` | |
| `D3_RCON_PASSWORD` | `net_serverRemoteConsolePassword` | |
| `D3_PURE` | `si_pure`: clients may only use the server's paks | `1` |
| `D3_WARMUP` | `si_warmup` | `0` |
| `D3_TEAM_DAMAGE` | `si_teamDamage` | `0` |
| `D3_SPECTATORS` | `si_spectators` | `1` |
| `START_EXE` | Launcher | `/usr/local/bin/d3-server` |
| `START_ARGS` | Extra console commands, inserted before `+spawnServer` (e.g. `+set g_gameReviewPause 5`) | |

The map rotation is the `mapcycle.scriptcfg` script in the game's `pak000.pk4` (`g_mapCycle`). It plays each map twice (Tourney: 3 times, 7 in d3xp) and then moves to the next stock map. To change it, put your own `mapcycle.scriptcfg` in `Overlay/<D3_GAME>/`; `.scriptcfg` files load even on pure servers.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/base:latest` by default. A build stage compiles dhewm3 (`DHEWM3_VERSION`, verified by `DHEWM3_SHA256`). To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/base:local -t lancommander/doom3:local .
```

---

## License

Doom 3 is a trademark of id Software. Its game data is not included and is distributed under its own license. dhewm3 is GPLv3.
This repository contains only Docker build logic and helper scripts licensed under MIT.
