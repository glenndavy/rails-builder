{pkgs}: ''
  #!${pkgs.runtimeShell}

  # Default values
  REDIS_PORT=6379
  COMMAND=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port)
        REDIS_PORT="$2"
        shift 2
        ;;
      start|stop|help)
        COMMAND="$1"
        shift
        ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: manage-redis {start|stop|help} [--port PORT]" >&2
        exit 1
        ;;
    esac
  done

  # Default to help if no command given
  if [ -z "$COMMAND" ]; then
    COMMAND="help"
  fi

  export source=$PWD
  echo "DEBUG: Starting manage-redis $COMMAND --port $REDIS_PORT" >&2
  echo "DEBUG: Source = $source" >&2
  export REDIS_PID=$source/tmp/redis.pid
  case "$COMMAND" in
    start)
      if [ -f "$REDIS_PID" ] && kill -0 $(cat $REDIS_PID) 2>/dev/null; then
        echo "Redis is already running."
        exit 0
      fi
      mkdir -p $source
      ${pkgs.redis}/bin/redis-server --pidfile $REDIS_PID --daemonize yes --port $REDIS_PORT
      sleep 2
      if ! ${pkgs.redis}/bin/redis-cli -p $REDIS_PORT ping | grep -q PONG; then
        echo "Failed to start Redis."
        exit 1
      fi
      echo "Redis started successfully. REDIS_URL: redis://localhost:$REDIS_PORT/0"
      ;;
    stop)
      echo "DEBUG: Stopping Redis" >&2
      if [ -f "$REDIS_PID" ] && kill -0 $(cat $REDIS_PID) 2>/dev/null; then
        kill $(cat $REDIS_PID)
        rm -f $REDIS_PID
        echo "Redis stopped."
      else
        echo "Redis is not running or PID file not found."
      fi
      ;;
    help)
      echo "manage-redis - Redis development server management"
      echo ""
      echo "USAGE:"
      echo "  manage-redis {start|stop|help} [--port PORT]"
      echo ""
      echo "COMMANDS:"
      echo "  start [--port PORT]  - Start Redis server"
      echo "  stop                 - Stop Redis server"
      echo "  help                 - Show this help message"
      echo ""
      echo "OPTIONS:"
      echo "  --port PORT          - Use custom port (default: 6379)"
      echo ""
      echo "CONNECTION INFO:"
      echo "  Host: localhost"
      echo "  Port: $REDIS_PORT"
      echo "  Database: 0 (default)"
      echo ""
      echo "REDIS_URL:"
      echo "  redis://localhost:$REDIS_PORT/0"
      echo ""
      echo "DIRECT CONNECTION COMMANDS:"
      echo "  redis-cli -p $REDIS_PORT"
      echo "  redis-cli -p $REDIS_PORT ping"
      echo ""
      echo "DATA LOCATION:"
      echo "  PID file: $PWD/tmp/redis.pid"
      ;;
    *)
      echo "Usage: manage-redis {start|stop|help} [--port PORT]" >&2
      echo "Run 'manage-redis help' for detailed information" >&2
      exit 1
      ;;
  esac
  echo "DEBUG: manage-redis completed" >&2
''
