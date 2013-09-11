httpProxy = require 'http-proxy'
net = require 'net'
url = require 'url'
http = require 'http'

timed_out_until = 0

truncate = (str) ->
  maxLen = 64
  if str.length > maxLen
    return str.substr(0, maxLen) + '...'
  else
    return str

logRequest = (req) ->
  console.log "#{Date()}\t #{req.method} #{truncate(req.url)}"
  for header in req.headers
    console.log "* #{header}: #{truncate(req.headers[header])}"

logError = (err) ->
  console.warn "*** #{Date()}\t #{err}"

process.on 'uncaughtException', logError
regularProxy = new httpProxy.RoutingProxy()

sendError = (req, res) ->
  res.statusCode = 500
  res.setHeader('proxy-alive', 'false')
  res.setHeader('Content-Type', 'text/plain')
  res.write("Error\n")
  res.end()

server = http.createServer (req, res) ->
  logRequest(req)
  uri = url.parse(req.url)
  if timed_out_until > Date.now()
    sendError(req, res)
    return

  if uri.path.match 'is_alive'
    res.setHeader('proxy-alive', 'true')
    res.setHeader('Content-Type', 'text/plain')
    res.write("OK\n")
    res.end()
    return

  # overload the res.write() to sniff on response
  res.oldWrite = res.write
  res.write = (data) ->
    if data.toString().match /This IP has been automatically blocked/ || Math.random() > 0.5
      logError 'ERROR! data: \t' + data.toString()
      timed_out_until = Date.now() + 1000 * 60 * 5 # timeout for 5 minutes
      sendError(req, res)
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

server.listen 3000

console.log "Starting proxy on port 3000"
