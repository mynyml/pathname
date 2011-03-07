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
    @path = core.path.normalize(path.toString()).replace(/(.)\/$/,'$1')

  # --------------------------------------------------
  # path functions
  # --------------------------------------------------

  join: (paths...) ->
    new @constructor(core.path.join(@path, paths.map((path) -> path.toString())...))

  dirname: ->
    new @constructor(core.path.dirname(@path))

  # FIXME return as string?
  basename: (ext) ->
    new @constructor(core.path.basename(@path, ext))

  extname: ->
    core.path.extname(@path)

  exists: (cb) ->
    if cb?
      core.path.exists(@path, cb)
    else
      core.path.existsSync(@path)

  # TODO
  # normalize
  # resolve (?)

  # --------------------------------------------------
  # fs functions
  # --------------------------------------------------

  stat: (cb) ->
    if cb?
      core.fs.stat(@path, cb)
    else
      core.fs.statSync(@path)

  lstat: (cb) ->
    if cb?
      core.fs.lstat(@path, cb)
    else
      core.fs.lstatSync(@path)

  # TODO async version
  realpath: ->
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
      if @fd?
        process.nextTick(=> cb(null, @fd))
      else
        core.fs.open @path, flags, mode, (err, @fd) =>
          try
            cb(err, @fd)
          finally
            @close()
    else
      return @fd if @fd?
      @fd = core.fs.openSync(@path, flags, mode)

  close: (cb) ->
    if cb?
      if @fd?
        core.fs.close @fd, (err) => cb(err, @)
        delete @fd
      else
        cb(null, @)
    else
      if @fd?
        core.fs.closeSync(@fd)
        delete @fd
        @

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

  chmod: (mode, cb) ->
    [cb, mode] = extractCallback(mode, cb)

    if cb?
      core.fs.chmod(@path, mode, cb)
    else
      core.fs.chmodSync(@path, mode)

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

  link: (dstpath, cb) ->
    [cb, dstpath] = extractCallback(dstpath, cb)

    if cb?
      core.fs.link @path, dstpath.toString(), (err) => cb(err, @)
    else
      core.fs.linkSync(@path, dstpath.toString())
      @

  symlink: (dstpath, cb) ->
    [cb, dstpath] = extractCallback(dstpath, cb)

    if cb?
      core.fs.symlink @path, dstpath.toString(), (err) => cb(err, @)
    else
      core.fs.symlinkSync(@path, dstpath.toString())
      @

  readlink: (cb) ->
    if cb?
      core.fs.readlink @path, (err, path) => cb(err, new @constructor(path))
    else
      new @constructor(core.fs.readlinkSync(@path))

  readdir: (cb) ->
    if cb?
      core.fs.readdir @path, (err, paths) =>
        if err?
          cb(err, null)
        else
          cb(null, paths.map (path) => new @constructor(path))
    else
      core.fs.readdirSync(@path).map (path) => new @constructor(path)

  watchFile: (args...) ->
    core.fs.watchFile(@path, args...)

  unwatchFile: ->
    core.fs.unwatchFile(@path)

  # --------------------------------------------------
  # fs.Stats functions
  # --------------------------------------------------

  for func in ['isFile', 'isDirectory', 'isBlockDevice', 'isCharacterDevice', 'isFIFO', 'isSocket']
    do (func) =>
      @::[func] = (cb) ->
        if cb?
          @exists (exists) =>
            if exists
              @stat (err, stats) -> cb(err, stats[func]())
            else
              cb(null, no)
        else
          @exists() and @stat()[func]()

  isSymbolicLink: (cb) ->
    if cb?
      @lstat (err, stats) ->
        if /^ENOENT/.test(err?.message)
          cb(null, no)
        else
          cb(err, stats?.isSymbolicLink())
    else
      try
        @lstat().isSymbolicLink()
      catch e
        no

  # --------------------------------------------------
  # Pathname functions
  # --------------------------------------------------

  toString: ->
    @path

  parent: ->
    @dirname()

  touch: (mode, cb) ->
    [cb, mode] = extractCallback(mode, cb)

    if cb?
      @open 'w+', mode, (err, _) => cb(err, @)
    else
      @open('w+', mode); @close()

  # TODO async version not so async
  tree: (depth, cb) ->
    [cb, depth] = extractCallback(depth, cb)

    done  = no
    paths = [@]

    # FIXME i are teh uglie
    if cb?
      if not @isSymbolicLink() and @isDirectory() and (!depth? or depth > 0)
        core.fs.readdir @path, (err, files) =>
          return if done
          if err?
            done = yes
            cb(err, null)
          else
            count = files.length
            files.forEach (fname) =>
              @join(fname).tree (depth and (depth - 1)), (err, _paths) ->
                return if done #avoid calling cb more than once
                if err?
                  done = yes
                  cb(err, null)
                else
                  paths.push(_paths)
                  cb(null, flatten(paths)) if --count is 0
      else
        cb(null, paths)

    else
      if not @isSymbolicLink() and @isDirectory() and (!depth? or depth > 0)
        core.fs.readdirSync(@path).forEach (fname) => paths.push(@join(fname).tree(depth and (depth - 1)))

      flatten(paths)

  # TODO async version not so async
  rmR: (cb) ->
    if cb?
      @tree (err, files) ->
        if err?
          cb(err)
        else
          files.reverse().forEach (path) ->
            if path.isSymbolicLink() then path.unlink()
            if path.isFile()         then path.unlink()
            if path.isDirectory()    then path.rmdir()
          cb(null)
    else
      @tree().reverse().forEach (path) ->
        if path.isSymbolicLink() then path.unlink()
        if path.isFile()         then path.unlink()
        if path.isDirectory()    then path.rmdir()

  mkdirP: (cb) ->
    create = =>
      @traverse((path) -> path.mkdir() unless path.exists())

    if cb?
      process.nextTick =>
        try
          create() #sync, to garantee order
          cb(null)
        catch e
          cb(e)
    else
      create()

  traverse: (cb) ->
    cb(@components().map((path) => new @constructor(path)).reduce((curr, next) -> cb(curr); curr.join(next)))

  components: ->
    elements = @toString().split('/').filter (e) -> e.length isnt 0
    elements.unshift('/') if @toString()[0] is '/'
    elements

  children: (args...) -> @readdir(args...)


  # TODO
  # siblings
  # chdir
  # relativeFrom

module.exports = Pathname

