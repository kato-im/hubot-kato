HTTP            = require('http')
HTTPS           = require('https')
EventEmitter    = require('events').EventEmitter
WebSocketClient = require('websocket').client
# for inspectiong and loggingig
Util            = require("util")
Winston         = require('winston')
# for scripts loading
Fs              = require('fs')
Path            = require('path')

# logger options
winston = new Winston.Logger
  transports: [
    new Winston.transports.File {
      filename: process.env.HUBOT_KATO_LOG_FILE || 'kato-hubot.log',
      timestamp: true,
      json: false,
      level: process.env.HUBOT_KATO_LOG_LEVEL || 'error'
    }
    new Winston.transports.Console {
      level: process.env.HUBOT_KATO_LOG_LEVEL || 'error'
    }
  ]


# simple Winston logger wrapper
logger =
  error   : (msg) -> winston.log("error", msg)
  debug   : (msg) -> winston.log("debug", msg)
  info    : (msg) -> winston.log("info",  msg)
  inspect : (msg, obj) -> winston.log("debug", msg + "#{Util.inspect(obj)}")

{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, Response} = require 'hubot'

try
  {TextMessage} = require '../../../src/message' # because of bugs with new version of nodejs

# Hubot Adapter
class Kato extends Adapter
  constructor: (robot) ->
    super robot
    # scripts files loader
    path = Path.resolve __dirname, '../scripts'
    Fs.exists path, (exists) ->
      logger.inspect("path ", path)
      logger.inspect("exist ", exists)
      if exists
        for file in Fs.readdirSync(path)
          robot.loadFile path, file
          robot.parseHelp Path.join(path, file)
      else logger.info("Script folder #{path} doesn't exist!")

  send: (envelope, strings...) ->
    @client.send(envelope.room, str) for str in strings

  reply: (envelope, strings...) ->
    strings = strings.map (s) -> "@#{envelope.user.name} #{s}"
    @send envelope.user, strings...

  run: ->
    self = @

    options =
      api_url : process.env.HUBOT_KATO_API || "https://api.kato.im"
      login   : process.env.HUBOT_KATO_LOGIN
      password: process.env.HUBOT_KATO_PASSWORD
    logger.debug "Kato adapter options: #{Util.inspect options}"

    unless options.login? and options.password?
      logger.error \
        "Not enough parameters provided. I need a login, password"
      process.exit(1)

    client = new KatoClient(options, @robot)

    client.on "TextMessage", (user, message) ->
      self.receive new TextMessage user, message

    client.on 'reconnect', () ->
      setTimeout ->
        client.Login()
      , 5000

    client.Login()
    @client = client
    self.emit "connected"

exports.use = (robot) ->
  new Kato robot

