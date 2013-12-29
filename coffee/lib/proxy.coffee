httpProxy = require 'http-proxy'
net = require 'net'
url = require 'url'
http = require 'http'
{puts, inspect} = require 'util'

USERNAME = process.env.PROXY_USERNAME || ''
PASSWORD = process.env.PROXY_PASSWORD || 'password'
PORT = if process.env.PORT? then parseInt(process.env.PORT) else 3000

timed_out_until = 0

truncate = (str) ->
  maxLen = 64
  if str.length > maxLen
    return str.substr(0, maxLen) + '...'
  else
    return str

logRequest = (req) ->
  console.log "#{Date()}\t #{req.method} #{truncate(req.url)}"

logError = (err) ->
  console.warn "*** #{Date()}\t #{err}"

process.on 'uncaughtException', logError
regularProxy = new httpProxy.RoutingProxy()

send500 = (req, res) ->
  res.statusCode = 500
  res.setHeader('proxy-alive', 'false')
  res.setHeader('Content-Type', 'text/plain')
  res.write("Error\n")
  res.end()

send401 = (req, res) ->
  res.statusCode = 401
  res.setHeader('Content-Type', 'text/plain')
  res.write("Unauthorized\n")
  res.end()

getAuth = (authHeader) ->
  try
    token = authHeader.split(/\s+/).pop()
    auth = new Buffer(token, 'base64').toString()
    parts = auth.split(/:/)
    username: parts[0], password: parts[1]
  catch error # bad auth, return null
    username: null, password: null

server = http.createServer (req, res) ->
  logRequest(req)
  uri = url.parse(req.url)
  if timed_out_until > Date.now()
    send500(req, res)
    return

  if uri.path.match 'is_alive'
    console.log "* Last timeout was #{timed_out_until}"
    res.setHeader('proxy-alive', 'true')
    res.setHeader('Content-Type', 'text/plain')
    res.write("OK\n")
    res.end()
    return

  # authenticate
  auth = getAuth(req.headers['proxy-authorization'] || '')
  if !(auth.username == USERNAME && auth.password == PASSWORD)
    console.log("Unauthorized request to #{uri.hostname}")
    send401(req, res)
    return

  # overload the res.write() to sniff on response
  res.oldWrite = res.write
  res.write = (data) ->
    if data.toString().match /This IP has been automatically blocked/
      logError 'ERROR! data: \t' + data.toString()
      timed_out_until = Date.now() + 1000 * 60 * 5 # timeout for 5 minutes
      send500(req, res)
      return
    else
      res.oldWrite(data) # basically like calling super

  regularProxy.proxyRequest req, res, 
    host: uri.hostname
    port: uri.port || 80

server.on 'upgrade', (req, socket, head) ->
  logRequest req
  parts = req.url.split ':', 2
  conn = net.connect parts[1], parts[2], ->
    socket.write "HTTP/1.1 200 OK\r\n\r\n"
    socket.pipe conn
    conn.pipe socket

server.listen PORT

console.log "Starting proxy on port #{PORT}"
