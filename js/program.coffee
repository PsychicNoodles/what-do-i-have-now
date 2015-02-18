R = React.DOM # quality of life aliasing

roux = "https://schedules.dalton.org/roux/index.php" # all requests use this URL

parseCourse = (xml, times) ->
  full: /<!\[CDATA\[(.*)]]>/.exec(xml.find('section name:first').html())[1]
  short: xml.find('section shortname:first').html()
  teacher: xml.find('instructor name:first').html()
  room: xml.find('location').html()
  time: times[0..1]
  id: xml.find("section:first").attr "id"

parseTime = (xml) ->
  xml.find("start").html().split(" ")[1].split(":")

findNow = (periods) ->
  now = moment()
  for p, i in periods
    $p = $ p # jquery-ify
    times = parseTime $p
    start = moment().hour(parseInt(times[0])).minutes(parseInt(times[1])).seconds(parseInt(times[2]))
    if now.isAfter(start.clone().subtract(5, "minutes")) # subtracts 5 minutes so you don't get "Lab" in the 5 minutes between periods
      if now.isBefore(start.clone().add(parseInt($p.find("duration").html()), "minutes"))
        return {} =
          now:
            parseCourse $p, times
          later:
            parseCourse $(c), parseTime $(c) for c in periods[(i + 1)..-1]
    else
      return {} =
        now:
          null
        later:
          parseCourse $(c), parseTime $(c) for c in periods[i..-1]
  now:
    null
  later:
    parseCourse $(c), parseTime $(c) for c in periods

Navbar = React.createFactory React.createClass # the navbar portion
  getInitialState: ->
    username: null
    password: null
  signIn: (evt) ->
    evt.preventDefault()
    @props.signInFn @state.username, @state.password
  signOut: (evt) ->
    evt.preventDefault()
    @props.signOutFn()
  render: -> # ~~bootstrap~~
    R.div className: "navbar navbar-default navbar-fixed-top",
      R.div className: "container",
        R.div className: "navbar-header",
          R.button type: "button", className: "navbar-toggle collapsed", "data-toggle": "collapse", "data-target": "#navbar", "aria-expanded": "false", "aria-controls": "navbar",
            R.span className: "sr-only", "Toggle navigation"
            R.span className: "icon-bar", null
            R.span className: "icon-bar", null
            R.span className: "icon-bar", null
          R.a className: "navbar-brand", href: "index.html",
            "What do I have now?"
        R.div id: "navbar", className: "navbar-collapse collapse",
          if @props.loggedIn
            R.form className: "navbar-form navbar-right", onSubmit: @signOut,
              R.button type: "submit", className: "btn btn-primary", "Sign out"
          else
            R.form className: "navbar-form navbar-right", onSubmit: @signIn,
              R.div className: "form-group#{if @props.loginError != 0 then ' has-error' else ''}",
                R.label className: "control-label", id: "login-feedback", if @props.loginError == 1 then "Invalid login" else if @props.loginError == 2 then "Server error, please try again later" else ""
                R.input type: "text", placeholder: "Username", className: "form-control", onChange: (evt) => @setState { username: evt.target.value } # updates state whenever value is changed
                R.input type: "password", placeholder: "Password", className: "form-control", onChange: (evt) => @setState { password: evt.target.value }
              R.button type: "submit", className: "btn btn-primary", "Sign in"

DevEmail = React.createFactory React.createClass # an email link builder
  render: ->
    R.a href: "mailto:mattori.birnbaum@gmail.com?subject=An error occurred with \"What do I have now?\"&\
               body=Error: #{@props.error}\nStatus: #{@props.status}\nKey: #{@props.credKey}\nID: #{@props.credId}\nExtra: #{@props.extra}", "the developer"

