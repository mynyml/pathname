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
  [args[i], args[0...i]...]

# --------------------------------------------------

# TODO return @ when possible
class Pathname

  constructor: (path) ->
    @path = core.path.normalize(path.toString()).replace(/\/$/,'')

  # --------------------------------------------------
  # path functions
  # --------------------------------------------------

  join: (paths...) ->
    new @constructor(core.path.join(@path, paths...))

  dirname: ->
    new @constructor(core.path.dirname(@path))

  basename: (ext) ->
    new @constructor(core.path.basename(@path, ext))

  extname: ->
    core.path.extname(@path)

  exists: (cb) ->
    if cb?
      core.path.exists(@path, cb)
    else
      try @stat(@path); true
      catch e then      false

  # --------------------------------------------------
  # fs functions
  # --------------------------------------------------

  stat: (cb) ->
    if cb?
      core.fs.stat(@path, cb)
    else
      core.fs.statSync(@path)

  realpathSync: ->
    new @constructor(core.fs.realpathSync(@path))

  unlink: (cb) ->
    if cb?
      core.fs.unlink(@path, cb)
    else
      core.fs.unlinkSync(@path)

  rmdir: (cb) ->
    if cb?
      core.fs.rmdir(@path, cb)
    else
      core.fs.rmdirSync(@path)

  mkdir: (mode, cb) ->
    [cb, mode] = [mode, undefined] if mode?.constructor is Function
    mode ?= 0700
    if cb?
      core.fs.mkdir @path, mode, (err) => cb(err, @)
    else
      core.fs.mkdirSync(@path, mode)
      @

  # TODO mode defaults to 0666
  open: (flags, mode, cb) ->
    [cb, flags, mode] = extractCallback(flags, mode, cb)

    if cb?
      core.fs.open @path, flags, mode, (err, fd) ->
        try
          cb(err, fd)
        finally
          core.fs.closeSync(fd)
    else
      core.fs.openSync(@path, flags, mode)

  rename: (path, cb) ->
    [cb, path] = extractCallback(path, cb)

    if cb?
      core.fs.rename @path, path.toString(), (err) =>
        cb(err, new @constructor(path.toString()))
    else
      core.fs.renameSync(@path, path.toString())
      new @constructor(path.toString())

  # TODO figure out "Bad file descriptor" error with fs.truncate()
  truncate: (len, cb) ->
    [cb, len] = extractCallback(len, cb)

    if cb?
      @open 'r+', 0666, (err, fd) ->
        if err?
          cb(err)
        else
          core.fs.truncate(fd, len, cb)
          # core.fs.truncateSync(fd, len)
          # cb()
    else
      core.fs.truncateSync(@open('r+', 0666), len)

  readFile: (encoding, cb) ->
    [cb, encoding] = extractCallback(encoding, cb)

    if cb?
      core.fs.readFile @path, encoding, cb
    else
      core.fs.readFileSync(@path, encoding)

  writeFile: (data, encoding, cb) ->
    [cb, data, encoding] = extractCallback(data, encoding, cb)

    if cb?
      core.fs.writeFile @path, data, encoding, cb
    else
      core.fs.writeFileSync(@path, data, encoding)

  # TODO
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

  isFile: (cb) ->
    if cb?
      @exists (exists) =>
        if not exists
          cb(null, false)
        else
          @stat (err, stats) -> cb(err, stats.isFile())
    else
      @exists() and @stat().isFile()

  isDirectory: (cb) ->
    if cb?
      @exists (exists) =>
        if not exists
          cb(null, false)
        else
          @stat (err, stats) -> cb(err, stats.isDirectory())
    else
      @exists() and @stat().isDirectory()

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
    @dirname()

  # FIXME calls cb twice if fs.open() provides err
  # FIXME use try/catch in sync mode
  touch: (cb) ->
    if cb?
      core.fs.open @path, 'w+', undefined, (err, fd) =>
        cb(err) if err?
        core.fs.close fd, (err) =>
          cb(err) if err?
          cb(null, @)
    else
      core.fs.closeSync(core.fs.openSync(@path, 'w+'))
      @

  # TODO async version
  treeSync: (depth) ->
    paths = [@]

    if @isDirectory() and (!depth? or depth > 0)
      core.fs.readdirSync(@path).forEach (fname) => paths.push(@join(fname).treeSync(depth and (depth - 1)))

    flatten(paths)

  # TODO async version
  # TODO account for symlinks
  rmRSync: ->
    @treeSync().reverse().forEach (path) ->
      # if path.isFile() or path.isSymbolicSync() then path.unlinkSync()
      if path.isFile()      then path.unlink()
      if path.isDirectory() then path.rmdir()

  # TODO
  # tree    (async)
  # rmR     (async)
  # mkdirP
  # children
  # siblings
  # chdir
  # relativeFrom

module.exports = Pathname

