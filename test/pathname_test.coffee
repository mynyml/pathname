mods =
  fs:   require('fs')
  sys:  require('sys')
  path: require('path')
  util: require('util')

# dev utils
global.puts    = mods.sys.puts
global.inspect = mods.util.inspect
global.l       = console.log
global.d       = (x) -> console.log("DEBUG: " + inspect x)

_        = require('underscore')
assert   = require('assert')
temp     = require('temp')
Pathname = require('../src/pathname').Pathname

process._events ?= {}
process.setMaxListeners(60)

# --------------------------------------------------
# Helpers
# --------------------------------------------------
with_tmpdir = with_tmpdirs = (cb) ->
  paths = []
  count = cb.length
  for i in [1..count]
    temp.mkdir "Pathname-", (err, dirPath) ->
      assert.ifError(err)
      paths.push(dirPath)
      cb(paths...) if --count is 0

with_tmpfile = (cb) ->
  temp.open "Pathname-", (err, info) ->
    assert.ifError(err)
    cb(info.path, info.fd)

assert.include = (enumerable, value, message) ->
  message ?= "Expected '#{inspect(enumerable)}' to include '#{inspect(value)}'"
  assert.ok((enumerable.some (item) -> _.isEqual(item, value)), message)

assert.closed = (fd) ->
  assert.throws (-> mods.fs.readSync(fd, new Buffer(1), 0, 1, 0)), Error, "fd '#{fd}' is open, expected it to be closed"

assert.open = (fd) ->
  assert.doesNotThrow (-> mods.fs.readSync(fd, new Buffer(1), 0, 1, 0)), Error, "fd '#{fd}' is closed, expected it to be open"

assert.match = (actual, expected) ->
  assert.ok expected.test(actual), "Expected #{expected} to match #{actual}"

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
  assert.equal new Pathname(path).stat().ino, mods.fs.statSync(path).ino

with_tmpdir (path) ->
  new Pathname(path).stat (err, info) ->
    assert.ifError(err)
    assert.equal info.ino, mods.fs.statSync(path).ino


## test expands path
with_tmpdir (path) ->
  root = new Pathname(path)
  root.join('foo').touch()

  cwd = process.cwd()
  try
    process.chdir(path)
    assert.equal new Pathname('foo').realpath().constructor, Pathname
    assert.equal new Pathname('foo').realpath().toString(), root.join('foo').toString()
  catch e
    up(e)
  finally
    process.chdir(cwd)


## test removes a file
with_tmpfile (path) ->
  path = new Pathname(path)
  path.unlink (err, unlinkedPath) ->
    assert.ifError(err)
    assert.ok not path.exists()
    assert.ok not path.isFile()

    assert.equal unlinkedPath.constructor, Pathname
    assert.equal unlinkedPath.toString(), path.toString()

with_tmpfile (path) ->
  path = new Pathname(path)
  unlinkedPath = path.unlink()
  assert.ok not path.exists()
  assert.ok not path.isFile()

  assert.equal unlinkedPath.constructor, Pathname
  assert.equal unlinkedPath.toString(), path.toString()


## test removes empty directory
with_tmpdir (path) ->
  path = new Pathname(path)
  path.rmdir (err, unlinkedPath) ->
    assert.ifError(err)
    assert.ok not path.exists()
    assert.ok not path.isDirectory()

    assert.equal unlinkedPath.constructor, Pathname
    assert.equal unlinkedPath.toString(), path.toString()

with_tmpdir (path) ->
  path = new Pathname(path)
  unlinkedPath = path.rmdir()
  assert.ok not path.exists()
  assert.ok not path.isDirectory()

  assert.equal unlinkedPath.constructor, Pathname
  assert.equal unlinkedPath.toString(), path.toString()


## test creates directory
process.nextTick ->
  try
    path = new Pathname(temp.path()).mkdir()
    assert.ok path.exists()
    assert.ok path.isDirectory()
    assert.equal path.stat().mode.toString(8), '40700'
  finally
    mods.fs.rmdirSync(path.toString()) if path?

new Pathname(temp.path()).mkdir undefined, (err, path) ->
  try
    assert.ifError(err)
    assert.ok path.exists()
    assert.ok path.isDirectory()
    assert.equal path.stat().mode.toString(8), '40700'
  catch e
    up(e)
  finally
    mods.fs.rmdirSync(path.toString()) if path?

