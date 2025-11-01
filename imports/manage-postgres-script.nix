#      manage-postgres = pkgs.writeShellScriptBin "manage-postgres" ''
{pkgs}: ''
  #!${pkgs.runtimeShell}
  set -e
  echo "DEBUG: Starting manage-postgres $1" >&2
  export source=$PWD
  export PGDATA=$source/tmp/pgdata
  export PGHOST=$source/tmp
  export PGDATABASE=rails_build
  echo "DEBUG: source=$source" >&2
  echo "DEBUG: PGDATA=$PGDATA" >&2
  echo "DEBUG: PGHOST=$PGHOST" >&2
  echo "DEBUG: Checking write permissions for $source/tmp" >&2
  mkdir -p "$source/tmp"
  chmod u+w "$source/tmp"
  ls -ld "$source/tmp" >&2
  mkdir -p "$PGDATA"
  chmod u+w "$PGDATA"
  case "$1" in
  	start)
  		echo "DEBUG: Checking PGDATA validity" >&2
  		if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
  			echo "DEBUG: Valid cluster found, checking status" >&2
  			if ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" status; then
  				echo "PostgreSQL is already running."
  				exit 0
  			fi
  		else
  			echo "DEBUG: No valid cluster, initializing" >&2
  			rm -rf "$PGDATA"
  			mkdir -p "$PGDATA"
  			chmod u+w "$PGDATA"
  			echo "Running initdb..." >&2
  			if ! ${pkgs.postgresql}/bin/initdb -D "$PGDATA" --no-locale --encoding=UTF8 > "$source/tmp/initdb.log" 2>&1; then
  				echo "initdb failed. Log:" >&2
  				cat "$source/tmp/initdb.log" >&2
  				exit 1
  			fi
  			echo "unix_socket_directories = '$PGHOST'" >> "$PGDATA/postgresql.conf"
  		fi
  		echo "Starting PostgreSQL..." >&2
  		if ! ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" -l "$source/tmp/pg.log" -o "-k $PGHOST" start > "$source/tmp/pg_ctl.log" 2>&1; then
  			echo "pg_ctl start failed. Log:" >&2
  			cat "$source/tmp/pg_ctl.log" >&2
  			exit 1
  		fi
  		sleep 2
  		if ! ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" status; then
  			echo "PostgreSQL failed to start." >&2
  			cat "$source/tmp/pg.log" >&2
  			exit 1
  		fi
  		if ! ${pkgs.postgresql}/bin/psql -h "$PGHOST" -lqt | cut -d \| -f 1 | grep -qw "$PGDATABASE"; then
  			${pkgs.postgresql}/bin/createdb -h "$PGHOST" "$PGDATABASE"
  		fi
  		echo "PostgreSQL started successfully. DATABASE_URL: postgresql://$USER@localhost/$PGDATABASE?host=$PGHOST" >&2
  		;;
  	stop)
  		echo "DEBUG: Stopping PostgreSQL" >&2
  		if [ -d "$PGDATA" ] && ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" status; then
  			${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" stop
  			echo "PostgreSQL stopped."
  		else
  			echo "PostgreSQL is not running or PGDATA not found."
  		fi
  		;;
  	help)
  		echo "manage-postgres - PostgreSQL development server management"
  		echo ""
  		echo "USAGE:"
  		echo "  manage-postgres {start|stop|help}"
  		echo ""
  		echo "COMMANDS:"
  		echo "  start  - Initialize and start PostgreSQL server"
  		echo "  stop   - Stop PostgreSQL server"
  		echo "  help   - Show this help message"
  		echo ""
  		echo "CONNECTION INFO:"
  		echo "  Database: rails_build"
  		echo "  Host: localhost (via Unix socket in ./tmp/)"
  		echo "  User: $USER (current Unix user)"
  		echo "  Port: 5432 (default)"
  		echo ""
  		echo "DATABASE_URL FORMAT:"
  		echo "  postgresql://$USER@localhost/rails_build?host=$PWD/tmp"
  		echo ""
  		echo "DIRECT CONNECTION COMMANDS:"
  		echo "  psql -h $PWD/tmp -d rails_build"
  		echo "  psql postgresql://$USER@localhost/rails_build?host=$PWD/tmp"
  		echo ""
  		echo "DATA LOCATION:"
  		echo "  Data directory: $PWD/tmp/pgdata"
  		echo "  Socket directory: $PWD/tmp"
  		echo "  Log file: $PWD/tmp/pg.log"
  		;;
  	*)
  		echo "Usage: manage-postgres {start|stop|help}" >&2
  		echo "Run 'manage-postgres help' for detailed information" >&2
  		exit 1
  		;;
  esac
  echo "DEBUG: manage-postgres completed" >&2
''
