PATHNAME
========
OOP wrapper for `fs`, `path` and `Stat` functions. This document describes the api. See README.md for overview and usage.


NOTES
-----
* Pathname objects are immutable. Methods that manipulate the paths will return new path object(s).
* Pathname objects need not correspond to an existing file on disk


CORE NODE FUNCTIONS
-------------------
All functions provided by the `path`, `fs` and `Stat` modules are available on
`Pathname`, and they all take the exact same arguments, with the exception that
an initial path or file descriptor argument is always implicit.


PATHNAME-SPECIFIC METHODS
-------------------------
Pathname also provides a few extra methods, which can be quite useful.

### toString()
String representation of `path` object

    new Pathname('/tmp/foo').toString()
    #=> '/tmp/foo'

### parent()
Parent directory of `path`

    new Pathname('/tmp/foo').parent()
    #=> Pathname('/tmp') #i.e. Pathname object for path '/tmp'

### children(cb)
All paths (files and directories) one level below `path` in the fs tree. `path`
must be a directory.

    # given: '/tmp/foo', '/tmp/bar'

    new Pathname('/tmp').children()
    #=> [Pathname('/tmp/foo'), Pathname('/tmp/bar')]

async:

    new Pathname('/tmp').children(function(paths) {
      paths #=> [Pathname('/tmp/foo'), Pathname('/tmp/bar')]
    })

### siblings(cb)
All paths (files and directories) in the same directory level as `path`,
excluding `path`

    # given: '/tmp/foo', '/tmp/bar', '/tmp/baz'

    new Pathname('/tmp/foo').siblings()
    #=> [Pathname('/tmp/bar'), Pathname('/tmp/baz')]

async:

    new Pathname('/tmp/foo').siblings(function(paths) {
      paths #=> [Pathname('/tmp/bar'), Pathname('/tmp/baz')]
    })

### tree(cb)
Entire fs tree below (and including) `path`

    # given: '/tmp/foo', '/tmp/bar', '/tmp/bar/baz'

    new Pathname('/tmp').tree()
    #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/bar'), Pathname('/tmp/bar/baz')]

async:

    new Pathname('/tmp').tree(function(paths) {
      paths
      #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/bar'), Pathname('/tmp/bar/baz')]
    })

### touch(mode, cb)
Create a file at `path`

    path = new Pathname('/tmp/foo')

    path.exists()                  #=> false
    path.touch()                   #=> path
    path.exists() && path.isFile() #=> true

async:

    path = new Pathname('/tmp/foo')
    path.exists() #=> false

    path.touch(function(path) {
      path.exists() && path.isFile()
      #=> true
    })

### rmR(cb)
Recursively remove directory at `path` and it's contents (whole directory tree below it).

    path = new Pathname('/tmp')

    path.tree()
    #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/bar'), Pathname('/tmp/bar/baz')]

    path.rmR()    #=> path
    path.tree()   #=> [Pathname('/tmp')]
    path.exists() #=> false

async:

    path = new Pathname('/tmp')

    path.tree()
    #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/bar'), Pathname('/tmp/bar/baz')]

    path.rmR(function(path) {
      path.tree()     #=> [Pathname('/tmp')]
      path.exists()   #=> false
    })

### mkdirP(cb)
Create a multilevel path

    path = new Pathname('/tmp/foo/bar')

    path.exists()                       #=> false
    path.parent().exists()              #=> false
    path.mkdirP()                       #=> path
    path.exists() && path.isDirectory() #=> true

async:

    path = new Pathname('/tmp/foo/bar')

    path.exists()          #=> false
    path.parent().exists() #=> false

    path.mkdirP(function(path) {
      path.exists() && path.isDirectory()
      #=> true
    })

### traverse(cb)
Iterates over every component of `path`

    path  = new Pathname('/tmp/foo/bar')
    parts = []

    path.traverse(function(part) { parts.push(part) })
    parts #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/foo/bar')]
    
### components()
Component parts of `path`

    new Pathname('/tmp/foo/bar').components()
    #=> ['/', 'tmp', 'foo', 'bar']