Body = React.createFactory React.createClass
  getInitialState: ->
    auto: false
    frequency: 10
    interval: null
  toggleAuto: (evt) ->
    @setState
      auto: evt.target.checked
    if evt.target.checked
      @setState
        interval: setInterval(@props.updateFn, @state.frequency * 1000 * 60)
    else
      clearInterval @state.interval
  componentWillUnmount: ->
    clearInterval @state.interval
  render: ->
    R.div className: "container",
      R.div className: "jumbotron",
        R.h2 null, if @props.courseError or not @props.loggedIn then "Uh oh!" else "You have:"
        R.h1 null,
          if @props.courseError
            "An error occurred"
          else if not @props.loggedIn 
            "Please sign in,"
          else if not @props.course
            "Loading..."
          else
            @props.course.full
        R.h3 null,
          if @props.courseError
            "due to #{@props.courseError.msg}" + (if @props.courseError.status then " (status: #{@props.courseError.status})" else "")
          else if not @props.loggedIn
            "your classes can't be retrieved otherwise."
          else if not @props.course
            "..."
          else if @props.course.short
            "(#{@props.course.short})"
          else undefined
        R.p className: "lead",
          if @props.courseError
            R.span null,
              "Please send an email to ",
              DevEmail error: @props.courseError.err, status: @props.courseError.status, credKey: localStorage.getItem("key"), credId: localStorage.getItem("id"), extra: @props.courseError.extra
          else if not @props.loggedIn
            "Your login info will be saved once signed in."
          else if not @props.course
            "..."
          else if @props.course.teacher and @props.course.room
            "with #{@props.course.teacher} in #{@props.course.room}"
          else undefined
        R.div className: "row",
          R.div className: "col-md-1 col-md-offset-4",
            R.button className: "btn btn-default", style: (if not @props.course then { "display": "none" } else undefined), onClick: @props.updateFn, "Refresh"
          R.div className: "col-md-3",
            R.div className: "input-group",
              R.span className: "input-group-addon",
                R.input type: "checkbox", onClick: @toggleAuto
              R.span className: "input-group-addon", "Every"
              R.input className: "form-control", type: "text", value: @state.frequency, onChange: (evt) => if !isNaN evt.target.value then @setState { frequency: evt.target.value }
              R.span className: "input-group-addon", "minutes"
      if @props.courseLater
        R.div className: "col-md-6 col-md-offset-3",
          R.h4 className: "text-center", "And later..."
          R.ul className: "list-group",
            for course, i in @props.courseLater
              R.li className: "list-group-item", key: i,
                R.span className: "badge", moment().hour(course.time[0]).minutes(course.time[1]).format("h:mm A")
                R.h4 className: "list-group-item-heading", course.full
                R.p className: "list-group-item-text", "with #{course.teacher} in #{course.room}"

Base = React.createClass
  getInitialState: ->
    loggedIn: (localStorage.getItem("key") and localStorage.getItem("id"))
    loginError: 0
    courseError: null
    course: null # {isLab: bool, full: String, short: String, teacher: String, room: String}
    courseLater: null
  componentWillMount: ->
    if @state.loggedIn
      @update()
  signIn: (username, password) ->
    $.ajax
      url: roux
      type: "POST"
      data: { rouxRequest: "<request><key></key><action>authenticate</action><credentials><username>#{username}</username><password type=\"plaintext\">#{password}</password></credentials></request>" }
      timeout: 1000
      success: (res) =>
        $res = $ res
        if $res.find("error").length isnt 0
          @setState
            loginError: 1
        else
          localStorage.setItem "key", $res.find("key:first").html()
          localStorage.setItem "id", $res.find("key:first").attr "owner"
          @setState
            loggedIn: true
            loginError: 0
          $("#navbar").removeClass "in"
          @update()
      error: (xhr, err, status) =>
        @setState
          loginError: 2
  signOut: ->
    localStorage.removeItem "key"
    localStorage.removeItem "id"
    @setState
      loggedIn: false
      course: null
      courseError: null
      courseLater: null
  update: ->
    @setState
      course: null
      courseError: null
      courseLater: null
    $.ajax
      url: roux
      type: "POST"
      data: { rouxRequest: "<request><key>#{localStorage.getItem 'key'}</key><action>selectStudentCalendar</action><ID>#{localStorage.getItem 'id'}</ID><academicyear>#{moment().year()}</academicyear></request>" }
      timeout: 1000
      success: (res) =>
        try
          err = $(res).find "error"
          if err.length != 0
            @signOut()
          else
            periods = $(res).find "period"
            if periods.length != 0
              {now, later} = findNow periods
              if now is null
                if moment().isAfter(moment().hour(12).minutes(35)) and moment().isBefore(moment().hour(13).minutes(14)) # interval
                  @setState
                    course:
                      full: "Interval"
                      short: "get some food"
                else if moment().isAfter(moment().hour(15).minutes(15)) # afterschool
                  @setState
                    course:
                      full: "nothing!"
                      short: "school's over"
                else
                  @setState
                    course:
                      full: "Lab!"
              else
                @setState
                  course: now
              if later.length > 0
                @setState
                  courseLater: later
              else
                @setState
                  courseLater: null
            else
              @setState
                course:
                  full: "nothing!"
                  short: "no classes today"
        catch err
         @setState
           courseError:
             msg: "either an internal Dalton server problem or parsing error"
             err: "Could not find period in \"selectStudentCalendar\" call"
             extra: err
         console.err err
  render: ->
    R.div null,
      Navbar loggedIn: @state.loggedIn, signInFn: @signIn, signOutFn: @signOut, loginError: @state.loginError
      Body loggedIn: @state.loggedIn, course: @state.course, courseError: @state.courseError, courseLater: @state.courseLater, updateFn: @update
      #R.div null, # debugging
      # for k, v of @state
      #   R.div null, "#{k} = " + (if v is not null and v.keys then ("#{k1} = #{v2}" for k1, v1 of v) else v)
      

$ ->
  React.render(
    React.createElement Base, null
    $("#bind")[0]
  )
  if window.location.protocol != "https:"
    window.location.href = "https:" + window.location.href.substring(window.location.protocol.length)