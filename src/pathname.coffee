core =
  fs:   require('fs')
  path: require('path')
  util: require('util')

# --------------------------------------------------
# Helpers
# --------------------------------------------------
flatten = (array) ->
  array.reduce(((memo, value) =>
    value = flatten(value) if Array.isArray(value)
    memo.concat(value)
  ), [])

extractCallback = (args...) ->
  i = k for v,k in args when v?.constructor is Function
  [args[i] or (->), args[0...i]...]

# --------------------------------------------------

# TODO return @ when possible
class Pathname

  @normalize: (path) ->
    core.path.normalize(path).replace(/\/$/,'')

  constructor: (path) ->
    @path = @constructor.normalize(core.path.normalize(path))

  # --------------------------------------------------
  # path functions
  # --------------------------------------------------

  # FIXME
  join: (path) ->
    new @constructor(core.path.join(@path, path))

  # FIXME
  dirname: ->
    @path.split('/').slice(0, -1).join('/')

  # FIXME
  basename: ->
    @path.split('/').slice(-1)

  # FIXME
  extname: ->
    if /\./.test(@path) then @path.split('.').slice(-1) else null

  # TODO unify
  exists: (cb) ->
    core.path.exists(@path, cb)

  existsSync: ->
    try core.fs.statSync(@path); true
    catch e then                 false

  # --------------------------------------------------
  # fs functions
  # --------------------------------------------------

  # TODO unify
  stat: (cb) ->
    core.fs.stat(@path, cb)

  statSync: ->
    core.fs.statSync(@path)

  # TODO rename to realpath
  absoluteSync: ->
    new @constructor(core.fs.realpathSync(@path))

  # TODO unify
  unlink: (cb) ->
    core.fs.unlink(@path, cb)

  unlinkSync: ->
    core.fs.unlinkSync(@path)

  # TODO remove aliases
  rm: (cb) ->
    @unlink(cb)

  rmSync: ->
    @unlinkSync()

  # TODO unify
  rmdir: (cb) ->
    core.fs.rmdir(@path, cb)

  rmdirSync: ->
    core.fs.rmdirSync(@path)

  # TODO unify
  mkdir: (mode, cb) ->
    [cb, mode] = [mode, undefined] if mode?.constructor is Function
    core.fs.mkdir @path, mode ? 0700, (err) => cb(err, @)

  mkdirSync: (mode = 0700) ->
    core.fs.mkdirSync(@path, mode)
    @

  # TODO unify
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

  # TODO
  # rename
  # truncate
  # chmod
  # lstat
  # link
  # symlink
  # readlink
  # close
  # read    (use readFile)
  # write   (use writeFile)
  # watch
  # unwatch

  # --------------------------------------------------
  # fs.Stats functions
  # --------------------------------------------------

  # TODO unify
  isFile: (cb) ->
    @exists (exists) =>
      exists and @stat (err, stats) -> cb(err, stats.isFile())

  isFileSync: ->
    @existsSync() and @statSync().isFile()

  # TODO unify
  isDirectory: (cb) ->
    @exists (exists) =>
      exists and @stat (err, stats) -> cb(err, stats.isDirectory())

  isDirectorySync: ->
    @existsSync() and @statSync().isDirectory()

  # TODO
  # isBlockDevice
  # isCharacterDevice
  # isSymbolicLink
  # isFIFO
  # isSocket

  # --------------------------------------------------
  # pathname functions
  # --------------------------------------------------

  toString: ->
    @path

  parent: ->
    new @constructor(@dirname())

  # TODO unify
  touch: (cb) ->
    core.fs.open @path, 'w+', undefined, (err, fd) =>
      cb(err) if err?
      core.fs.close fd, (err) =>
        cb(err) if err?
        cb(null, @)

  touchSync: ->
    core.fs.closeSync(core.fs.openSync(@path, 'w+'))
    @

  # TODO async version
  treeSync: (depth) ->
    paths = [@]

    if @isDirectorySync() and (!depth? or depth > 0)
      core.fs.readdirSync(@path).forEach (fname) => paths.push(@join(fname).treeSync(depth and (depth - 1)))

    flatten(paths)

  # TODO account for symlinks
  rmRSync: ->
    @treeSync().reverse().forEach (path) ->
      # if path.isFileSync() or path.isSymbolicSync() then path.unlinkSync()
      if path.isFileSync() then path.unlinkSync()
      if path.isDirectorySync()                     then path.rmdirSync()

  # TODO
  # tree    (async)
  # rmR     (async)
  # mkdirP
  # children
  # siblings
  # chdir

module.exports = Pathname

