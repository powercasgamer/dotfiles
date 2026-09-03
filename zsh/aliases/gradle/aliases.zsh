# ./gradlew build, skipping tests
alias gbuild="./gradlew build -x test"

# Full clean rebuild: no build cache, fresh dependency resolution, no daemon
alias cleangradle="./gradlew clean build --no-build-cache --refresh-dependencies --no-daemon"
