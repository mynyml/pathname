core =
  fs:   require('fs')
  path: require('path')
  util: require('util')

# --------------------------------------------------
# Helpers
# --------------------------------------------------
flatten = (array) ->
  @reduce(((memo, value) => 
    value = flatten(value) if @constructor.isArray(value)
    memo.concat(value)
  ), [])

extractCallback = (args...) ->
  i = k for v,k in args when v?.constructor is Function
  [args[i] or (->), args[0...i]...]

# --------------------------------------------------

# TODO rmR(), mkdirP(), open(), close(), children(), siblings(),
#      chdir([block]), read() (== readFile()), write() (== writeFile()),
#      watch(), unwatch()
class Pathname

  @normalize: (path) ->
    core.path.normalize(path).replace(/\/$/,'')

  constructor: (path) ->
    @path  = @constructor.normalize(core.path.normalize(path))
    @depth = @path.split('/').length

  parent: ->
    new @constructor(@dirname())

  dirname: ->
    @path.split('/').slice(0, -1).join('/')

  basename: ->
    @path.split('/').slice(-1)

  extname: ->
    if /\./.test(@path) then @path.split('.').slice(-1) else null

  absoluteSync: ->
    new @constructor(core.fs.realpathSync(@path))

  exists: (cb) ->
    core.path.exists(@path, cb)

  existsSync: ->
    try core.fs.statSync(@path); true
    catch e then                 false

  join: (path) ->
    new @constructor(core.path.join(@path, path))

  stat: (cb) ->
    core.fs.stat(@path, cb)

  statSync: ->
    core.fs.statSync(@path)

  isFile: (cb) ->
    @exists (exists) =>
      exists and @stat (err, stats) -> cb(err, stats.isFile())

  isFileSync: ->
    @existsSync() and @statSync().isFile()

  isDirectory: (cb) ->
    @exists (exists) =>
      exists and @stat (err, stats) -> cb(err, stats.isDirectory())

  isDirectorySync: ->
    @existsSync() and @statSync().isDirectory()

  toString: ->
    @path

  tree: (args...) -> @treeSync(args...)

  treeSync: (depth) ->
    paths = [@]

    if @isDirectorySync() and (!depth? or @depth < depth)
      core.fs.readdirSync(@path).forEach (fname) => paths.push(@join(fname).treeSync(depth))

    flatten(paths)

  mkdir: (mode, cb) ->
    [cb, mode] = [mode, undefined] if mode?.constructor is Function
    core.fs.mkdir @path, mode ? 0700, (err) => cb(err, @)

  mkdirSync: (mode = 0700) ->
    core.fs.mkdirSync(@path, mode)
    @

  touch: (cb) ->
    core.fs.open @path, 'w+', undefined, (err, fd) =>
      cb(err) if err?
      core.fs.close fd, (err) =>
        cb(err) if err?
        cb(null, @)

  touchSync: ->
    core.fs.closeSync(core.fs.openSync(@path, 'w+'))
    @

  rmdir: (cb) ->
    core.fs.rmdir(@path, cb)

  rmdirSync: ->
    core.fs.rmdirSync(@path)

  unlink: (cb) ->
    core.fs.unlink(@path, cb)

  unlinkSync: ->
    core.fs.unlinkSync(@path)

  rm: (cb) ->
    @unlink(cb)

  rmSync: ->
    @unlinkSync()

  open: (flags, mode, cb) ->
    [cb, flags, mode] = extractCallback(flags, mode, cb)

    fd = core.fs.open @path, flags or 'r+', mode, (err, fd) ->
      try
        cb(err, fd)
      finally
        core.fs.closeSync(fd)

  openSync: (flags, mode, cb) ->
    [cb, flags, mode] = extractCallback(flags, mode, cb)

    fd = core.fs.openSync(@path, flags or 'r+', mode)
    try
      cb(fd)
    finally
      core.fs.closeSync(fd)


module.exports = Pathname

