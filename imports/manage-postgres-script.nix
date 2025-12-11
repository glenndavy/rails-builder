{pkgs}: ''
  #!${pkgs.runtimeShell}
  set -e

  # Default values
  PGPORT=5432
  COMMAND=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port)
        PGPORT="$2"
        shift 2
        ;;
      start|stop|help)
        COMMAND="$1"
        shift
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: manage-postgres {start|stop|help} [--port PORT]" >&2
        exit 1
        ;;
    esac
  done

  # Default to help if no command given
  if [ -z "$COMMAND" ]; then
    COMMAND="help"
  fi

  export source=$PWD
  export PGDATA=$source/tmp/pgdata
  export PGHOST=$source/tmp
  export PGDATABASE=rails_build
  export PGPORT=$PGPORT

  mkdir -p "$source/tmp"
  chmod u+w "$source/tmp"
  mkdir -p "$PGDATA"
  chmod u+w "$PGDATA"

  case "$COMMAND" in
  	start)
  		if [ -d "$PGDATA" ] && [ -f "$PGDATA/PG_VERSION" ]; then
  			if ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" status; then
  				echo "PostgreSQL is already running."
  				exit 0
  			fi
  		else
  			rm -rf "$PGDATA"
  			mkdir -p "$PGDATA"
  			chmod u+w "$PGDATA"
  			echo "Initializing PostgreSQL cluster..."
  			if ! ${pkgs.postgresql}/bin/initdb -D "$PGDATA" --no-locale --encoding=UTF8 > "$source/tmp/initdb.log" 2>&1; then
  				echo "initdb failed. Log:" >&2
  				cat "$source/tmp/initdb.log" >&2
  				exit 1
  			fi
  			echo "unix_socket_directories = '$PGHOST'" >> "$PGDATA/postgresql.conf"
  			echo "port = $PGPORT" >> "$PGDATA/postgresql.conf"
  		fi
  		echo "Starting PostgreSQL..."
  		if ! ${pkgs.postgresql}/bin/pg_ctl -D "$PGDATA" -l "$source/tmp/pg.log" -o "-k $PGHOST -p $PGPORT" start > "$source/tmp/pg_ctl.log" 2>&1; then
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
  		if ! ${pkgs.postgresql}/bin/psql -h "$PGHOST" -p "$PGPORT" -lqt | cut -d \| -f 1 | grep -qw "$PGDATABASE"; then
  			${pkgs.postgresql}/bin/createdb -h "$PGHOST" -p "$PGPORT" "$PGDATABASE"
  		fi
  		echo "PostgreSQL started successfully."
  		echo "DATABASE_URL: postgresql://$(whoami)@localhost:$PGPORT/$PGDATABASE?host=$PGHOST"
  		;;
  	stop)
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
  		echo "  manage-postgres {start|stop|help} [--port PORT]"
  		echo ""
  		echo "COMMANDS:"
  		echo "  start [--port PORT]  - Initialize and start PostgreSQL server"
  		echo "  stop                 - Stop PostgreSQL server"
  		echo "  help                 - Show this help message"
  		echo ""
  		echo "OPTIONS:"
  		echo "  --port PORT          - Use custom port (default: 5432)"
  		echo ""
  		echo "CONNECTION INFO:"
  		echo "  Database: rails_build"
  		echo "  Host: localhost (via Unix socket in ./tmp/)"
  		echo "  User: $(whoami) (current Unix user)"
  		echo "  Port: $PGPORT"
  		echo ""
  		echo "DATABASE_URL:"
  		echo "  postgresql://$(whoami)@localhost:$PGPORT/rails_build?host=$PWD/tmp"
  		echo ""
  		echo "DIRECT CONNECTION COMMANDS:"
  		echo "  psql -h $PWD/tmp -p $PGPORT -d rails_build"
  		echo "  psql postgresql://$(whoami)@localhost:$PGPORT/rails_build?host=$PWD/tmp"
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
''
