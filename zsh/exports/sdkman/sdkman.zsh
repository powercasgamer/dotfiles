# SDKMAN (https://sdkman.io) -- candidate version manager for Java, Kotlin,
# Groovy, Gradle, Maven, sbt, Scala, and friends. Installed by
# sdkman/setup.sh, which strips the init snippet the upstream installer
# wants to append directly to this tracked zshrc; sourced here instead.
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
