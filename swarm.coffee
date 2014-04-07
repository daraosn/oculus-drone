_ = require "underscore"
ardrone = require "ar-drone"

swarm = []
swarm.drones = {}
swarm.forEach = (iterator) ->
  Object.keys(swarm.drones).forEach (id) ->
    iterator(swarm.drones[id])

swarm.do = (block) ->
  swarm.forEach (drone) ->
    block?(drone)
swarm.action = (command) ->
  swarm.forEach (drone) ->
    if drone.enabled
      drone.snooze drone.inactivityTime
      console.log("drone[#{command.action}]()")
      drone[command.action]?()
swarm.move = (control) ->
  swarm.forEach (drone) ->
    if drone.enabled
      drone.snooze drone.inactivityTime
      drone.move control
swarm.animate = (animation) ->
  swarm.forEach (drone) ->
    if drone.enabled
      drone.snooze animation.duration # TODO: research wheter the drone times-out or not with longer snooze times
      drone.animate(animation.name, animation.duration)
swarm.add = (config) ->
  drone = ardrone.createClient(ip: config.ip)
  drone.id = config.id || config.ip.split(".").pop()
  drone.ip = config.ip
  drone.enabled = false
  drone.camera = 0
  drone.changeCamera = (camera) ->
    camera = !drone.camera + 0 if camera == "toggle"
    camera = 0 unless typeof camera == "number"
    drone.config('video:video_channel', ''+camera);
    drone.camera = camera
  drone.control =
    x: 0
    y: 0
    z: 0
    r: 0
  drone.isIddle = ->
    return drone.control.x == 0 && drone.control.y == 0 && drone.control.z == 0 && drone.control.r == 0
  drone.move = (control) ->
    if control
      _.extend drone.control, control
      console.log drone.control, control, drone.isIddle() if control
    else
      control = drone.control
    if drone.isIddle()
      drone.stop()
      # console.log("drone.stop", drone.ip)
    else
      if control.x < 0
        drone.left -control.x
        # console.log("drone.left", drone.ip, -control.x)
      else if control.x > 0
        drone.right control.x
        # console.log("drone.right", drone.ip, control.x)
      if control.y < 0
        drone.back -control.y
        # console.log("drone.back", drone.ip, -control.y)
      else if control.y > 0
        drone.front control.y
        # console.log("drone.front", drone.ip, control.y)
      if control.z < 0
        drone.down -control.z
        # console.log("drone.down", drone.ip, -control.z)
      else if control.z > 0
        drone.up control.z
        # console.log("drone.up", drone.ip, control.z)
      if control.r < 0
        drone.counterClockwise -control.r
        # console.log("drone.counterClockwise", drone.ip, -control.r)
      else if control.r > 0
        drone.clockwise control.r
        # console.log("drone.clockwise", drone.ip, control.r)
    return control
  ##############################
  ## AR Drone SDK 2.0.1, page 36
  ##############################
  ## ".. AR.Drone 2.0 is reached by sending the AT-commands every 30 ms for smooth drone movements.
  ## To prevent the drone from considering the WIFI connection as lost, two consecutive commands must
  ## be sent within less than 2 seconds."
  drone.inactivityTime = 200
  drone.inactivityTimeout = +new Date + drone.inactivityTime
  drone.snooze = (length) ->
    console.log "drone %s snooze (keep alive off)", drone.ip if drone.inactive
    drone.inactive = false
    drone.inactivityTimeout = +new Date + length
  drone.keepAlive = ->
    if +new Date() > drone.inactivityTimeout
      console.log "drone %s inactive (keep alive on)", drone.ip unless drone.inactive
      #console.log "drone %s => keepAlive", drone.ip
      drone.inactive = true
      drone.move() # this will take care of stoping or moving the drone
  setInterval drone.keepAlive, 30

  # add drone to swarm
  swarm.drones[drone.id] = drone
  swarm.push drone

module.exports = swarm