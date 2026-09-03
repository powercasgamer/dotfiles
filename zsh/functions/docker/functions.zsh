# Run `java` in an ephemeral Alpine-based JRE container -- no local
# JDK/JRE needed, and nothing lingers after it exits (--rm). Mounts $PWD
# as /work so relative paths (a jar via -jar, a classpath via -cp, ...)
# resolve the same as running them locally. The image is pulled once and
# cached by docker after that.
#
# Usage: djava [java args...]
#   djava -version
#   djava -jar app.jar foo bar
#   djava -cp . Main
# Override the image (e.g. for a different Java version) with:
#   DJAVA_IMAGE=eclipse-temurin:17-jre-alpine djava -version
djava() {
  local image="${DJAVA_IMAGE:-eclipse-temurin:25-jre-alpine}"
  local tty_flag=(-i)
  [ -t 1 ] && tty_flag=(-it)
  docker run --rm "${tty_flag[@]}" \
    --user "$(id -u):$(id -g)" \
    -v "$PWD:/work" \
    -w /work \
    "$image" \
    java "$@"
}
