path = require('path')
http = require('http')
express = require('express')
bodyParser = require('body-parser')
morgan = require('morgan')
fs = require('fs')
stdio = require('stdio')
spawn = require('child_process').spawn
crypto = require('crypto')
bunyan = require('bunyan')

ops = stdio.getopt({
  'cwd': {
    args: 1
    description: 'The local repository to update'
  }
  'secret': {
    args: 1
    description: 'The secret to use with the signature'
  }
  'name': {
    args: 1
    description: 'The name of this app to use for logging'
  }
})

config = {
  cwd: '~'
  secret: null
  name: 'GitHubWebHookDeploy'
  basePath: ''
  port: 3000
}

if ops.cwd
  config.cwd = ops.cwd
if ops.secret
  config.secret = ops.secret
if ops.name
  config.name = ops.name

log = bunyan.createLogger({name: config.name})

app = express()
app.set('port', process.env.PORT || config.port || 3000)
app.use(morgan('dev'))
app.use(bodyParser())

app.post('/payload',(req,res) ->
  log.debug({body: req.body},'received request for /payload')
  event = req.get('X-Github-Event')
  if 'push' == event
    valid = true
    if null != config.secret
      calculatedSignature = crypto.createHmac('sha1', config.secret).update(JSON.stringify(req.body)).digest('hex')
      signature = req.get('X-Hub-Signature')
      if undefined != signature && null != signature
        signature = signature.substr(5)
      if undefined  != signature && null != signature && calculatedSignature != signature
        valid = false
        log.warn({requestSignature: signature, calculatedSignature: calculatedSignature},'calculated signature doesn\'t match the signature found the the request')
    if valid
      log.debug({github: {event: req.get('X-Github-Event'), signature: req.get('X-Hub-Signature')}, cwd: config.cwd},'running git update')
      update = spawn('git',['pull'],{cwd:config.cwd})
      update.stdout.on('data', (data) ->
        log.debug({data: data},'git pull info output')
      )
      update.stderr.on('data', (data) ->
        log.warn({data: data},'git pull error output')
      )
  res.send()
)

http.createServer(app).listen(app.get('port'), () ->
  log.info({port: app.get('port')},'Express server started')
)