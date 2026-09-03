# Force-kill any stray gradle/Kotlin-daemon processes, e.g. after a build
# hangs. pkill -f matches the whole command line directly, so this needs no
# ps|grep|awk|kill pipeline (and no `grep -v grep` to avoid self-matching).
killgradlehard() {
  if pkill -9 -f -i gradle; then
    echo "Killed all gradle processes."
  else
    echo "No gradle processes found."
  fi
}

# Graceful daemon stop, falling back to a hard kill of anything still
# around after gradle's own shutdown window.
killgradle() {
  gradle --stop
  sleep 15
  if pkill -9 -f GradleDaemon; then
    echo "Force-killed a lingering GradleDaemon."
  fi
}
