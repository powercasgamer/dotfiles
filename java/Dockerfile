# Trimmed JRE built with jlink -- keeps only the modules most JVM
# apps/services actually need (see --add-modules below) instead of the
# full JDK/JRE module set. GUI (java.desktop) and dev-only tooling
# (javac/jshell/jconsole/jdb/...) are deliberately left out: this image is
# for running jars/classes, not developing them. ~95MB vs ~287MB for the
# stock eclipse-temurin:25-jre-alpine.
#
# Built automatically by djava (zsh/functions/docker/functions.zsh) the
# first time it's called, and reused after that. Rebuild by hand with:
#   docker build -t dotfiles-java-slim:25 ~/dotfiles/java
#
# jdk.crypto.ec is easy to forget and breaks HTTPS to a lot of real-world
# servers (many TLS handshakes need its elliptic-curve support) --
# verified working here against a live HTTPS request. If your app needs a
# module not in this list (jdeps <jar> will tell you), rebuild with it
# added, or fall back to DJAVA_IMAGE=eclipse-temurin:25-jre-alpine.
FROM eclipse-temurin:25-jdk-alpine AS builder

RUN jlink \
      --add-modules java.base,java.logging,java.naming,java.management,java.net.http,java.sql,java.sql.rowset,java.xml,java.instrument,java.scripting,java.security.jgss,java.security.sasl,jdk.security.auth,java.transaction.xa,java.rmi,jdk.crypto.ec,jdk.unsupported,jdk.charsets,jdk.zipfs,jdk.httpserver \
      --strip-debug \
      --no-header-files \
      --no-man-pages \
      --compress=zip-6 \
      --output /javaruntime

FROM alpine:3.20

COPY --from=builder /javaruntime /opt/java
ENV JAVA_HOME=/opt/java
ENV PATH="$JAVA_HOME/bin:$PATH"
