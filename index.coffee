express = require "express"
faye = require "faye"
path = require "path"

# Replace with your drones IP addresses
drone_ip = "192.168.1.1"

network = [drone_ip]

swarm = require "./swarm"

# Initialize Drones

network.forEach (ip) ->
  swarm.add ip: ip

# Configure Drones

#-> activate navdata
swarm.do (drone) ->
  console.log('config drone:', drone.id)
  drone.config('general:navdata_demo', 'TRUE');
  drone.on 'navdata', (data) ->
    drone.navdata = data
    socket.publish "/drone/navdata/"+drone.id, data

# #-> activate video stream
# swarm.do (drone) ->
#   drone.pngStream = drone.createPngStream(frameRate: 10)
#   drone.pngStream.on "error", (error) ->
#     console.log('drone.pngStream *error*', error)
#   drone.pngStream.on "data", (frame) ->
#     drone.pngBuffer = frame

# Initialize Express server

app = express()
app.configure ->
  app.set('port', process.env.PORT || 3000)
  app.use(app.router)
  app.use(express.static(path.join(__dirname, 'public')))
  app.use("/bower_components", express.static(path.join(__dirname, 'bower_components')))
server = require("http").createServer(app)

# Initialize Sockets

bayeux = new faye.NodeAdapter(mount: '/faye', timeout: 45)
bayeux.attach(server)
bayeux.bind "handshake", (clientId) ->
  console.log "socket handshake!", clientId
bayeux.bind "disconnect", (clientId) ->
  console.log "socket disconnect!", clientId
socket = new faye.Client("http://localhost:#{app.get("port")}/faye")

# Configure routes

app.get "/drones", (req, res) ->
  drones = []
  swarm.forEach (drone) ->
    drones.push
      id: drone.id
      ip: drone.ip
      camera: drone.camera
      enabled: drone.enabled
  console.log "new client connection (sent %s drones)", drones.length
  res.end JSON.stringify(drones)

socket.subscribe "/drone/enable", (data) ->
  swarm.drones[data.id].enabled = data.status
  console.log 'set drone %s control to %s', data.id, data.status

socket.subscribe "/drone/camera", (data) ->
  swarm.drones[data.id].changeCamera data.camera
  console.log 'set drone %s camera to %s', data.id, data.camera

socket.subscribe "/swarm/move", (control) ->
  console.log 'swarm move', control
  swarm.move(control)

socket.subscribe "/swarm/animate", (animation) ->
  console.log 'swarm animate: ', animation
  swarm.animate(animation)

socket.subscribe "/swarm/action", (command) ->
  console.log 'swarm action: ', command
  swarm.action(command)

server.listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")

app.get "/drone/camera/:id/:random", (req, res) ->
  res.header "Cache-Control", "no-cache, no-store" # avoid high disk usage on client browser
  res.header "Content-Type", "image/png" # avoid client browser warning on missing mime
  res.end swarm.drones[req.params.id].pngBuffer, "binary"

# Additional tasks
# setInterval (->
#   swarm.do (drone) ->
#     console.log drone.ip, drone.navdata.demo.clockwiseDegrees if drone.navdata #and drone.navdata.droneState.flying
#     # console.log '=======>', drone.ip
#     # console.log drone.navdata.demo
# ), 1000

# __videoMode=0
# setInterval (->
#   console.log('video:video_channel', ''+__videoMode)
#   swarm.do (drone) ->
#     drone.config('video:video_channel', ''+__videoMode);
#   __videoMode++
#   __videoMode=0 if __videoMode > 1
# ), 1000

require("dronestream").listen(server, ip: drone_ip, path: '/dronestream101', timeout: 500)