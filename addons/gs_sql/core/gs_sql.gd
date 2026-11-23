@tool
class_name GSSql
extends RefCounted

## Builds a driver from configuration, so a game's config file chooses the database.
##
## [codeblock]
## # cfg: { "sql": { "driver": "sqlite", "path": "user://airdrift.db" } }
## # cfg: { "sql": { "driver": "gateway", "url": "http://10.0.0.5:8780", "dialect": "mysql",
## #                 "token": "..." } }
## var made := GSSql.from_config(config.sql, self)
## if made.ok:
##     var driver: GSSqlDriver = made.value
##     await driver.open()
## [/codeblock]
##
## [b]The token belongs in the JSON file and nowhere else.[/b] Environment variables and
## argv are readable by every process on the box and end up in `ps` and in pasted bug
## reports, which is why [code]GSConfig.sensitive_keys[/code] refuses secrets from both.
## A key named [code]sql_token[/code] in a game's config is refused the same way, so this
## takes the token from the dictionary it is handed and expects that to come from the file.
##
## [b]One driver per database, shared by every store that keeps data in it.[/b] Records,
## statistics, achievements and bans in one SQLite file is one connection and one place to
## back up; each store prefixes its own tables, so they never collide.


## A driver for [param config], not yet open. [param host] is where the gateway's
## [GSHttp] is parented, since [HTTPRequest] is a Node; ignored for SQLite.
##
## An empty driver name, or "none", is a success carrying null: no database configured is
## a normal setup, and the stores above fall back to their file implementations.
static func from_config(config: Dictionary, host: Node = null) -> GSResult:
	var kind := str(config.get("driver", "")).strip_edges().to_lower()

	match kind:
		"", "none", "off", "file":
			return GSResult.success(null)

		"sqlite", "sqlite3":
			var path := str(config.get("path", GSSqlDriverSqlite.default_path()))
			if path.strip_edges() == "":
				return GSResult.fail(GSError.CODE_INVALID, "The SQLite driver needs a path.")
			return GSResult.success(GSSqlDriverSqlite.new(path))

		"gateway", "http", "postgres", "postgresql", "mysql", "mariadb":
			var url := str(config.get("url", ""))
			var dialect_name := str(config.get("dialect", kind if kind not in ["gateway", "http"] else "postgres"))
			var dialect := GSSqlDialect.from_name(dialect_name)
			if dialect < 0:
				return GSResult.fail(GSError.CODE_INVALID, "Unknown SQL dialect.", dialect_name)
			if url.strip_edges() == "":
				return GSResult.fail(
					GSError.CODE_INVALID, "A SQL gateway needs a url.",
					"Postgres and MySQL are reached through an HTTP gateway; see gs-sql's README"
				)
			if not (url.begins_with("http://") or url.begins_with("https://")):
				return GSResult.fail(GSError.CODE_INVALID, "The gateway url must be http(s).", url)
			if host == null:
				return GSResult.fail(
					GSError.CODE_STATE, "A SQL gateway needs a host node for its GSHttp."
				)

			var driver := GSSqlDriverGateway.new(url, dialect)
			driver.token = str(config.get("token", ""))

			var http := GSHttp.new()
			http.name = "SqlGatewayHttp"
			# Statements are not idempotent; see GSSqlDriverGateway.open().
			http.max_retries = 0
			http.timeout_sec = float(config.get("timeout_sec", 10.0))
			host.add_child(http)
			driver.http = http

			return GSResult.success(driver)

	return GSResult.fail(
		GSError.CODE_INVALID, "Unknown SQL driver.",
		"%s (expected sqlite, gateway, or none)" % kind
	)
