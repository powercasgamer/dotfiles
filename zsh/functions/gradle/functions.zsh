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
  if ! command -v gradle >/dev/null 2>&1; then
    echo "Error: gradle not found on PATH." >&2
    return 1
  fi
  gradle --stop
  sleep 15
  if pkill -9 -f GradleDaemon; then
    echo "Force-killed a lingering GradleDaemon."
  fi
}

# Bump the project's Gradle wrapper: `update-gradle 9.2.0`, or no argument
# for the latest release. The second `:wrapper` run happens on the new
# version, so it regenerates gradle-wrapper.jar and the gradlew scripts too,
# not just gradle-wrapper.properties.
update-gradle() {
  if [[ ! -x ./gradlew ]]; then
    echo "Error: no ./gradlew in $PWD." >&2
    return 1
  fi
  local version=$1
  if [[ -z $version ]]; then
    version=$(curl -fsSL https://services.gradle.org/versions/current |
      sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p')
    if [[ -z $version ]]; then
      echo "Error: couldn't fetch the latest Gradle version." >&2
      return 1
    fi
  fi
  echo "Updating Gradle wrapper to $version..."
  ./gradlew :wrapper --gradle-version="$version" && ./gradlew :wrapper
}
