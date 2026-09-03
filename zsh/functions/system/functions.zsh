# Kill a hung JetBrains Gateway / remote-dev backend on this machine
# (leaves other JetBrains processes alone -- for those, see nukejetbrains).
killgateway() {
  if pkill -f "ide-backend|remote-dev-server"; then
    echo "Killed all remote IntelliJ backend instances."
  else
    echo "No remote IntelliJ instances are currently running."
  fi
}
