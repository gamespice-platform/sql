# GameSpice SQL

SQLite, PostgreSQL and MySQL for the Gamespice family: drivers, one dialect layer, tables as plain data, and versioned migrations. Stores in other addons reach a driver by duck typing, so nothing depends on GameSpice SQL.

Read the family [CLAUDE.md](../../CLAUDE.md) first.

**The distributable is `addons/gs_sql/`.** It requires [GameSpice Core](../gs-core) and nothing else (`ln -s ../../gs-core/addons/gs_core addons/gs_core`, gitignored). The SQLite driver also wants godot-sqlite in `addons/godot-sqlite` (gitignored; `tools/fetch_sqlite.sh .`).

## Read before

| Read | Before |
| --- | --- |
| [docs/design.md](docs/design.md) | changing a driver, the dialect, the schema, migrations or the gateway: the duck-typed contract, where the three databases differ, migrations, the gateway's no-retry rule, SQLite durability, what is deliberately not here |
| [docs/history.md](docs/history.md) | the column named `key`, the missing database directory |

## Layout

| Path | What |
| --- | --- |
| `addons/gs_sql/core/gs_sql.gd` | `GSSql`: `from_config` builds a driver (gateway or SQLite) |
| `addons/gs_sql/core/gs_sql_dialect.gd` | `GSSqlDialect`: frozen `Kind`, column types, `RESERVED`, `is_safe_identifier`, `numbered`, `upsert` |
| `addons/gs_sql/core/gs_sql_schema.gd` | `GSSqlSchema`: a table spec (plain data) to DDL per dialect |
| `addons/gs_sql/core/gs_sql_migrator.gd` | `GSSqlMigrator`: per-component versions in `gs_sql_migrations` |
| `addons/gs_sql/driver/gs_sql_driver.gd` | `GSSqlDriver`: the base and the duck-typed surface (`query`, `execute`, `batch`, `upsert_sql`, `migrate`, `ensure_table`) |
| `addons/gs_sql/driver/gs_sql_driver_gateway.gd` | `GSSqlDriverGateway`: HTTP to a gateway, `/query` and `/batch` |
| `addons/gs_sql/driver/gs_sql_driver_sqlite.gd` | `GSSqlDriverSqlite`: the godot-sqlite extension |
| `addons/gs_sql/driver/gs_sql_driver_recording.gd` | `GSSqlDriverRecording`: records statements, for suites |
| `tools/sql_gateway.py` | the reference gateway (SQLite, Postgres, MySQL) |
| `tools/test_live.sh` | runs a live suite against SQLite, the extension, and any database given a DSN |
| `tools/fetch_sqlite.sh` | installs pinned godot-sqlite into a project |
| `examples/sql_selftest.tscn`, `sql_live.tscn` | the offline suite; the live suite |

## Running and testing

The family's two steps ([family CLAUDE.md](../../CLAUDE.md#validating-anything)), then:

```bash
timeout 120 godot --headless --path . res://examples/sql_selftest.tscn   # offline
tools/fetch_sqlite.sh .                                                  # once, for the extension run
tools/test_live.sh                                                       # sql_live via the gateway on SQLite, then the extension
```

Live against Postgres and MariaDB, through `tools/sql_gateway.py`: a Python with `psycopg` and `pymysql` importable, a Postgres role and database `gs_sql_test`, and a MariaDB 11 container on 127.0.0.1:13306 (for example `docker run -d --name gs-sql-mariadb -p 127.0.0.1:13306:3306 -e MARIADB_DATABASE=gs_sql_test -e MARIADB_USER=gs_sql_test -e MARIADB_PASSWORD=... -e MARIADB_RANDOM_ROOT_PASSWORD=1 mariadb:11`):

```bash
GS_SQL_PYTHON=<venv>/bin/python \
GS_SQL_PG_DSN=postgresql://gs_sql_test:...@127.0.0.1/gs_sql_test \
GS_SQL_MYSQL_DSN=mysql://gs_sql_test:...@127.0.0.1:13306/gs_sql_test tools/test_live.sh
```

The runner takes a project and a scene, so every store's live suite runs the same way: `tools/test_live.sh ../gs-timer res://examples/timer_sql_live.tscn`, and likewise gs-moderation, gs-leaderboard, gs-achievements and gs-stats (`examples/<addon>_sql_live.tscn`). The extension prints `ERROR:  --> SQL error` for every failing statement, including ones a suite fails on purpose; `test_live.sh` filters those and still fails on `SCRIPT ERROR` or `Parse Error`.

## Rules that bite

- Never name a `GSSql*` class from a store or a delivered game; hold the driver untyped, or load `gs_sql.gd` by path. [design](docs/design.md#stores-reach-a-driver-duck-typed)
- `?` placeholders everywhere; wrap integers from rows in `int()`; always `await`. [design](docs/design.md#stores-reach-a-driver-duck-typed)
- `GSSqlDialect.Kind` values are frozen; other repos compare against 0, 1, 2. [design](docs/design.md#stores-reach-a-driver-duck-typed)
- A dialect difference is handled in `GSSqlDialect` or `GSSqlSchema` once, never in a store; never use a `RESERVED` word as a column. [design](docs/design.md#where-the-three-differ-handled-once)
- Bind computed values rather than `SET a = …, b = a + …`: MySQL reads the new `a`. [design](docs/design.md#where-the-three-differ-handled-once)
- Append a migration step, never edit one; name components `<addon>:<prefix or table>`. [design](docs/design.md#migrations)
- The gateway's `GSHttp` never retries; a refused statement is a 200 carrying `error`. [design](docs/design.md#the-gateway)
- The gateway's token comes from a file, never argv; its fence is the database user. [design](docs/design.md#the-gateway)
- Headless Godot gets no notification on SIGINT or SIGTERM: a store writes as it goes, never at exit. [design](docs/design.md#sqlite-through-the-extension)
- Run the live suites against all three databases after a dialect or schema change; SQLite alone accepts what MySQL refuses. [history](docs/history.md#a-column-named-key)
