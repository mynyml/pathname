Pathname
========

Summary
-------
OOP wrapper for `fs`, `path` and `Stat` functions.

Simple, clear and concise way to manipulate paths, files and directories.
Inspired by the Ruby stdlib class of the same name.


Features
--------
* Unified Sync/Async API
* Direct mapping of core nodejs functions, so that API is consistent and intuitive
* Returns `this` when possible, allowing for method chaining
* Additional convenience methods


Install
-------

    npm install pathname


Examples
--------

### Unified Sync/Async API

Pathname abstracts away the `funcname()` vs `funcnameSync()` distiction made in
core nodejs `fs` functions, and substitutes it for an intuitive equivalent;
when called with a callback, the function is async - when called without a
callback, it is synchronous.

    path = 'tmp/foo.txt' // contents: "bar"

    # async
    fs.readFile(path, function(data) {
      data // 'bar'
    })
    new Pathname(path).readFile(function (data) {
      data // 'bar'
    })

    # sync
    fs.readFileSync(path)         // 'bar'
    new Pathname(path).readFile() // 'bar'

Notice the sync version doesn't end with `Sync`.


### Direct Mapping

All functions provided by the `path`, `fs` and `Stat` modules are available on
`Pathname`, and they all take the exact same arguments, with the exception that
initial path or file descriptor arguments are always implicit.

    // path functions
    path.basename()
    path.dirname()
    path.extname()
    path.exists()
    // ...

    // Stat functions
    path.isFile()
    path.isDirectory()
    path.isSymbolicLink()
    // ...

    // fs functions
    path.readFile()
    path.writeFile(data, encoding)
    path.watchFile()
    path.link(dstpath)
    path.mkdir()
    // ...
    

### Method Chaining

Methods return `this` when no other value is expected. In async versions,
`this` is passed as second argument when `err` would otherwise be the only
expected argument. This behaviour allows for chaining of Pathname method calls.

    # sync
    new Pathname(__dirname ).parent().join('lib/my_module/version')
    new Pathname('/tmp/foo').parent().siblings()
    new Pathname('/tmp/foo').mkdir().join('bar').touch().watchFile()
    new Pathname('/tmp/foo').writeFile('bar').readFile()

    # async
    new Pathname('/tmp/foo').mkdir(function(err, path) {
      path.join('bar').touch(function(err, path) {
        path.watchFile()
      })
    })


### Additional Methods

Pathname also provides a few extra methods, which can be quite useful. See
[inline docs][1] and [examples][2] for details.

    toString(), parent(), children(), siblings(), tree(), touch(), rmR(),
    mkdirP(), traverse(), components()


Links
-----

* code:  <http://github.com/mynyml/pathname>
* docs:  <http://github.com/mynyml/pathname/blob/master/README.md>
* wiki:  <http://wiki.github.com/mynyml/pathname>
* bugs:  <http://github.com/mynyml/pathname/issues>




[1]:  https://github.com/mynyml/pathname/blob/master/src/pathname.coffee
[2]:  https://github.com/mynyml/pathname/blob/master/examples.coffee

