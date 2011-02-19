core =
  fs:   require('fs')
  sys:  require('sys')
  path: require('path')
  util: require('util')


global.puts    = core.sys.puts
global.inspect = core.util.inspect
global.l       = console.log
global.d       = (x) -> console.log("DEBUG: " + inspect x)

_        = require('underscore')
assert   = require('assert')
temp     = require('temp')
Pathname = require('../src/index')

process._events = {}
process.setMaxListeners(50)

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

# assert.__defineGetter__ 'defered', ->
#   proxy = {}
#   delete @.defered
#   for key, val of @ when val?.constructor is Function
#     proxy[key] = (args...) ->
#       process.on 'exit', -> val(args...)
#   @.__defineGetter__('defered', arguments.callee)
#   proxy


# source: http://efreedom.com/Question/1-3561493/RegExpescape-Function-Javascript
# author: bobince
RegExp.escape = (exp) ->
  exp.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&')

up = (e) ->
  console.log(e.stack)
  console.log(e.message) if e.message?
  throw e

# --------------------------------------------------
# Tests
# --------------------------------------------------

## test object wraps path
assert.equal new Pathname('/tmp/foo').toString(), '/tmp/foo'


## test normalizes path on creation
assert.equal new Pathname('/tmp/foo/'       ).toString(), '/tmp/foo'
assert.equal new Pathname('/tmp/foo/bar/../').toString(), '/tmp/foo'


## test joining paths
assert.equal new Pathname("/tmp/foo" ).join("bar" ).constructor, Pathname
assert.equal new Pathname("/tmp/foo" ).join("bar" ).toString(), "/tmp/foo/bar"
assert.equal new Pathname("/tmp/foo" ).join("bar/").toString(), "/tmp/foo/bar"
assert.equal new Pathname("/tmp/foo" ).join("/bar").toString(), "/tmp/foo/bar"
assert.equal new Pathname("/tmp/foo/").join("/bar").toString(), "/tmp/foo/bar"
assert.equal new Pathname("/tmp/foo/").join("bar", "baz").toString(), "/tmp/foo/bar/baz"


## test extracts dirname
assert.equal new Pathname('/tmp/foo/bar.txt').dirname().constructor, Pathname
assert.equal new Pathname('/tmp/foo/bar.txt').dirname().toString(), '/tmp/foo'
assert.equal new Pathname('/tmp/foo/bar'    ).dirname().toString(), '/tmp/foo'


## test extracts basename
assert.equal new Pathname('/tmp/foo'    ).basename().constructor, Pathname
assert.equal new Pathname('/tmp/foo'    ).basename().toString(), 'foo'
assert.equal new Pathname('/tmp/foo.ext').basename().toString(), 'foo.ext'


## test extracts extension
assert.equal new Pathname('/tmp/foo'        ).extname(), ''
assert.equal new Pathname('/tmp/foo.ext'    ).extname(), '.ext'
assert.equal new Pathname('/tmp/foo.txt.ext').extname(), '.ext'


## test knows dir exists
with_tmpdir (path) ->
  assert.ok new Pathname(path).exists()

with_tmpdir (path) ->
  new Pathname(path).exists (exists) -> assert.ok(exists)


## test knows file exists
with_tmpfile (path) ->
  assert.ok new Pathname(path).exists()

with_tmpfile (path) ->
  new Pathname(path).exists (exists) -> assert.ok(exists)


## test knows path doesn't exist
assert.ok not new Pathname(temp.path()).exists()

with_tmpdir (path) ->
  new Pathname(path).join('foo').exists (exists) ->
    assert.ok not exists


## test queries stats
with_tmpdir (path) ->
  assert.equal new Pathname(path).stat().ino, core.fs.statSync(path).ino

with_tmpdir (path) ->
  new Pathname(path).stat (err, info) ->
    assert.ifError(err)
    assert.equal info.ino, core.fs.statSync(path).ino


# test expands path
# FIXME
#with_tmpdir (path) ->
#  cwd = process.cwd()
#  try
#    process.chdir(path)
#    base =           new Pathname(path).basename()
#    assert.deepEqual new Pathname(base).realpathSync(), new Pathname(path)
#  catch e
#    puts inspect("Expection: #{e}")
#  finally
#    process.chdir(cwd)


## test removes a file
with_tmpfile (path) ->
  path = new Pathname(path)
  path.unlink (err) ->
    assert.ifError(err)
    assert.ok not path.exists()
    assert.ok not path.isFile()

with_tmpfile (path) ->
  path = new Pathname(path)
  path.unlink()
  assert.ok not path.exists()
  assert.ok not path.isFile()


## test removes empty directory
with_tmpdir (path) ->
  path = new Pathname(path)
  path.rmdir (err) ->
    assert.ifError(err)
    assert.ok not path.exists()
    assert.ok not path.isDirectory()

with_tmpdir (path) ->
  path = new Pathname(path)
  path.rmdir()
  assert.ok not path.exists()
  assert.ok not path.isDirectory()


## test creates directory
try
  path = new Pathname(temp.path()).mkdir()
  assert.ok path.exists()
  assert.ok path.isDirectory()
  # assert.equal path.statSync().mode, 0700 #TODO
finally
  core.fs.rmdirSync(path.toString()) if path?

