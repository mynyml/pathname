Pathname
========
OOP wrapper for `fs`, `path` and `Stat` functions.

This document describes the api. See README.md for overview and usage.

* Pathnames are immutable

Core Node Functions
-------------------


Pathname-specific Methods
-------------------------
Pathname also provides a few extra methods, which can be quite useful.

### toString()
String representation of `path` object

    new Pathname('/tmp/foo').toString()
    #=> '/tmp/foo'

### parent()
Parent directory of `path`

    new Pathname('/tmp/foo').parent().toString()
    #=> '/tmp'

### children()
All paths (files and directories) one level below `path` in the fs tree. `path`
must be a directory.

    # given: '/tmp/foo', '/tmp/bar'

    new Pathname('/tmp').children()
    #=> [Pathname('/tmp/foo'), Pathname('/tmp/bar')]

### siblings()
All paths (files and directories) in the same directory level as `path`,
excluding `path`

    # given: '/tmp/foo', '/tmp/bar', '/tmp/baz'

    new Pathname('/tmp/foo').siblings()
    #=> [Pathname('/tmp/bar'), Pathname('/tmp/baz')]

### tree()
Entire fs tree below (and including) `path`

    # given: '/tmp/foo', '/tmp/bar', '/tmp/bar/baz'

    new Pathname('/tmp').tree()
    #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/bar'), Pathname('/tmp/bar/baz')]

### touch()
Create a file at `path`

    path = new Pathname('/tmp/foo')

    path.exists()
    # false

    path.touch()

    path.exists() and path.isFile()
    # true

### rmR()
Recursively remove directory at `path` and it's contents (whole directory tree below it).

    path = new Pathname('/tmp')

    path.tree()
    #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/bar'), Pathname('/tmp/bar/baz')]

    path.rmR()

    path.tree()
    #=> [Pathname('/tmp')]

    path.exists()
    # false

    # NOTE: Pathname objects need not correspond to an existing file on the fs,
    # so it's correct that path.tree() above includes the current object.

### mkdirP()
Create a multilevel path

    path = new Pathname('/tmp/foo/bar')

    path.exists()
    # false

    path.parent().exists()
    # false

    path.mkdirP()

    path.exists() and path.isDirectory()
    # true

### traverse()
Iterates over every component of `path`

    path  = new Pathname('/tmp/foo/bar')
    parts = []

    path.traverse(function(part) { parts.push(part) })
    parts #=> [Pathname('/tmp'), Pathname('/tmp/foo'), Pathname('/tmp/foo/bar')]
    
### components()
Component parts of `path`

    new Pathname('/tmp/foo/bar').components()
    #=> ['/', 'tmp', 'foo', 'bar']

