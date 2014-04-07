window.socket = new Faye.Client "/faye", timeout: 1, retry: 1
socket.bind "transport:down", ->
  swarm.forEach (drone) -> drone.terminate()
  $('body').append(
    $('<div id="lost-connection">').css(
      position: "fixed", top: 0, left: 0, width: '100%', height: '100%', opacity: 0.8, background: 'black'
    ).append(
      $('<div>').html(
        'Lost connection with server<br><br><span id="reconnecting">- Reconnecting -</span>'
      ).css(
        color: "white", textAlign: "center", fontSize: "16px", marginTop: "10px"
      )
    )
  )
  setInterval ->
    $('#lost-connection #reconnecting').fadeOut().fadeIn()
  , 1000
  socket.bind "transport:up", ->
    document.location.reload()

# initialize drones

window.swarm = []
$.extend(swarm,
  drones: {}
  forEach: (iterator) ->
    Object.keys(swarm.drones).forEach (id) ->
      iterator(swarm.drones[id])
  _speed: 1
  speed: (options) ->
    return swarm._speed unless options
    swarm._speed = options.speed
  # socket stuff
  action: (options, stop) ->
    return if stop
    console.log "/swarm/action", options
    socket.publish "/swarm/action", options
  move: (options, stop) ->
    #console.log "/drone/move", axis: options.axis, speed: options.vector * swarm.speed() * (if stop then 0 else 1)
    move = {}
    move[options.axis] = options.vector * swarm.speed() * (if stop then 0 else 1)
    socket.publish "/swarm/move", move
  animate: (options, stop) ->
    return if stop
    console.log "/swarm/animate", options
    socket.publish "/swarm/animate", options
)

$.ajax
  url: '/drones',
  dataType: 'json'
  success: (drones) ->
    drones.forEach (drone) ->
      swarm.drones[drone.id] = new Drone(drone)
      swarm.push swarm.drones[drone.id]

# configure oculus rift support
window.useOculusControl = false
window.referenceOculusAngle = null
window.lastOculusAngle = null
queryOculusAngles = ->
  $.get 'http://localhost:50000', (response, error) ->
    window.lastOculusAngle = response
$ ->
  setInterval queryOculusAngles, 10
  setInterval renderOculusControl, 10
  window.$oculusOSD=$('.oculus-osd')
  $('body').prepend window.$oculusDiv=$('<div>')
  window.$oculusDiv.css(
    position: 'fixed'
    top: 0
    left: 0
    width: '100%'
    height: '30px'
    backgroundColor: 'black'
    color: 'white'
    textAlign: 'center'
    fontSize: '13px'
    lineHeight: '30px'
    zIndex: '1'
  )
  window.$oculusDiv.html('Start Oculus deamon & press O to set reference and start control')

setOculusAngle = (options, stop)->
  return if stop
  if window.useOculusControl = !window.useOculusControl
    $('#oculus-stream').show()
    $('#oculus-left,#oculus-right').fadeIn 500;
    window.$oculusDiv.animate color: 'black', backgroundColor: 'white'#, height: '60px'
    window.$oculusDiv.html('OCULUS RIFT ENABLED<br>')
    window.referenceOculusAngle = window.lastOculusAngle
  else
    $('#oculus-left,#oculus-right').fadeOut 500, ->
      $('#oculus-stream').hide()

    window.$oculusDiv.animate color: 'white', backgroundColor: 'black'#, height: '30px'
    window.$oculusDiv.html('Start Oculus deamon & press O to set reference and start control')
    window.referenceOculusAngle = null
    swarm.move axis: 'x', vector: 0
    swarm.move axis: 'y', vector: 0
    swarm.move axis: 'r', vector: 0
    swarm.action action: 'stop'
    

window.diffOculusAngle = ->
  if window.useOculusControl && window.referenceOculusAngle
    euler:
      y: +diffAngles(window.referenceOculusAngle.euler.y, window.lastOculusAngle.euler.y),
      p: +diffAngles(window.referenceOculusAngle.euler.p, window.lastOculusAngle.euler.p),
      r: -diffAngles(window.referenceOculusAngle.euler.r, window.lastOculusAngle.euler.r),