new Pathname(temp.path()).mkdir (err, path) ->
  try
    assert.ifError(err)
    assert.ok path.exists()
    assert.ok path.isDirectory()
    assert.equal path.stat().mode.toString(8), '40700'
  catch e
    up(e)
  finally
    mods.fs.rmdirSync(path.toString()) if path?


## test opens file (sync)
with_tmpfile (path, fd) ->
  try
    mods.fs.writeFileSync(path, 'foo')
    mods.fs.closeSync(fd)

    path = new Pathname(path)

    _fd1 = path.open('r', 0666)
    mods.fs.readSync(_fd1, buffer = new Buffer(3), 0, 3, 0)
    assert.equal buffer.toString(), 'foo'

    _fd2 = path.open('r')
    mods.fs.readSync(_fd2, buffer = new Buffer(3), 0, 3, 0)
    assert.equal buffer.toString(), 'foo'

    assert.equal _fd1, _fd2

  finally
    mods.fs.closeSync(_fd1)


## test opens file (async)
with_tmpfile (path, fd) ->
  mods.fs.writeFileSync(path, 'foo')
  mods.fs.closeSync(fd)

  path = new Pathname(path)
  _fd1 = null
  _fd2 = null

  process.on 'exit', -> assert.equal _fd1, _fd2

  path.open 'r', 0666, (err, _fd1) ->
    assert.ifError(err)
    buffer = new Buffer(3)
    mods.fs.readSync(_fd1, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'
    process.on 'exit', -> mods.fs.closeSync(_fd1)

  path.open 'r', (err, _fd2) ->
    assert.ifError(err)
    buffer = new Buffer(3)
    mods.fs.readSync(_fd2, buffer, 0, 3, 0)
    assert.equal buffer.toString(), 'foo'
    process.on 'exit', -> mods.fs.closeSync(_fd2)


## test closes a file
with_tmpdir (dir) ->
  path = new Pathname(dir).join('foo')

  path.open('w+')
  assert.open(path.fd)

  path.close()
  assert.closed(path.fd)

with_tmpdir (dir) ->
  path = new Pathname(dir).join('foo')

  path.open('w+')
  assert.open(path.fd)

  path.close (err) ->
    assert.ifError(err)
    assert.closed(path.fd)


## test closing a file is a noop when file is already closed
with_tmpdir (dir) ->
  path = new Pathname(dir).join('foo')

  fd = path.open('w+')
  assert.open(fd)

  path.close()
  assert.closed(fd)

  assert.doesNotThrow (-> path.close()), /Bad file descriptor/


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


## test truncates a file
with_tmpfile (path) ->
  path = new Pathname(path)

  path.writeFile('foobar')
  truncatedPath = path.truncate(3)

  assert.equal path.readFile().toString(), 'foo'

  assert.equal truncatedPath.constructor, Pathname
  assert.equal truncatedPath.toString(), path.toString()

with_tmpfile (path) ->
  path = new Pathname(path)

  path.writeFile('foobar')
  path.truncate 3, (err, truncatedPath) ->
    assert.ifError(err)
    assert.equal path.readFile().toString(), 'foo'

    assert.equal truncatedPath.constructor, Pathname
    assert.equal truncatedPath.toString(), path.toString()


## test changes file mode
with_tmpdir (dir) ->
  path = new Pathname(dir).join('foo')
  path.open 'w+', 0644, (err, fd) ->
    assert.equal path.stat().mode.toString(8), '100644'
    chmodedPath = path.chmod(0622)
    assert.equal path.stat().mode.toString(8), '100622'

    assert.equal chmodedPath.constructor, Pathname
    assert.equal chmodedPath.toString(), path.toString()

with_tmpdir (dir) ->
  path = new Pathname(dir).join('bar')
  path.open 'w+', 0644, (err, fd) ->
    assert.equal path.stat().mode.toString(8), '100644'
    path.chmod 0622, (err, chmodedPath) ->
      assert.ifError(err)
      assert.equal path.stat().mode.toString(8), '100622'

      assert.equal chmodedPath.constructor, Pathname
      assert.equal chmodedPath.toString(), path.toString()


## test reads from a file
with_tmpfile (path) ->
  mods.fs.writeFileSync(path, 'foo')

  path = new Pathname(path)
  assert.equal path.readFile().constructor, Buffer
  assert.equal path.readFile().toString(), 'foo'

with_tmpfile (path) ->
  mods.fs.writeFileSync(path, 'foo')

  path = new Pathname(path)
  path.readFile (err, data) ->
    assert.ifError(err)
    assert.equal path.readFile().constructor, Buffer
    assert.equal path.readFile().toString(), 'foo'


## test writes to a file
with_tmpfile (path) ->
  path = new Pathname(path)
  writtenPath = path.writeFile('foo')

  assert.equal path.readFile().toString(), 'foo'
  assert.equal writtenPath.constructor, Pathname
  assert.equal writtenPath.toString(), path.toString()

with_tmpfile (path) ->
  path = new Pathname(path)

  path.writeFile 'foo', (err, writtenPath) ->
    assert.ifError(err)
    assert.equal path.readFile().toString(), 'foo'
    assert.equal writtenPath.constructor, Pathname
    assert.equal writtenPath.toString(), path.toString()


## test creates hard link
with_tmpdir (path) ->
  path1 = new Pathname(path).join('foo')
  path2 = new Pathname(path).join('bar').touch().link(path1)

  path2.writeFile('data')
  assert.equal path1.readFile(), 'data'

  path2.unlink()
  assert.equal path1.readFile(), 'data'

with_tmpdir (path) ->
  path1 = new Pathname(path).join('foo')
  new Pathname(path).join('bar').touch().link path1, (err, path2) ->
    assert.ifError(err)

    path2.writeFile('data')
    assert.equal path1.readFile(), 'data'

    path2.unlink()
    assert.equal path1.readFile(), 'data'


## test creates symlink
with_tmpdir (path) ->
  path1 = new Pathname(path).join('foo')
  path2 = new Pathname(path).join('bar').touch().symlink(path1)

  path2.writeFile('data')
  assert.equal path1.readFile(), 'data'

  path2.unlink()
  assert.throws((-> path1.readFile()), Error)

with_tmpdir (path) ->
  path1 = new Pathname(path).join('foo')
  new Pathname(path).join('bar').touch().symlink path1, (err, path2) ->
    assert.ifError(err)

    path2.writeFile('data')
    assert.equal path1.readFile(), 'data'

    path2.unlink()
    assert.throws((-> path1.readFile()), Error)


## test reads symlink path
with_tmpdir (path) ->
  path1 = new Pathname(path).join('foo')
  path2 = new Pathname(path).join('bar').touch().symlink(path1)

  assert.equal path1.readlink().constructor, Pathname
  assert.equal path1.readlink().toString(), path2.toString()

with_tmpdir (path) ->
  path1 = new Pathname(path).join('foo')
  path2 = new Pathname(path).join('bar').touch().symlink(path1)

  path1.readlink (err, resolvedPath) ->
    assert.equal resolvedPath.constructor, Pathname
    assert.equal resolvedPath.toString(), path2.toString()


## test watches and unwatches a file
with_tmpfile (path) ->
  called = no

  path = new Pathname(path)
  watchedPath = path.watchFile {interval: 100}, (curr, prev) ->
    assert.ok curr.mtime >= prev.mtime
    called = yes
    unwatchedPath = path.unwatchFile()
    assert.equal unwatchedPath.constructor, Pathname
    assert.equal unwatchedPath.toString(), path.toString()

  assert.equal watchedPath.constructor, Pathname
  assert.equal watchedPath.toString(), path.toString()

  path.writeFile 'foo', (err) ->
    setTimeout((->
      assert.ok called, "file listener wasn't called"
    ), 200)

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


## test knows path is a symlink
with_tmpdir (dir) ->
  path1 = new Pathname(dir).join('foo')
  path2 = new Pathname(dir).join('bar').touch().symlink(path1)

  assert.ok     path1.isFile()
  assert.ok     path2.isFile()
  assert.ok     path1.isSymbolicLink()
  assert.ok not path2.isSymbolicLink()


## test finds parent directory
assert.deepEqual new Pathname('/tmp/foo/bar.txt').parent(), new Pathname('/tmp/foo')
assert.deepEqual new Pathname('/tmp/foo/bar'    ).parent(), new Pathname('/tmp/foo')


## test creates file
process.nextTick ->
  try
    path = new Pathname(temp.path()).touch()
    assert.ok path.exists()
    assert.ok path.isFile()
  finally
    mods.fs.unlinkSync(path.toString()) if path?

new Pathname(temp.path()).touch (err, path) ->
  try
    assert.ok path.exists()
    assert.ok path.isFile()
  finally
    mods.fs.unlinkSync(path.toString()) if path?

process.nextTick ->
  try
    path = new Pathname(temp.path()).touch(0744)
    assert.equal path.stat().mode.toString(8), '100744'
  finally
    mods.fs.unlinkSync(path.toString()) if path?


## test traverses directory tree recursively
with_tmpdir (path) ->
  try
    root = new Pathname(path)
    root.join('bar'        ).touch()
    root.join('boo'        ).mkdir()
    root.join('boo/moo'    ).mkdir()
    root.join('boo/moo/zoo').touch()

    assert.ok root.tree().every (path) -> path.constructor is Pathname

    tree = root.tree(0)
    assert.equal   tree.length, 1
    assert.include tree, root

    assert.equal root.tree(-1).length, tree.length

    tree = root.tree(1)
    assert.equal   tree.length, 3
    assert.include tree, root
    assert.include tree, root.join('bar')
    assert.include tree, root.join('boo')

    tree = root.tree(2)
    assert.equal   tree.length, 4
    assert.include tree, root
    assert.include tree, root.join('bar')
    assert.include tree, root.join('boo')
    assert.include tree, root.join('boo/moo')

    tree = root.tree(3)
    assert.equal   tree.length, 5
    assert.include tree, root
    assert.include tree, root.join('bar')
    assert.include tree, root.join('boo')
    assert.include tree, root.join('boo/moo')
    assert.include tree, root.join('boo/moo/zoo')

    assert.equal root.tree(undefined).length, tree.length
    assert.equal root.tree(null     ).length, tree.length
  catch e
    up(e)
  finally
    if root?
      root.join('boo/moo/zoo').unlink()
      root.join('boo/moo'    ).rmdir()
      root.join('boo'        ).rmdir()
      root.join('bar'        ).unlink()

with_tmpdir (path) ->
  root = new Pathname(path)
  root.join('bar'        ).touch()
  root.join('boo'        ).mkdir()
  root.join('boo/moo'    ).mkdir()
  root.join('boo/moo/zoo').touch()

  root.tree (err, files) ->
    assert.ifError(err)
    assert.ok files.every (path) -> path.constructor is Pathname

  root.tree 0, (err, files) ->
    assert.ifError(err)
    assert.equal   files.length, 1
    assert.include files, root

    root.tree -1, (err, files2) ->
      assert.ifError(err)
      assert.equal files2.length, files.length

  root.tree 1, (err, files) ->
    assert.equal   files.length, 3
    assert.include files, root
    assert.include files, root.join('bar')
    assert.include files, root.join('boo')

  root.tree 2, (err, files) ->
    assert.equal   files.length, 4
    assert.include files, root
    assert.include files, root.join('bar')
    assert.include files, root.join('boo')
    assert.include files, root.join('boo/moo')

  root.tree 3, (err, files) ->
    assert.equal   files.length, 5
    assert.include files, root
    assert.include files, root.join('bar')
    assert.include files, root.join('boo')
    assert.include files, root.join('boo/moo')
    assert.include files, root.join('boo/moo/zoo')

    root.tree undefined, (err, files2) -> assert.equal files2.length, files.length
    root.tree null,      (err, files2) -> assert.equal files2.length, files.length
    root.tree            (err, files2) -> assert.equal files2.length, files.length


## deletes directory tree
with_tmpdir (path) ->
  try
    root = new Pathname(path)
    root.join('bar'        ).touch()
    root.join('boo'        ).mkdir().symlink(root.join('baz'))
    root.join('boo/moo'    ).mkdir()
    root.join('boo/moo/zoo').touch()

    ## make sure root is a tmp dir
    regexp = new RegExp("^#{RegExp.escape(temp.dir)}")
    assert.match root.realpath().toString(), regexp

    removedPath = root.rmR()

    assert.ok(not root.join('boo').exists())
    assert.equal removedPath.constructor, Pathname
    assert.equal removedPath.toString(), root.toString()
  catch e
    up(e)
  finally
    if root?.exists()
      root.join('boo/moo/zoo').unlink()
      root.join('boo/moo'    ).rmdir()
      root.join('boo'        ).rmdir()
      root.join('baz'        ).unlink()
      root.join('bar'        ).unlink()
      root.rmdir()

with_tmpdir (path) ->
  root = new Pathname(path)
  root.join('bar'        ).touch()
  root.join('boo'        ).mkdir().symlink(root.join('baz'))
  root.join('boo/moo'    ).mkdir()
  root.join('boo/moo/zoo').touch()

  ## make sure root is a tmp dir
  regexp = new RegExp("^#{RegExp.escape(temp.dir)}")
  assert.match root.realpath().toString(), regexp

  assert.throws (-> root.rmdir()), /ENOTEMPTY/
  root.rmR (err, removedPath) ->
    assert.ifError(err)
    assert.ok(not root.join('boo').exists())

    assert.equal removedPath.constructor, Pathname
    assert.equal removedPath.toString(), root.toString()


## test reads directory contents
with_tmpdir (path) ->
  try
    root = new Pathname(path)
    root.join('bar'    ).touch()
    root.join('boo'    ).mkdir()
    root.join('boo/moo').touch()

    assert.ok      root.readdir().every (path) -> path.constructor is Pathname
    assert.equal   root.readdir().length, 2
    assert.include root.readdir(), root.join('bar').basename()
    assert.include root.readdir(), root.join('boo').basename()
  catch e
    up(e)
  finally
    root.rmR() if root?.exists()

with_tmpdir (path) ->
  root = new Pathname(path)
  root.join('bar'    ).touch()
  root.join('boo'    ).mkdir()
  root.join('boo/moo').touch()

  root.readdir (err, files) ->
    assert.ok      files.every (path) -> path.constructor is Pathname
    assert.equal   files.length, 2
    assert.include files, root.join('bar').basename()
    assert.include files, root.join('boo').basename()


## test children
with_tmpdir (path) ->
  root = new Pathname(path)
  root.join('bar'        ).touch()
  root.join('boo'        ).mkdir()
  root.join('boo/moo'    ).touch()

  root.children (err, files) ->
    assert.ifError(err)
    assert.equal files.length, 2
    assert.include files, root.join('bar')
    assert.include files, root.join('boo')

    files[1].children (err, files2) ->
      assert.ifError(err)
      assert.equal files2.length, 1
      assert.include files2, root.join('boo/moo')


  children = root.children()
  assert.equal children.length, 2
  assert.include children, root.join('bar')
  assert.include children, root.join('boo')

  children2 = children[1].children();
  assert.equal children2.length, 1
  assert.include children2, root.join('boo/moo')



## test creates many levels of directories
with_tmpdir (path) ->
  root = new Pathname(path)
  assert.ok not root.join('foo').isDirectory()

  newpath = root.join('foo/bar/baz').mkdirP()
  assert.ok root.join('foo/bar/baz').isDirectory()

  assert.equal newpath.constructor, Pathname
  assert.equal newpath.toString(), root.join('foo/bar/baz').toString()

with_tmpdir (path) ->
  root = new Pathname(path)
  assert.ok not root.join('foo').isDirectory()

  root.join('foo/bar/baz').mkdirP (err, createdPath) ->
    assert.ifError(err)
    assert.ok root.join('foo/bar/baz').isDirectory()

    assert.equal createdPath.constructor, Pathname
    assert.equal createdPath.toString(), root.join('foo/bar/baz').toString()


## test retrieves paths in same directory
with_tmpdir (path) ->
  root = new Pathname(path)
  root.join('foo').mkdir()
  root.join('bar').mkdir()
  root.join('baz').mkdir()

  assert.equal   root.join('foo').siblings().length, 2
  assert.include root.join('foo').siblings(), root.join('bar')
  assert.include root.join('foo').siblings(), root.join('baz')

with_tmpdir (path) ->
  root = new Pathname(path)
  root.join('foo').mkdir()
  root.join('bar').mkdir()
  root.join('baz').mkdir()

  root.join('foo').siblings (err, paths) ->
    assert.equal   paths.length, 2
    assert.include paths, root.join('bar')
    assert.include paths, root.join('baz')


###

