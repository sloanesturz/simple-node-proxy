// Generated by CoffeeScript 1.6.3
(function() {
  var http, httpProxy, options, proxy, url;

  httpProxy = require('http-proxy');

  options = require('./config');

  url = require('url');

  http = require('http');

  proxy = httpProxy.createServer(function(req, res, proxy) {
    var target;
    target = {
      host: 'craigslist.org',
      port: 80
    };
    return proxy.proxyRequest(req, res, target);
  });

  proxy.listen(8000);

}).call(this);
