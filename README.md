[![dot-sql - GameSpice addon](docs/banner.png)](https://moddingcommunity.com/a/264-dot-sql)

Lets Gamespice addons keep their data in SQLite, PostgreSQL or MySQL/MariaDB, so records, statistics, achievements and bans can live in a real database that several servers share. Godot has no database client of its own; this is the layer that supplies one.

## Install

1. Get [Godot 4.7](https://godotengine.org/download).
2. Either use [dot-bootstrap](https://github.com/gamespice-platform/bootstrap), which clones every project and links the addons, or copy `addons/dot_sql/` and [dot-core](https://github.com/gamespice-platform/core)'s `addons/dot_core/` into your project and enable dot-sql in *Project > Project Settings > Plugins*.
3. For SQLite, run `tools/fetch_sqlite.sh <your project>`. It installs a pinned, checksummed release of [godot-sqlite](https://github.com/2shady4u/godot-sqlite) (MIT) into `addons/godot-sqlite`. This addon does not ship it.

dot-core is the only dependency.

## What is in it

| Piece | What it is |
| --- | --- |
| `DotSqlDriverSqlite` | SQLite through godot-sqlite. One server, one file. |
| `DotSqlDriverGateway` | PostgreSQL, MySQL/MariaDB or SQLite through a small HTTP gateway running beside the database. Several servers, one database. |
| `tools/sql_gateway.py` | A reference gateway in Python. It handles one request at a time: fine for a few servers, meant to be copied rather than scaled. |
| `DotSqlDialect` | Everywhere the databases differ: column types, upserts, placeholders, reserved words. |
| `DotSqlSchema` | Tables described as data and turned into SQL for each database. |
| `DotSqlMigrator` | Versioned schema changes, one counter per asset. |
| `DotSql.from_config` | Builds a driver from a config dictionary, so a server picks its database in a file. |

## Use

```gdscript
# One SQLite file on this server:
var made := DotSql.from_config({"driver": "sqlite", "path": "user://game.db"}, self)

# A shared MySQL or PostgreSQL database through the gateway:
var made := DotSql.from_config({
    "driver": "gateway", "dialect": "mysql",
    "url": "http://10.0.0.5:8780", "token": "from your config file",
}, self)

var store := DotTimerStoreSql.new(made.value)
await store.open()          # creates or migrates its tables
timers.store = store
```

Keep the token in the config file. Environment variables and command lines are readable by every process on the machine.

Run the reference gateway:

```bash
pip install "psycopg[binary]" pymysql      # only the one you need
echo "a long random token" > gateway.token
python3 tools/sql_gateway.py --dialect mysql --dsn mysql://user:pass@127.0.0.1:3306/game --token-file gateway.token
```

The gateway takes a bearer token on every request. Keep it on a private address or put TLS in front. It is the safer setup anyway: the database password stays on the gateway's machine, and the gateway can connect as a user that only touches the game's tables.

## Other addons do not need this one

dot-timer, dot-moderation, dot-leaderboard, dot-achievements and dot-stats each have a SQL store. They hold the driver in an untyped variable and call five methods on it (`query`, `execute`, `batch`, `upsert_sql`, `migrate`), so they load without dot-sql.

## Testing

| Scene | Checks |
| --- | --- |
| `examples/sql_selftest.tscn` | Dialects, placeholders, table specs, upserts, migrations and config, with no database. |
| `examples/sql_live.tscn` | Real tables, upserts, emoji and quotes, transactions and migrations against a real database. |

Import the project once, then run each scene headless with Godot. `tools/test_live.sh` runs the live suite on SQLite; set `GS_SQL_PG_DSN` and `GS_SQL_MYSQL_DSN` to include PostgreSQL and MySQL. It also runs other addons' live suites, such as `tools/test_live.sh ../dot-timer res://examples/timer_sql_live.tscn`.

## Status and licence

Part of the [Gamespice](https://gamespice.net) platform: a family of Godot addons. Written with Claude Code and maintained by `gamemann`. Every addon has headless tests, but little of this has been played by real users yet, so expect rough edges and please [open an issue](https://github.com/gamespice-platform/sql/issues) when you hit one.

MIT licence, see [LICENSE](LICENSE). The only closed part of the [Gamespice](https://gamespice.net) platform is the web back end; you can use your own instead of Gamespice's.
