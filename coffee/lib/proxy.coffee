httpProxy = require 'http-proxy'
options = require './config'
url = require 'url'
http = require('http')



proxy = httpProxy.createServer (req, res, proxy) ->
  target = 
   host: 'craigslist.org'
   port: 80

  # target = {host: 'www.craigslist.com', path: '/about/sites', port: 80};
  proxy.proxyRequest(req, res, target);

proxy.listen(8000)