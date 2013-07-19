fs = require('fs')
async = require('async')
request = require('request')
getuid = require('getuid')
{exec} = require('child_process')

API_ENDPOINT = 'http://paras.rulemotion.com:1337'
HAKI_PATH = '/home/haki'

try
	state = require('./state.json')
catch e
	console.error(e)
	process.exit()

bootstrapTasks = [
	# get config from extra partition
	(callback) ->
		try
			callback(null, require('/mnt/config.json'))
		catch error
			callback(error)
	# bootstrapping
	(config, callback) ->
		request.post("#{API_ENDPOINT}/associate", {
			json:
				user: config.id
		}, (error, response, body) ->
			if error
				return callback(error)

			if typeof body isnt 'object'
				callback(body)

			state.virgin = false
			state.uuid = body.uuid
			state.giturl = body.giturl

			console.log state

			fs.writeFileSync('state.json', JSON.stringify(state))

			fs.writeFileSync('/etc/openvpn/ca.crt', body.ca)
			fs.writeFileSync('/etc/openvpn/client.crt', body.cert)
			fs.writeFileSync('/etc/openvpn/client.key', body.key)
			fs.appendFileSync('/etc/openvpn/client.conf', "remote #{body.vpnhost} #{body.vpnport}")

			callback(null)
		)
]

setHakiEnv = (callback) ->
	process.setuid(getuid('haki'))
	process.chdir(HAKI_PATH)
	callback()

stage1Tasks = [
	(callback) -> async.waterfall(bootstrapTasks, callback)
	(callback) -> exec('systemctl start openvpn@client', callback)
	(callback) -> exec('systemctl enable openvpn@client', callback)
	setHakiEnv
	(callback) -> fs.mkdir('hakiapp', callback)
	(callback) -> exec('git init', cwd: 'hakiapp', callback)
	(callback) -> exec("git remote add origin #{state.giturl}", cwd: 'hakiapp', callback)
]

updateRepo = (callback) ->
	tasks1 = [
		(callback) -> setTimeout(callback, 3e5)
		(callback) -> exec('git pull', cwd: 'hakiapp', callback)
		(stdout, stderr, callback) -> exec('git rev-parse HEAD', cwd: 'hakiapp', callback)
		(stdout, stderr, callback) -> callback(null, stdout.trim())
	]

	tasks2 = [
		(callback) -> exec('npm install', cwd: 'hakiapp', callback)
		(callback) -> exec('foreman start', cwd: 'hakiapp', callback)
	]

	async.waterfall(tasks1, (error, hash) ->
		if hash isnt state.githead
			state.githead = hash
			async.series(tasks2, callback)
		else
			callback()

stage2Tasks = [
	setHakiEnv
	(callback) -> async.forever(updateRepo, callback)
]

if state.virgin
	tasks = stage1Tasks.concat(stage2Tasks)
else
	tasks = stage2Tasks

async.series(tasks, (error, results) ->
	if (error)
		console.error(error)
	else
		console.log('Bootstrapped')
)
