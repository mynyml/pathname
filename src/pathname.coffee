mods =
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
    @path = mods.path.normalize(path.toString()).replace(/(.)\/$/,'$1')

  # --------------------------------------------------
  # path functions
  # --------------------------------------------------

  join: (paths...) ->
    new @constructor(mods.path.join(@path, paths.map((path) -> path.toString())...))

  dirname: ->
    new @constructor(mods.path.dirname(@path))

  # FIXME return as string?
  basename: (ext) ->
    new @constructor(mods.path.basename(@path, ext))

  extname: ->
    mods.path.extname(@path)

  exists: (cb) ->
    if cb?
      mods.path.exists(@path, cb)
    else
      mods.path.existsSync(@path)

  # TODO
  # normalize
  # resolve (?)

  # --------------------------------------------------
  # fs functions
  # --------------------------------------------------

  stat: (cb) ->
    if cb?
      mods.fs.stat(@path, cb)
    else
      mods.fs.statSync(@path)

  lstat: (cb) ->
    if cb?
      mods.fs.lstat(@path, cb)
    else
      mods.fs.lstatSync(@path)

  # TODO async version
  realpath: ->
    new @constructor(mods.fs.realpathSync(@path))

  unlink: (cb) ->
    if cb?
      mods.fs.unlink(@path, cb)
    else
      mods.fs.unlinkSync(@path)

  rmdir: (cb) ->
    if cb?
      mods.fs.rmdir(@path, cb)
    else
      mods.fs.rmdirSync(@path)

  mkdir: (mode, cb) ->
    [cb, mode] = [mode, undefined] if mode?.constructor is Function
    mode ?= 0700
    if cb?
      mods.fs.mkdir @path, mode, (err) => cb(err, @)
    else
      mods.fs.mkdirSync(@path, mode)
      @

  # TODO mode defaults to 0666
  open: (flags, mode, cb) ->
    [cb, flags, mode] = extractCallback(flags, mode, cb)

    if cb?
      if @fd?
        process.nextTick(=> cb(null, @fd))
      else
        mods.fs.open @path, flags, mode, (err, @fd) =>
          try
            cb(err, @fd)
          finally
            @close()
    else
      return @fd if @fd?
      @fd = mods.fs.openSync(@path, flags, mode)

  close: (cb) ->
    if cb?
      if @fd?
        mods.fs.close @fd, (err) => cb(err, @)
        delete @fd
      else
        cb(null, @)
    else
      if @fd?
        mods.fs.closeSync(@fd)
        delete @fd
        @

  rename: (path, cb) ->
    [cb, path] = extractCallback(path, cb)

    if cb?
      mods.fs.rename @path, path.toString(), (err) =>
        cb(err, new @constructor(path.toString()))
    else
      mods.fs.renameSync(@path, path.toString())
      new @constructor(path.toString())

  # TODO figure out "Bad file descriptor" error with fs.truncate()
  truncate: (len, cb) ->
    [cb, len] = extractCallback(len, cb)

    if cb?
      @open 'r+', 0666, (err, fd) ->
        if err?
          cb(err)
        else
          mods.fs.truncate(fd, len, cb)
          # mods.fs.truncateSync(fd, len)
          # cb()
    else
      mods.fs.truncateSync(@open('r+', 0666), len)

  chmod: (mode, cb) ->
    [cb, mode] = extractCallback(mode, cb)

    if cb?
      mods.fs.chmod(@path, mode, cb)
    else
      mods.fs.chmodSync(@path, mode)

  readFile: (encoding, cb) ->
    [cb, encoding] = extractCallback(encoding, cb)

    if cb?
      mods.fs.readFile @path, encoding, cb
    else
      mods.fs.readFileSync(@path, encoding)

  writeFile: (data, encoding, cb) ->
    [cb, data, encoding] = extractCallback(data, encoding, cb)

    if cb?
      mods.fs.writeFile @path, data, encoding, cb
    else
      mods.fs.writeFileSync(@path, data, encoding)

  link: (dstpath, cb) ->
    [cb, dstpath] = extractCallback(dstpath, cb)

    if cb?
      mods.fs.link @path, dstpath.toString(), (err) => cb(err, @)
    else
      mods.fs.linkSync(@path, dstpath.toString())
      @

  symlink: (dstpath, cb) ->
    [cb, dstpath] = extractCallback(dstpath, cb)

    if cb?
      mods.fs.symlink @path, dstpath.toString(), (err) => cb(err, @)
    else
      mods.fs.symlinkSync(@path, dstpath.toString())
      @

  readlink: (cb) ->
    if cb?
      mods.fs.readlink @path, (err, path) => cb(err, new @constructor(path))
    else
      new @constructor(mods.fs.readlinkSync(@path))

  readdir: (cb) ->
    if cb?
      mods.fs.readdir @path, (err, paths) =>
        if err?
          cb(err, null)
        else
          cb(null, paths.map (path) => new @constructor(path))
    else
      mods.fs.readdirSync(@path).map (path) => new @constructor(path)

  watchFile: (args...) ->
    mods.fs.watchFile(@path, args...)

  unwatchFile: ->
    mods.fs.unwatchFile(@path)

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
        mods.fs.readdir @path, (err, files) =>
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
        mods.fs.readdirSync(@path).forEach (fname) => paths.push(@join(fname).tree(depth and (depth - 1)))

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

  children: (args...) ->
    @readdir(args...)

  siblings: (cb) ->
    if cb?
      @parent().children (err, paths) =>
        if err?
          cb(err, null)
        else
          _paths = paths.filter (path) =>
            path.toString() isnt @basename().toString()
          cb(null, _paths)
    else
      @parent().children().filter (path) =>
        path.toString() isnt @basename().toString()


  # TODO
  # chdir
  # relativeFrom
  # absolute

module.exports = Pathname