###################################################################
# The client.
###################################################################
class KatoClient extends EventEmitter
  self = @
  constructor: (options, @robot) ->
    self = @
    [schema, host] = options.api_url.split("://")
    self.secure    = schema == "https"
    self.api_host  = host
    self.login     = options.login
    self.password  = options.password
    self.rooms     = options.rooms
    self.orgs      = []

    @.on 'login', (err) ->
      @WebSocket()

  # Get organizations membership which is available for account.
  # Set returned orgs collection to self.orgs
  # (will be used for ws messages subscription)
  GetAccount: () ->
    @get "/accounts/"+self.account_id, null, (err, data) ->
      {response, body} = data
      switch response.statusCode
        when 200,201
          json = JSON.parse body
          self.orgs = []
          for m in json.memberships
            self.orgs.push({org_id:     m.org_id,\
                            org_name:   m.org_name,\
                            restricted: m.restricted,\
                            role:       m.role})
          logger.inspect "account memberships: #{Util.inspect json}"
          self.emit 'login'
        when 403
          logger.error "Invalid account id"
        else
          self.emit 'reconnect'

  Login: () ->
    id = @uuid()
    data = JSON.stringify
      email: self.login
      password: self.password

    @put "/sessions/"+id, data, (err, data) ->
      {response, body} = data
      switch response.statusCode
        when 200,201
          self.sessionKey = response.headers['set-cookie'][0].split(';')[0]
          self.sessionId = id
          json = JSON.parse body
          self.account_id = json.account_id
          self.session_id = json.id
          self.GetAccount() # getting additional account infformation for ws subscription
        when 403
          logger.error "Invalid login/password combination"
          process.exit(2)
        else
          logger.error "Can't login. Status: #{response.statusCode}, Id: #{id}, Headers: #{Util.inspect(response.headers)}"
          logger.error "Kato error: #{response.statusCode}"
          self.emit 'reconnect'

  WebSocket: () ->
    client = new WebSocketClient()

    client.on 'connectFailed', (error) ->
      logger.error('_Connect Error: ' + error.toString())

    client.on 'connect', (connection) ->
      self.connection = connection
      connection.on 'close', () ->
        logger.info 'echo-protocol Connection Closed'
        self.emit 'reconnect'
      connection.on 'error', (error) ->
        logger.info "error #{error}"
      connection.on 'message', (message) ->
        logger.debug "incomming message: #{Util.inspect message}"
        if (message.type == 'utf8')
          data = JSON.parse message.utf8Data
          if data.type == "text" # message for hubot
            user =
              id: data.from.id
              name: data.from.name
              room: data.room_id
            if self.login != data.from.email # ignore own messages
              user = self.robot.brain.userForId(user.id, user)
              self.emit "TextMessage", user, data.params.text
          else if data.type == "read" || data.type == "typing" || data.type == "silence"
            # ignore
          else if data.type == "check" # server check of status
            json = JSON.stringify(
              org_id: data.org_id,
              type: "presence",
              params: {
                status: "online",
                ts: Date.now(),
                tz_offset: new Date().getTimezoneOffset()/60,
                device_type: "hubot"  # TODO: not sure about it
              })
            connection.sendUTF json # notifying server for hubot user presence
            logger.debug "send presence: #{json}"
          else
            logger.debug "unused message received: #{Util.inspect(data)}"

      # Send message for subscribing to all avalable rooms
      Subscribe = () ->
        for o in self.orgs
          params = {}
          params.organization = {}
          params.accounts = {}
          params.forums = {}
          if (o.role == "owner")
            params.groups = {}
          json = JSON.stringify(
            type: "sync"
            org_id: o.org_id
            group_id: o.org_id
            params: params
          )
          connection.sendUTF json

      # Subscribe to organizations messages (aka hello)
      json = JSON.stringify(
        type: "sync"
        params: { account: {} })
      logger.debug "send ws hello: #{json}"
      connection.sendUTF json, Subscribe()

    headers =
      'Cookie': self.sessionKey
    client.connect((if self.secure then 'wss' else 'ws') + '://'+self.api_host+'/ws/v1', null, null, headers)

  uuid: (size) ->
    part = (d) ->
      if d then part(d - 1) + Math.ceil((0xffffffff * Math.random())).toString(16) else ''
    part(size || 8)

  send: (room_id, str) ->
    json = JSON.stringify
      room_id: room_id
      type: "text"
      params:
        text: str
        data:
          renderer: "markdown"
    logger.debug "sended: #{JSON.stringify json}"
    @connection.sendUTF json

  put: (path, body, callback) ->
    @request "PUT", path, body, callback

  get: (path, body, callback) ->
    @request "GET", path, body, callback

  request: (method, path, body, callback) ->
    if self.secure
      module = HTTPS
      port = 443
    else
      module = HTTP
      port = 80
    headers =
      "Authorization" : @authorization
      "Host"          : self.api_host
      "Content-Type"  : "application/json"
      "Cookie"        : self.sessionKey # it's need for HTTP api requests

    options =
      "agent"  : false
      "host"   : self.api_host
      "port"   : port
      "path"   : path
      "method" : method
      "headers": {}

    if method is "POST" || method is "PUT"
      if typeof(body) isnt "string"
        body = JSON.stringify body

      body = new Buffer(body)
      headers["Content-Length"] = body.length

    for key, val of headers when val
      options.headers[key] = val

    request = module.request options, (response) ->
      data = ""

      response.on "data", (chunk) ->
        data += chunk

      response.on "end", ->
        callback null, {response: response, body: data}

      response.on "error", (err) ->
        logger.error "Kato response error: #{err}"
        callback err, { }

    if method is "POST" || method is "PUT"
      request.end(body, 'binary')
    else
      request.end()

    request.on "error", (err) ->
      logger.error "Kato request error: #{err}"
