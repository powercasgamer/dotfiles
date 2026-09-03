# Run `java` in an ephemeral container -- no local JDK/JRE needed, and
# nothing lingers after it exits (--rm). Mounts $PWD as /work so relative
# paths (a jar via -jar, a classpath via -cp, ...) resolve the same as
# running them locally.
#
# Usage: djava [java args...]
#   djava -version
#   djava -jar app.jar foo bar
#   djava -cp . Main
#
# Defaults to dotfiles-java-slim:25 -- a jlink-trimmed JRE (~95MB vs
# ~287MB stock, see java/Dockerfile for the module list and why) built
# automatically the first time it's needed, then reused. If a jar needs a
# module that trimmed image doesn't have (jdeps <jar> will tell you),
# either rebuild java/Dockerfile with it added, or override the image:
#   DJAVA_IMAGE=eclipse-temurin:25-jre-alpine djava -version
djava() {
  local default_image="dotfiles-java-slim:25"
  local image="${DJAVA_IMAGE:-$default_image}"
  local dotfiles_dir="${DJAVA_DOTFILES_DIR:-$HOME/dotfiles}"

  if [ "$image" = "$default_image" ] && ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "==> Building $image (jlink-trimmed JRE, one-time) from $dotfiles_dir/java" >&2
    docker build -t "$image" "$dotfiles_dir/java" >&2 || return 1
  fi

  local tty_flag=(-i)
  [ -t 1 ] && tty_flag=(-it)
  docker run --rm "${tty_flag[@]}" \
    --user "$(id -u):$(id -g)" \
    -v "$PWD:/work" \
    -w /work \
    "$image" \
    java "$@"
}
