core =
  fs:   require('fs')
  sys:  require('sys')
  path: require('path')
  util: require('util')


global.puts    = core.sys.puts
global.debug   = core.util.debug
global.inspect = core.util.inspect
global.d       = (x) -> debug inspect x

_        = require('underscore')
assert   = require('assert')
temp     = require('temp')
Pathname = require('../src/index')

# --------------------------------------------------
# Helpers
# --------------------------------------------------
with_tmpdir = (cb) ->
  temp.mkdir "Pathname-", (err, dirPath) ->
    assert.ifError(err)
    cb(dirPath)

with_tmpfile = (cb) ->
  temp.open "Pathname-", (err, info) ->
    assert.ifError(err)
    cb(info.path, info.fd)

assert.include = (enumerable, value, message) ->
  message ?= "Expected '#{inspect(enumerable)}' to include '#{inspect(value)}'"
  assert.ok((enumerable.some (item) -> _.isEqual(item, value)), message)

assert.closed = (fd) ->
  assert.throws (-> core.fs.readSync(fd, new Buffer(1), 0, 1, 0)), Error, "fd '#{fd}' is open, expected it to be closed"

assert.open = (fd) ->
  assert.doesNotThrow (-> core.fs.readSync(fd, new Buffer(1), 0, 1, 0)), Error, "fd '#{fd}' is closed, expected it to be open"

assert.match = (actual, expected) ->
  assert.ok expected.test(actual), "Expected #{expected} to match #{actual}"

assert.__defineGetter__ 'defered', ->
  proxy = {}
  delete @.defered
  for key, val of @ when val?.constructor is Function
    proxy[key] = (args...) ->
      process.on 'exit', -> val(args...)
  @.__defineGetter__('defered', arguments.callee)
  proxy

# source: http://efreedom.com/Question/1-3561493/RegExpescape-Function-Javascript
# author: bobince
RegExp.escape = (exp) ->
  exp.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&')

# --------------------------------------------------
# Tests
# --------------------------------------------------

## test object wraps path
assert.equal new Pathname('/tmp/foo').toString(), '/tmp/foo'


## test normalizes path on creation
assert.equal new Pathname('/tmp/foo/'       ).toString(), '/tmp/foo'
assert.equal new Pathname('/tmp/foo/bar/../').toString(), '/tmp/foo'


## test joining paths
assert.equal new Pathname("/tmp/foo").join("bar").constructor, Pathname
assert.equal new Pathname("/tmp/foo").join("bar").toString(),  "/tmp/foo/bar"
assert.equal new Pathname("/tmp/foo").join("/bar").toString(), "/tmp/foo/bar"
assert.equal new Pathname("/tmp/foo").join("bar/").toString(), "/tmp/foo/bar"


## test extracts basename
assert.equal new Pathname('/tmp/foo'    ).basename(), 'foo'
assert.equal new Pathname('/tmp/foo.ext').basename(), 'foo.ext'


## test extracts dirname
assert.equal new Pathname('/tmp/foo/bar.txt').dirname(), '/tmp/foo'
assert.equal new Pathname('/tmp/foo/bar'    ).dirname(), '/tmp/foo'


## test extracts extension
assert.equal new Pathname('/tmp/foo'        ).extname(), null
assert.equal new Pathname('/tmp/foo.ext'    ).extname(), 'ext'
assert.equal new Pathname('/tmp/foo.txt.ext').extname(), 'ext'


## test knows dir exists
with_tmpdir (path) ->
  assert.ok new Pathname(path).existsSync()

with_tmpdir (path) ->
  new Pathname(path).exists (exists) -> assert.ok(exists)


## test knows file exists
with_tmpfile (path) ->
  assert.ok new Pathname(path).existsSync()

with_tmpfile (path) ->
  new Pathname(path).exists (exists) -> assert.ok(exists)


## test knows path doesn't exist
assert.ok not new Pathname(temp.path()).existsSync()


