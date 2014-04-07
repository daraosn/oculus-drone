window.Drone = (config) ->
  _$div = (className) ->
    $('<div>').attr('class', className)

  d =
    id: config.id || config.ip.split(".").pop()
    ip: config.ip
    takeOff: ->
    land: ->
    stop: ->
    move: ->
    animate: ->
    navdata: ->
    updateNavdata: (navdata) ->
      d.navdata = navdata
      d.updateBattery(navdata.demo.batteryPercentage)
      ["clockwiseDegrees", "altitudeMeters", "frontBackDegrees",
      "leftRightDegrees", "xVelocity", "yVelocity", "zVelocity"].forEach (param) ->
        d._$wrapper.find(".navdata-" + param).html(Math.round(navdata.demo[param], 4))
    updateBattery: (percentage) ->
      d._$batteryBar.width(percentage+"%").text(percentage+"%")
      if(percentage < 30 and percentage >= 20)
        d._$batteryProgress.removeClass('progress-success').addClass('progress-warning').removeClass('progress-danger')
      else if(percentage < 20)
        d._$batteryProgress.removeClass('progress-success').removeClass('progress-warning').addClass('progress-danger')
      else
        d._$batteryProgress.addClass('progress-success').removeClass('progress-warning').removeClass('progress-danger')
    control: config.control || false
    toggle: ->
      d.enable !d.control
    enable: (status, quiet) ->
      d.control = status
      if status
        d._$wrapper.addClass('control')
        d._$ip.addClass('badge-success')
      else
        d._$wrapper.removeClass('control')
        d._$ip.removeClass('badge-success')
      socket.publish("/drone/enable", id: d.id, status: d.control) unless quiet
    terminate: ->
      clearInterval d._cameraTimer
    # private
    _$ip: _$div('ip badge')
    _$cameraImg: $('<img>')
    _$batteryProgress: _$div('battery progress')
    _$batteryBar: _$div('bar').css('width', '100%')
    _$wrapper: _$div 'drone'
    _template: ->
      $ip = d._$ip.appendTo(d._$wrapper).text(d.ip)
      $camera = _$div('camera').appendTo(d._$wrapper)
      $camera.append d._$cameraImg
      $navdata = _$div('navdata').appendTo(d._$wrapper)
      $battery = d._$batteryProgress.appendTo($navdata).append(d._$batteryBar)
      $navdata
        .append('<div>clockwiseDegrees: <span class="navdata-clockwiseDegrees"></span></div>')
        .append('<div>altitudeMeters: <span class="navdata-altitudeMeters"></span></div>')
        .append('<div>frontBackDegrees: <span class="navdata-frontBackDegrees"></span></div>')
        .append('<div>leftRightDegrees: <span class="navdata-leftRightDegrees"></span></div>')
        .append('<div>xVelocity: <span class="navdata-xVelocity"></span></div>')
        .append('<div>yVelocity: <span class="navdata-yVelocity"></span></div>')
        .append('<div>zVelocity: <span class="navdata-zVelocity"></span></div>')
      d._$wrapper

  $('#drones').append(d._template)

  d.enable config.enabled, true
  d._$cameraImg.click (e) ->
    e.stopPropagation()
    e.preventDefault()
    socket.publish("/drone/camera", id: d.id, camera: "toggle")
    false
  d._$wrapper.click ->
    d.toggle()
  d._$wrapper.dblclick (e) ->
    swarm.forEach (drone) ->
      drone.enable drone.id == d.id

  d._cameraTimer = setInterval ->
    d._$cameraImg.attr(src: "/drone/camera/#{d.id}/#{Math.random()}")
  , 100

  socket.subscribe "/drone/navdata/"+d.id, (navdata) ->
    d.updateNavdata navdata

  return d