# Run a .jar in an ephemeral Alpine-based JRE container -- no local
# JDK/JRE needed, and nothing lingers after it exits (--rm). Mounts $PWD
# (not just the jar's directory) as /work so relative paths in the jar's
# own args resolve the same as running it locally -- only works for
# jars/paths that live under $PWD. The image is pulled once and cached by
# docker after that.
#
# Usage: djar <path/to/app.jar> [java args...]
# Override the image (e.g. for a different Java version) with:
#   DJAR_IMAGE=eclipse-temurin:17-jre-alpine djar app.jar
djar() {
  if [ $# -eq 0 ]; then
    echo "Usage: djar <path/to/app.jar> [java args...]" >&2
    return 1
  fi
  local image="${DJAR_IMAGE:-eclipse-temurin:21-jre-alpine}"
  local tty_flag=(-i)
  [ -t 1 ] && tty_flag=(-it)
  docker run --rm "${tty_flag[@]}" \
    --user "$(id -u):$(id -g)" \
    -v "$PWD:/work" \
    -w /work \
    "$image" \
    java -jar "$@"
}
