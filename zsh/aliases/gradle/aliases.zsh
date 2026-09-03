alias deletegradle="rm -rf ~/.gradle/daemon"

# ./gradlew build, skipping tests
alias gbuild="./gradlew build -x test"

# Full clean rebuild: no build cache, fresh dependency resolution, no daemon
alias cleangradle="./gradlew clean build --no-build-cache --refresh-dependencies --no-daemon"

# Parallel, cached, no-daemon build for fast local iteration, skipping tests.
# (--build-cache/--parallel/--configure-on-demand/--no-watch-fs already set
# their -D equivalents, so those aren't repeated here.)
alias fastgradle='./gradlew --build-cache --parallel --configure-on-demand --no-watch-fs --no-daemon -x test -Dorg.gradle.jvmargs="-Xmx16g -XX:+UseParallelGC -XX:MaxMetaspaceSize=1g"'