window.renderOculusControl = ->
  return if !window.useOculusControl || !diffAngle=window.diffOculusAngle()
  
  diffThreshold = y: 0.3, p: 0.05, r: 0.05
  diffScale = y: 0.5, p: 0.3, r: 0.3
  oculusControl = x: 0, y: 0, r: 0
  
  window.$oculusOSD.html('')
  
  if Math.abs(diffAngle.euler.y) > diffThreshold.y
    window.$oculusOSD.append if diffAngle.euler.y > 0 then "CW " else "CWW "
    oculusControl.r = diffAngle.euler.y * diffScale.r if window.useOculusControl
  
  if Math.abs(diffAngle.euler.p) > diffThreshold.p
    window.$oculusOSD.append if diffAngle.euler.p > 0 then "FORWARD " else "BACKWARD "
    oculusControl.y = diffAngle.euler.p * diffScale.p if window.useOculusControl
  
  if Math.abs(diffAngle.euler.r) > diffThreshold.r
    window.$oculusOSD.append if diffAngle.euler.r > 0 then "LEFT " else "RIGHT "
    oculusControl.x = diffAngle.euler.r * diffScale.r if window.useOculusControl
  
  swarm.move axis: 'x', vector: -oculusControl.x
  swarm.move axis: 'y', vector: +oculusControl.y
  swarm.move axis: 'r', vector: +oculusControl.r

  $oculusControlPad = $('.oculus-control-pad')
  $oculusControl = $('.oculus-control')
  $oculusControlPad.css(
    marginTop: ((3 * -oculusControl.y + 0.5) * $oculusControl.width()) - ($oculusControlPad.width() / 2)
    marginLeft: ((3 * -oculusControl.x + 0.5) * $oculusControl.height()) - ($oculusControlPad.height() / 2)
    background: 'green'
  )
  $oculusControl.css
    "-webkit-transform": "rotate(" + (360 * (0.3 * oculusControl.r)) + "deg)"

  if !oculusControl.x && !oculusControl.y && !oculusControl.r
    window.$oculusOSD.html('HOLD') 
    $oculusControlPad.css background: 'black'

diffAngles = (a, b) ->
  a += 3*Math.PI
  b += 3*Math.PI
  a-b

# configure ui

keys =
  38 : { event: swarm.move, options: { axis: 'y', vector: +1 } } # W
  40 : { event: swarm.move, options: { axis: 'y', vector: -1 } } # S
  37 : { event: swarm.move, options: { axis: 'x', vector: -1 } } # A
  39 : { event: swarm.move, options: { axis: 'x', vector: +1 } } # D
  87 : { event: swarm.move, options: { axis: 'z', vector: +1 } } # up
  83 : { event: swarm.move, options: { axis: 'z', vector: -1 } } # down
  65 : { event: swarm.move, options: { axis: 'r', vector: -1 } } # left
  68 : { event: swarm.move, options: { axis: 'r', vector: +1 } } # right
  32 : { event: swarm.action, options: { action: 'stop' } } # space
  13 : { event: swarm.action, options: { action: 'takeoff' } } # enter
  27 : { event: swarm.action, options: { action: 'land' } } # esc
  69 : { event: swarm.action, options: { action: 'disableEmergency' } } # E
  49 : { event: swarm.animate, options: { name: 'wave', duration: 3000 } } # 1
  50 : { event: swarm.animate, options: { name: 'flipAhead', duration: 3000 } } # 2
  
  79 : { event: setOculusAngle }
  
  # ... use animations with caution

$(document).keydown (e) ->
  return unless keyOptions = keys[e.keyCode]
  e.preventDefault()
  return if keyOptions.sending
  keyOptions.sending = true
  keyOptions.event(keyOptions.options, false)

$(document).keyup (e) ->
  return unless keyOptions = keys[e.keyCode]
  e.preventDefault()
  keyOptions.sending = false
  keyOptions.event(keyOptions.options, true)


# VR video
$ ->
  _RATIO = 0.5
  dronestream = new NodecopterStream(document.getElementById("oculus-stream"))
  $videoBuffer = $('#oculus-stream canvas')
  videoBuffer = $videoBuffer[0]
  # videoCtx = video.getContext '2d' # not working as it's experimental-webgl
  $video1 = $videoBuffer.clone().appendTo('#oculus-left').attr('id', 'oculus-stream-left')
  $video2 = $videoBuffer.clone().appendTo('#oculus-right').attr('id', 'oculus-stream-right')
  video1 = $video1[0]
  video1Ctx = video1.getContext '2d'
  video2 = $video2[0]
  video2Ctx = video2.getContext '2d'
  
  processFrame = ->
    requestAnimationFrame(processFrame)
    
    # copy video to buffer for read/write on 2d context
    video1.width = video1.width
    video1Ctx.drawImage(videoBuffer, 0, 0, videoBuffer.width, videoBuffer.height)
    video2.width = video2.width
    video2Ctx.drawImage(videoBuffer, 0, 0, videoBuffer.width, videoBuffer.height)
    
  processFrame()