{pkgs}: ''
  #!${pkgs.runtimeShell}
  export source=$PWD
  echo "DEBUG: Starting manage-redis $1" >&2
  echo "DEBUG: Source = $source" >&2
  export REDIS_PID=$source/tmp/redis.pid
  case "$1" in
    start)
      if [ -f "$REDIS_PID" ] && kill -0 $(cat $REDIS_PID) 2>/dev/null; then
        echo "Redis is already running."
        exit 0
      fi
      mkdir -p $source
      ${pkgs.redis}/bin/redis-server --pidfile $REDIS_PID --daemonize yes --port 6379
      sleep 2
      if ! ${pkgs.redis}/bin/redis-cli ping | grep -q PONG; then
        echo "Failed to start Redis."
        exit 1
      fi
      echo "Redis started successfully. REDIS_URL: redis://localhost:6379/0"
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
    *)
      echo "Usage: manage-redis {start|stop}" >&2
      exit 1
      ;;
  esac
  echo "DEBUG: manage-redis completed" >&2
''