## test queries stats
with_tmpdir (path) ->
  assert.equal new Pathname(path).statSync().ino, core.fs.statSync(path).ino

with_tmpdir (path) ->
  new Pathname(path).stat (err, info) ->
    assert.ifError err
    assert.equal info.ino, core.fs.statSync(path).ino


# test expands path
with_tmpdir (path) ->
  cwd = process.cwd()
  try
    process.chdir(path)
    base =           new Pathname(path).basename()
    assert.deepEqual new Pathname(base).realpathSync(), new Pathname(path)
  catch e
    puts inspect("Expection: #{e}")
  finally
    process.chdir(cwd)


## test removes a file
with_tmpfile (path) ->
  path = new Pathname(path)
  path.unlink (err) ->
    assert.ifError(err)
    assert.ok not path.existsSync()
    assert.ok not path.isFileSync()

with_tmpfile (path) ->
  path = new Pathname(path)
  path.unlinkSync()
  assert.ok not path.existsSync()
  assert.ok not path.isFileSync()


## test removes empty directory
with_tmpdir (path) ->
  path = new Pathname(path)
  path.rmdir (err) ->
    assert.ifError(err)
    assert.ok not path.existsSync()
    assert.ok not path.isDirectorySync()

with_tmpdir (path) ->
  path = new Pathname(path)
  path.rmdirSync()
  assert.ok not path.existsSync()
  assert.ok not path.isDirectorySync()


## test creates directory
try
  path = new Pathname(temp.path()).mkdirSync()
  assert.ok path.existsSync()
  assert.ok path.isDirectorySync()
  # assert.equal path.statSync().mode, 0700 #TODO
finally
  core.fs.rmdirSync(path.toString()) if path?

new Pathname(temp.path()).mkdir undefined, (err, path) ->
  try
    assert.ifError err
    assert.ok path.existsSync()
    assert.ok path.isDirectorySync()
    # assert.equal path.statSync().mode, 0700 #TODO
  finally
    core.fs.rmdirSync(path.toString()) if path?

new Pathname(temp.path()).mkdir (err, path) ->
  try
    assert.ifError err
    assert.ok path.existsSync()
    assert.ok path.isDirectorySync()
    # assert.equal path.statSync().mode, 0700 #TODO
  finally
    core.fs.rmdirSync(path.toString()) if path?


## test opens file (sync)
with_tmpfile (path, fd) ->
  core.fs.writeFileSync(path, 'foo')
  core.fs.closeSync(fd)

  new Pathname(path).openSync 'r', 0666, (_fd) ->
    fd = _fd
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'

  assert.closed(fd)

  new Pathname(path).openSync 'r', (_fd) ->
    fd = _fd
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'

  assert.closed(fd)

  new Pathname(path).openSync (_fd) ->
    fd = _fd
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'

  assert.closed(fd)

  try
    new Pathname(path).openSync (_fd) ->
      fd = _fd
      throw new Error("handle me")
  finally
    assert.closed(fd)

## test opens file (async)
with_tmpfile (path, fd) ->
  core.fs.writeFileSync(path, 'foo')
  core.fs.closeSync(fd)

  new Pathname(path).open 'r', 0666, (err, _fd) ->
    assert.ifError(err)
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'
    assert.defered.closed(_fd)

  new Pathname(path).open 'r', (err, _fd) ->
    assert.ifError(err)
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'
    assert.defered.closed(_fd)

  new Pathname(path).open (err, _fd) ->
    assert.ifError(err)
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'
    assert.defered.closed(_fd)


## test knows path is a file
with_tmpfile (path) ->
  assert.ok new Pathname(path).isFileSync()

with_tmpdir (path) ->
  assert.ok not new Pathname(path).isFileSync()

assert.ok not new Pathname(temp.path()).isFileSync()

with_tmpfile (path) ->
  new Pathname(path).isFile (err, isFile) ->
    assert.ifError err
    assert.ok isFile

with_tmpdir (path) ->
  new Pathname(path).isFile (err, isFile) ->
    assert.ifError(err)
    assert.ok not isFile