new Pathname(temp.path()).mkdir undefined, (err, path) ->
  try
    assert.ifError(err)
    assert.ok path.exists()
    assert.ok path.isDirectory()
    # assert.equal path.statSync().mode, 0700 #TODO
  finally
    core.fs.rmdirSync(path.toString()) if path?

new Pathname(temp.path()).mkdir (err, path) ->
  try
    assert.ifError(err)
    assert.ok path.exists()
    assert.ok path.isDirectory()
    # assert.equal path.statSync().mode, 0700 #TODO
  finally
    core.fs.rmdirSync(path.toString()) if path?


## test opens file (sync)
with_tmpfile (path, fd) ->
  try
    core.fs.writeFileSync(path, 'foo')
    core.fs.closeSync(fd)

    _fd = new Pathname(path).open('r', 0666)
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'

    _fd = new Pathname(path).open('r')
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'

  finally
    core.fs.close(fd)


## test opens file (async)
with_tmpfile (path, fd) ->
  core.fs.writeFileSync(path, 'foo')
  core.fs.closeSync(fd)

  new Pathname(path).open 'r', 0666, (err, _fd) ->
    assert.ifError(err)
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'
    process.on 'exit', ->
      assert.closed(_fd)

  new Pathname(path).open 'r', (err, _fd) ->
    assert.ifError(err)
    buffer = new Buffer(3)
    core.fs.readSync(_fd, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'
    process.on 'exit', ->
      assert.closed(_fd)


## test renames a path
with_tmpdir (path) ->
  path = new Pathname(path)
  curr = path.join('foo').touch()
  next = path.join('bar')

  assert.ok curr.isFile()

  actual = curr.rename(next)

  assert.equal actual.constructor, Pathname
  assert.equal actual.toString(), next.toString()
  assert.ok    actual.isFile()

  assert.ok    not curr.exists()
  assert.equal curr.toString(), path.join('foo') #ensure immutability

with_tmpdir (path) ->
  path = new Pathname(path)
  curr = path.join('foo').touch()
  next = path.join('bar')

  assert.ok curr.isFile()

  curr.rename next, (err, actual) ->
    assert.ifError(err)
    assert.equal actual.constructor, Pathname
    assert.equal actual.toString(), next.toString()
    assert.ok    actual.isFile()

    assert.ok    not curr.exists()
    assert.equal curr.toString(), path.join('foo') #ensure immutability


# test reads from a file
with_tmpfile (path) ->
  core.fs.writeFileSync(path, 'foo')

  path = new Pathname(path)
  assert.equal path.readFile().constructor, Buffer
  assert.equal path.readFile().toString(), 'foo'

with_tmpfile (path) ->
  core.fs.writeFileSync(path, 'foo')

  path = new Pathname(path)
  path.readFile (err, data) ->
    assert.ifError(err)
    assert.equal path.readFile().constructor, Buffer
    assert.equal path.readFile().toString(), 'foo'


# test writes to a file
with_tmpfile (path) ->
  path = new Pathname(path)
  path.writeFile('foo')

  assert.equal path.readFile().toString(), 'foo'

with_tmpfile (path) ->
  path = new Pathname(path)

  path.writeFile 'foo', (err) ->
    assert.ifError(err)
    assert.equal path.readFile().toString(), 'foo'


## test knows path is a file
with_tmpfile (path) ->
  assert.ok new Pathname(path).isFile()

with_tmpdir (path) ->
  assert.ok not new Pathname(path).isFile()

assert.ok not new Pathname(temp.path()).isFile()

with_tmpfile (path) ->
  new Pathname(path).isFile (err, isFile) ->
    assert.ifError(err)
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
  assert.ok new Pathname(path).isDirectory()

with_tmpfile (path) ->
  assert.ok not new Pathname(path).isDirectory()

assert.ok not new Pathname(temp.path()).isDirectory()

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
  path = new Pathname(temp.path()).touch()
  assert.ok path.exists()
  assert.ok path.isFile()
finally
  core.fs.unlinkSync(path.toString()) if path?

new Pathname(temp.path()).touch (err, path) ->
  try
    assert.ok path.exists()
    assert.ok path.isFile()
  finally
    core.fs.unlinkSync(path.toString()) if path?


## test traverses directory tree recursively
with_tmpdir (path) ->
  try
    root = new Pathname(path)
    root.join('bar'        ).touch()
    root.join('boo'        ).mkdir()
    root.join('boo/moo'    ).mkdir()
    root.join('boo/moo/zoo').touch()

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
  catch e
    up(e)
  finally
    if root?
      root.join('boo/moo/zoo').unlink()
      root.join('boo/moo'    ).rmdir()
      root.join('boo'        ).rmdir()
      root.join('bar'        ).unlink()


## deletes directory tree
with_tmpdir (path) ->
  try
    root = new Pathname(path)
    root.join('bar'        ).touch()
    root.join('boo'        ).mkdir()
    root.join('boo/moo'    ).mkdir()
    root.join('boo/moo/zoo').touch()

    ## make sure root is a tmp dir
    regexp = new RegExp("^#{RegExp.escape(temp.dir)}")
    assert.match root.realpathSync().toString(), regexp

    root.rmRSync()

    assert.ok(not root.join('boo').exists())
  catch e
    up(e)
  finally
    if root?.exists()
      root.join('boo/moo/zoo').unlink()
      root.join('boo/moo'    ).rmdir()
      root.join('boo'        ).rmdir()
      root.join('bar'        ).unlink()
      root.rmdir()


###