new Pathname(temp.path()).isFile (err, isFile) ->
  assert.ifError(err)
  assert.ok not isFile


## test knows path is a dir
with_tmpdir (path) ->
  assert.ok new Pathname(path).isDirectorySync()

with_tmpfile (path) ->
  assert.ok not new Pathname(path).isDirectorySync()

assert.ok not new Pathname(temp.path()).isDirectorySync()

with_tmpdir (path) ->
  new Pathname(path).isDirectory (err, isDirectory) ->
    assert.ifError(err)
    assert.ok isDirectory

with_tmpfile (path) ->
  new Pathname(path).isDirectory (err, isDirectory) ->
    assert.ifError(err)
    assert.ok not isDirectory

new Pathname(temp.path()).isDirectory (err, isDirectory) ->
  assert.ifError(err)
  assert.ok not isDirectory


## test finds parent directory
assert.deepEqual new Pathname('/tmp/foo/bar.txt').parent(), new Pathname('/tmp/foo')
assert.deepEqual new Pathname('/tmp/foo/bar'    ).parent(), new Pathname('/tmp/foo')


## test creates file
try
  path = new Pathname(temp.path()).touchSync()
  assert.ok path.existsSync()
  assert.ok path.isFileSync()
finally
  core.fs.unlinkSync(path.toString()) if path?

new Pathname(temp.path()).touch (err, path) ->
  try
    assert.ok path.existsSync()
    assert.ok path.isFileSync()
  finally
    core.fs.unlinkSync(path.toString()) if path?


## test traverses directory tree recursively
with_tmpdir (path) ->
  try
    root = new Pathname(path)
    root.join('bar'        ).touchSync()
    root.join('boo'        ).mkdirSync()
    root.join('boo/moo'    ).mkdirSync()
    root.join('boo/moo/zoo').touchSync()

    assert.ok root.treeSync().every (path) -> path.constructor == Pathname

    tree = root.treeSync(0)
    assert.equal   tree.length, 1
    assert.include tree, root

    assert.equal root.treeSync(-1).length, tree.length

    tree = root.treeSync(1)
    assert.equal   tree.length, 3
    assert.include tree, root
    assert.include tree, root.join('bar')
    assert.include tree, root.join('boo')

    tree = root.treeSync(2)
    assert.equal   tree.length, 4
    assert.include tree, root
    assert.include tree, root.join('bar')
    assert.include tree, root.join('boo')
    assert.include tree, root.join('boo/moo')

    tree = root.treeSync(3)
    assert.equal   tree.length, 5
    assert.include tree, root
    assert.include tree, root.join('bar')
    assert.include tree, root.join('boo')
    assert.include tree, root.join('boo/moo')
    assert.include tree, root.join('boo/moo/zoo')

    assert.equal root.treeSync(undefined).length, tree.length
    assert.equal root.treeSync(null     ).length, tree.length
  finally
    if root?
      root.join('boo/moo/zoo').unlinkSync()
      root.join('boo/moo'    ).rmdirSync()
      root.join('boo'        ).rmdirSync()
      root.join('bar'        ).unlinkSync()


## deletes directory tree
with_tmpdir (path) ->
  try
    root = new Pathname(path)
    root.join('bar'        ).touchSync()
    root.join('boo'        ).mkdirSync()
    root.join('boo/moo'    ).mkdirSync()
    root.join('boo/moo/zoo').touchSync()

    # make sure root is a tmp dir
    regexp = new RegExp("^#{RegExp.escape(temp.dir)}")
    assert.match root.realpathSync().toString(), regexp

    root.rmRSync()

    assert.equal root.join('boo').existsSync(), false
  finally
    if root?.existsSync()
      root.join('boo/moo/zoo').unlinkSync()
      root.join('boo/moo'    ).rmdirSync()
      root.join('boo'        ).rmdirSync()
      root.join('bar'        ).unlinkSync()


###

