var mods  = {};
mods.fs   = require('fs');
mods.sys  = require('sys');
mods.path = require('path');
mods.util = require('util');

var _        = require('underscore');
var vows     = require('vows');
var assert   = require('assert');
var temp     = require('temp');
var Pathname = require('../lib/pathname').Pathname;

process._events = process._events || {};
process.setMaxListeners(60);

// --------------------------------------------------
// Helpers
// --------------------------------------------------
function nil(o) { return (typeof o === typeof (void 0)) || (o === null); }
function val(o) { return !nil(o); }

function withTmpdir(cb) {
    temp.mkdir('Pathname-', function (err, dirPath) {
        assert.ifError(err);
        cb(dirPath);
    });
}

function withTmpfile(cb) {
    temp.open('Pathname-', function (err, info) {
        assert.ifError(err);
        cb(info.path, info.fd);
    });
}

assert.include = function (enum, val, msg) {
    msg = msg || "Expected "+ mods.util.inspect(enum) +" to include '"+ mods.util.inspect(val) +"'";
    assert.ok(enum.some(function (x) { return _.isEqual(x, val); }), msg);
};

assert.closed = function (fd) {
    function testf() {
        mods.fs.readSync(fd, new Buffer(1), 0, 1, 0);
    }
    assert.throws(testf, Error, "fd '"+ fd +"' is closed, expected it to be open");
};

assert.open = function (fd) {
    function testf() {
        mods.fs.readSync(fd, new Buffer(1), 0, 1, 0);
    }
    assert.doesNotThrow(testf, Error, "fd '"+ fd +"' is closed, expected it to be open");
};

assert.match = function (actual, expected) {
    assert.ok(expected.test(actual), "Expected "+ expected +" to match "+ actual);
};

// source: http://efreedom.com/Question/1-3561493/RegExpescape-Function-Javascript
// author: bobince
RegExp.escape = function (exp) {
    return exp.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
};

function up(e) {
    console.log(e.stack);
    if (val(e.message)) { console.log(e.message); }
    throw e;
}

// --------------------------------------------------
// Tests
// --------------------------------------------------

// test object wraps path
assert.equal(new Pathname('/tmp/foo').toString(), '/tmp/foo');


// test normalizes path on creation
assert.equal(new Pathname('/tmp/foo'        ).toString(), '/tmp/foo');
assert.equal(new Pathname('/tmp/foo/bar/../').toString(), '/tmp/foo');


// test joining paths
assert.equal(new Pathname('/tmp/foo' ).join('bar' ).constructor, Pathname);
assert.equal(new Pathname('/tmp/foo' ).join('bar' ).toString(),  '/tmp/foo/bar');
assert.equal(new Pathname('/tmp/foo' ).join('bar/').toString(),  '/tmp/foo/bar');
assert.equal(new Pathname('/tmp/foo' ).join('/bar').toString(),  '/tmp/foo/bar');
assert.equal(new Pathname('/tmp/foo/').join('/bar').toString(),  '/tmp/foo/bar');
assert.equal(new Pathname('/tmp/foo/').join('bar', 'baz').toString(), '/tmp/foo/bar/baz');


// test extracts dirname
assert.equal(new Pathname('/tmp/foo/bar.txt').dirname().constructor, Pathname);
assert.equal(new Pathname('/tmp/foo/bar.txt').dirname().toString(), '/tmp/foo');
assert.equal(new Pathname('/tmp/foo/bar'    ).dirname().toString(), '/tmp/foo');


// test extracts basename
assert.equal(new Pathname('/tmp/foo'    ).basename().constructor, Pathname);
assert.equal(new Pathname('/tmp/foo'    ).basename().toString(), 'foo');
assert.equal(new Pathname('/tmp/foo.ext').basename().toString(), 'foo.ext');


// testextracts extention
assert.equal(new Pathname('/tmp/foo'        ).extname(), '');
assert.equal(new Pathname('/tmp/foo.ext'    ).extname(), '.ext');
assert.equal(new Pathname('/tmp/foo.txt.ext').extname(), '.ext');


// test knows dir exists
withTmpdir(function (path) {
    assert.ok(new Pathname(path).exists())
});
withTmpdir(function (path) {
    new Pathname(path).exists(function (exists) { assert.ok(exists); });
});


// test knows file exists
withTmpdir(function (path) {
    assert.ok(new Pathname(path).exists());
});
withTmpdir(function (path) {
    new Pathname(path).exists(function (exists) { assert.ok(exists); });
});


// test knows path doesn't exist
assert.ok(! new Pathname(temp.path()).exists());

withTmpdir(function (path) {
    new Pathname(path).join('foo').exists(function (exists) {
        assert.ok(! exists);
    });
});


// test queries stats
withTmpdir(function (path) {
    assert.equal(new Pathname(path).stat().ino, mods.fs.statSync(path).ino);
});
withTmpdir(function (path) {
    new Pathname(path).stat(function (err, info) {
        assert.ifError(err);
        assert.equal(info.ino, mods.fs.statSync(path).ino);
    });
});


// test expands path
withTmpdir(function (path) {
    var root = new Pathname(path);
    var cwd  = process.cwd();

    root.join('foo').touch();
    try {
        process.chdir(path);
        assert.equal(new Pathname('foo').realpath().constructor, Pathname);
        assert.equal(new Pathname('foo').realpath().toString(), root.join('foo').toString());
    } catch(e) {
        up(e);
    } finally {
        process.chdir(cwd);
    }
});


// test removes a file
withTmpfile(function (path) {
    var path = new Pathname(path);
    path.unlink(function (err, unlinkedPath) {
        assert.ifError(err);
        assert.ok(! path.exists());
        assert.ok(! path.isFile());

        assert.equal(unlinkedPath.constructor, Pathname);
        assert.equal(unlinkedPath.toString(), path.toString());
    });
});
withTmpfile(function (path) {
    var path = new Pathname(path);
    var unlinkedPath = path.unlink();

    assert.ok(! path.exists());
    assert.ok(! path.isFile());

    assert.equal(unlinkedPath.constructor, Pathname);
    assert.equal(unlinkedPath.toString(), path.toString());
});


// test removes empty directory
withTmpdir(function (path) {
    var path = new Pathname(path);
    path.rmdir(function (err, unlinkedPath) {
        assert.ifError(err);
        assert.ok(! path.exists());
        assert.ok(! path.isDirectory());

        assert.equal(unlinkedPath.constructor, Pathname);
        assert.equal(unlinkedPath.toString(), path.toString());
    });
});
withTmpdir(function (path) {
    var path = new Pathname(path);
    var unlinkedPath = path.rmdir();

    assert.ok(! path.exists());
    assert.ok(! path.isDirectory());

    assert.equal(unlinkedPath.constructor, Pathname);
    assert.equal(unlinkedPath.toString(), path.toString());
});


// test creates directory
process.nextTick(function () {
    try {
        var path = new Pathname(temp.path()).mkdir();
        assert.ok(path.exists());
        assert.ok(path.isDirectory());
        assert.equal(path.stat().mode.toString(8), '40700');
    } catch(e) {
        up(e);
    } finally {
        if (val(path)) {
            mods.fs.rmdirSync(path.toString());
        }
    }
});

new Pathname(temp.path()).mkdir(undefined, function (err, path) {
    try {
        assert.ifError(err);
        assert.ok(path.exists());
        assert.ok(path.isDirectory());
        assert.equal(path.stat().mode.toString(8), '40700');
    } catch(e) {
        up(e);
    } finally {
        if (val(path)) {
            mods.fs.rmdirSync(path.toString());
        }
    }
});

new Pathname(temp.path()).mkdir(function (err, path) {
    try {
        assert.ifError(err);
        assert.ok(path.exists());
        assert.ok(path.isDirectory());
        assert.equal(path.stat().mode.toString(8), '40700');
    } catch(e) {
        up(e);
    } finally {
        if (val(path)) {
            mods.fs.rmdirSync(path.toString());
        }
    }
});


// test opens file (sync)
withTmpfile(function (path, fd) {
    try {
        mods.fs.writeFileSync(path, 'foo');
        mods.fs.closeSync(fd);

        var path = new Pathname(path);

        var _fd1 = path.open('r', 0666);
        mods.fs.readSync(_fd1, buffer = new Buffer(3), 0, 3, 0);
        assert.equal(buffer.toString(), 'foo');

        var _fd2 = path.open('r');
        mods.fs.readSync(_fd2, buffer = new Buffer(3), 0, 3, 0);
        assert.equal(buffer.toString(), 'foo');

        assert.equal(_fd1, _fd2);
    } finally {
        mods.fs.closeSync(_fd1);
    }
});


// test opens file (async)
withTmpfile(function (path, fd) {
    mods.fs.writeFileSync(path, 'foo');
    mods.fs.closeSync(fd);

    var path = new Pathname(path);
    var _fd1 = null;
    var _fd2 = null;

    process.on('exist', function () {
        assert.equal(_fd1, _fd2);
    });

    path.open('r', 0666, function (err, _fd1) {
        assert.ifError(err);
        var buffer = new Buffer(3);
        mods.fs.readSync(_fd1, buffer, 0, 3, 0);
        assert.equal(buffer.toString(), 'foo');
        process.on('exit', function () {
            mods.fs.closeSync(_fd1);
        });
    });

    path.open('r', function (err, _fd2) {
        assert.ifError(err);
        var buffer = new Buffer(3);
        mods.fs.readSync(_fd2, buffer, 0, 3, 0);
        assert.equal(buffer.toString(), 'foo');
        process.on('exit', function () {
            mods.fs.closeSync(_fd2);
        });
    });
});


// test closes a file
withTmpdir(function (dir) {
    var path = new Pathname(dir).join('foo');

    path.open('w+');
    assert.open(path.fd);

    path.close();
    assert.closed(path.fd);
});
withTmpdir(function (dir) {
    var path = new Pathname(dir).join('foo');

    path.open('w+');
    assert.open(path.fd);

    path.close(function (err) {
        assert.ifError(err);
        assert.closed(path.fd);
    });
});


// test closing a file is a noop when file is already closed
withTmpdir(function (dir) {
    var path = new Pathname(dir).join('foo');

    var fd = path.open('w+');
    assert.open(fd);

    path.close();
    assert.closed(fd);

    assert.doesNotThrow(function () { path.close(); }, /Bad file descriptor/);
});


// test renames a path
withTmpdir(function (path) {
    var path = new Pathname(path);
    var curr = path.join('foo').touch();
    var next = path.join('bar');

    assert.ok(curr.isFile());

    actual = curr.rename(next);

    assert.equal(actual.constructor, Pathname);
    assert.equal(actual.toString(), next.toString());
    assert.ok   (actual.isFile());

    assert.ok   (! curr.exists());
    assert.equal(curr.toString(), path.join('foo')); //ensure immutability
});

withTmpdir(function (path) {
    var path = new Pathname(path);
    var curr = path.join('foo').touch();
    var next = path.join('bar');

    assert.ok(curr.isFile());

    curr.rename(next, function (err, actual) {
        assert.ifError(err);
        assert.equal(actual.constructor, Pathname);
        assert.equal(actual.toString(), next.toString());
        assert.ok   (actual.isFile());

        assert.ok   (! curr.exists());
        assert.equal(curr.toString(), path.join('foo')) //ensure immutability
    });
});


// test truncates a file
withTmpfile(function (path) {
    var path = new Pathname(path);
    var truncatedPath;

    path.writeFile('foobar');
    truncatedPath = path.truncate(3);

    assert.equal(path.readFile().toString(), 'foo');

    assert.equal(truncatedPath.constructor, Pathname);
    assert.equal(truncatedPath.toString(), path.toString());
});

withTmpfile(function (path) {
    var path = new Pathname(path);

    path.writeFile('foobar');
    path.truncate(3, function (err, truncatedPath) {
        assert.ifError(err);
        assert.equal(path.readFile().toString(), 'foo');

        assert.equal(truncatedPath.constructor, Pathname);
        assert.equal(truncatedPath.toString(), path.toString());
    });
});


// test changes file mode
withTmpdir(function (dir) {
    var path = new Pathname(dir).join('foo');
    path.open('w+', 0644, function (err, fd) {
        var chmodedPath;

        assert.equal(path.stat().mode.toString(8), '100644');
        chmodedPath = path.chmod(0622);
        assert.equal(path.stat().mode.toString(8), '100622');

        assert.equal(chmodedPath.constructor, Pathname);
        assert.equal(chmodedPath.toString(), path.toString());
    });
});

withTmpdir(function (dir) {
    var path = new Pathname(dir).join('bar');
    path.open('w+', 0644, function (err, fd) {
        assert.equal(path.stat().mode.toString(8), '100644');
        path.chmod(0622, function (err, chmodedPath) {
            assert.ifError(err);
            assert.equal(path.stat().mode.toString(8), '100622');

            assert.equal(chmodedPath.constructor, Pathname);
            assert.equal(chmodedPath.toString(), path.toString());
        });
    });
});


// test reads from a file
withTmpfile(function (path) {
    mods.fs.writeFileSync(path, 'foo');

    var path = new Pathname(path);
    assert.equal(path.readFile().constructor, Buffer);
    assert.equal(path.readFile().toString(), 'foo');
});

withTmpfile(function (path) {
    mods.fs.writeFileSync(path, 'foo');

    var path = new Pathname(path);
    path.readFile(function (err, data) {
        assert.ifError(err);
        assert.equal(path.readFile().constructor, Buffer);
        assert.equal(path.readFile().toString(), 'foo');
    });
});


// test writes to a file
withTmpfile(function (path) {
    var path = new Pathname(path);
    var writtenPath = path.writeFile('foo');

    assert.equal(path.readFile().toString(), 'foo');
    assert.equal(writtenPath.constructor, Pathname);
    assert.equal(writtenPath.toString(), path.toString());
});
withTmpfile(function (path) {
    var path = new Pathname(path);

    path.writeFile('foo', function (err, writtenPath) {
        assert.ifError(err);
        assert.equal(path.readFile().toString(), 'foo');
        assert.equal(writtenPath.constructor, Pathname);
        assert.equal(writtenPath.toString(), path.toString());
    });
});


// test creates hard link
withTmpdir(function (path) {
    var path1 = new Pathname(path).join('foo');
    var path2 = new Pathname(path).join('bar').touch().link(path1);

    path2.writeFile('data');
    assert.equal(path1.readFile(), 'data');

    path2.unlink();
    assert.equal(path1.readFile(), 'data');
});

withTmpdir(function (path) {
    var path1 = new Pathname(path).join('foo');
    new Pathname(path).join('bar').touch().link(path1, function (err, path2) {
        assert.ifError(err);

        path2.writeFile('data');
        assert.equal(path1.readFile(), 'data');

        path2.unlink();
        assert.equal(path1.readFile(), 'data');
    });
});


// test creates symlink
withTmpdir(function (path) {
    var path1 = new Pathname(path).join('foo');
    var path2 = new Pathname(path).join('bar').touch().symlink(path1);

    path2.writeFile('data');
    assert.equal(path1.readFile(), 'data');

    path2.unlink();
    assert.throws(function () { path1.readFile(); }, Error);
});

withTmpdir(function (path) {
    var path1 = new Pathname(path).join('foo');
    new Pathname(path).join('bar').touch().symlink(path1, function (err, path2) {
        assert.ifError(err);

        path2.writeFile('data');
        assert.equal(path1.readFile(), 'data');

        path2.unlink();
        assert.throws(function () { path1.readFile(); }, Error);
    });
});


// test reads symlink path
withTmpdir(function (path) {
    var path1 = new Pathname(path).join('foo');
    var path2 = new Pathname(path).join('bar').touch().symlink(path1);

    assert.equal(path1.readlink().constructor, Pathname);
    assert.equal(path1.readlink().toString(), path2.toString());
});

withTmpdir(function (path) {
    var path1 = new Pathname(path).join('foo');
    var path2 = new Pathname(path).join('bar').touch().symlink(path1);

    path1.readlink(function (err, resolvedPath) {
        assert.equal(resolvedPath.constructor, Pathname);
        assert.equal(resolvedPath.toString(), path2.toString());
    });
});


// test watches and unwatches a file
withTmpfile(function (path) {
    var called = false;
    var path = new Pathname(path);
    var watchedPath = path.watchFile({}, function (curr, prev) {
        assert.ok(curr.mtime >= prev.mtime);
        called = true;
        unwatchedPath = path.unwatchFile();
        assert.equal(unwatchedPath.constructor, Pathname);
        assert.equal(unwatchedPath.toString(), path.toString());
    });
    assert.equal(watchedPath.constructor, Pathname);
    assert.equal(watchedPath.toString(), path.toString());

    path.writeFile('foo');
    setTimeout(function () { assert.ok(called, "file listener wasn't called"); }, 0);
});


// test knows path is a file
withTmpfile(function (path) {
    assert.ok(new Pathname(path).isFile());
});
withTmpdir(function (path) {
    assert.ok(! new Pathname(path).isFile());
});
assert.ok(! new Pathname(temp.path()).isFile());

withTmpfile(function (path) {
    new Pathname(path).isFile(function (err, isFile) {
        assert.ifError(err);
        assert.ok(isFile);
    });
});

withTmpdir(function (path) {
    new Pathname(path).isFile(function (err, isFile) {
        assert.ifError(err);
        assert.ok(! isFile);
    });
});

new Pathname(temp.path()).isFile(function (err, isFile) {
    assert.ifError(err);
    assert.ok(! isFile);
});


// test knows path is a dir
withTmpdir(function (path) {
    assert.ok(new Pathname(path).isDirectory());
});
withTmpfile(function (path) {
    assert.ok(! new Pathname(path).isDirectory());
});
assert.ok(! new Pathname(temp.path()).isDirectory());

withTmpdir(function (path) {
    new Pathname(path).isDirectory(function (err, isDirectory) {
        assert.ifError(err);
        assert.ok(isDirectory);
    });
});

withTmpfile(function (path) {
    new Pathname(path).isDirectory(function (err, isDirectory) {
        assert.ifError(err);
        assert.ok(! isDirectory);
    });
});

new Pathname(temp.path()).isDirectory(function (err, isDirectory) {
    assert.ifError(err);
    assert.ok(! isDirectory);
});


// test knows path is a symlink
withTmpdir(function (dir) {
    var path1 = new Pathname(dir).join('foo');
    var path2 = new Pathname(dir).join('bar').touch().symlink(path1);

    assert.ok(  path1.isFile());
    assert.ok(  path2.isFile());
    assert.ok(  path1.isSymbolicLink());
    assert.ok(! path2.isSymbolicLink());
});


// test finds parent directory
assert.deepEqual(new Pathname('/tmp/foo/bar.txt').parent(), new Pathname('/tmp/foo'));
assert.deepEqual(new Pathname('/tmp/foo/bar'    ).parent(), new Pathname('/tmp/foo'));


// test creates file
process.nextTick(function () {
    try {
        var path = new Pathname(temp.path()).touch();
        assert.ok(path.exists());
        assert.ok(path.isFile());
    } finally {
        if (val(path)) {
            mods.fs.unlinkSync(path.toString());
        }
    }
});

new Pathname(temp.path()).touch(function (err, path) {
    try {
        assert.ok(path.exists());
        assert.ok(path.isFile());
    } finally {
        if (val(path)) {
            mods.fs.unlinkSync(path.toString());
        }
    }
});

process.nextTick(function () {
    try {
        var path = new Pathname(temp.path()).touch(0744);
        assert.equal(path.stat().mode.toString(8), '100744');
    } finally {
        if (val(path)) {
            mods.fs.unlinkSync(path.toString());
        }
    }
});


// test traverses directory tree recursively
withTmpdir(function (path) {
    try {
        var root = new Pathname(path);
        var tree;

        root.join('bar'        ).touch();
        root.join('boo'        ).mkdir();
        root.join('boo/moo'    ).mkdir();
        root.join('boo/moo/zoo').touch();

        assert.ok(root.tree().every(function (path) {
            return path.constructor.name == 'Pathname';
        }));

        tree = root.tree(0);
        assert.equal  (tree.length, 1);
        assert.include(tree, root);

        assert.equal  (root.tree(-1).length, tree.length);

        tree = root.tree(1);
        assert.equal  (tree.length, 3);
        assert.include(tree, root);
        assert.include(tree, root.join('bar'));
        assert.include(tree, root.join('boo'));

        tree = root.tree(2);
        assert.equal  (tree.length, 4);
        assert.include(tree, root);
        assert.include(tree, root.join('bar'));
        assert.include(tree, root.join('boo'));
        assert.include(tree, root.join('boo/moo'));

        tree = root.tree(3);
        assert.equal  (tree.length, 5);
        assert.include(tree, root);
        assert.include(tree, root.join('bar'));
        assert.include(tree, root.join('boo'));
        assert.include(tree, root.join('boo/moo'));
        assert.include(tree, root.join('boo/moo/zoo'));

        assert.equal(root.tree(undefined).length, tree.length);
        assert.equal(root.tree(null     ).length, tree.length);

    } catch(e) {
        up(e);
    } finally {
        if (val(root)) {
            root.join('boo/moo/zoo').unlink();
            root.join('boo/moo'    ).rmdir();
            root.join('boo'        ).rmdir();
            root.join('bar'        ).unlink();
        }
    }
});

withTmpdir(function (path) {
    var root = new Pathname(path);
    root.join('bar'        ).touch();
    root.join('boo'        ).mkdir();
    root.join('boo/moo'    ).mkdir();
    root.join('boo/moo/zoo').touch();

    root.tree(function (err, files) {
        assert.ifError(err);
        assert.ok(files.every(function (path) { return path.constructor.name == 'Pathname'; }));
    });

    root.tree(0, function (err, files) {
        assert.ifError(err);
        assert.equal  (files.length, 1);
        assert.include(files, root);

        root.tree(-1, function (err, files2) {
            assert.ifError(err);
            assert.equal(files2.length, files.length);
        });
    });

    root.tree(1, function (err, files) {
        assert.equal  (files.length, 3);
        assert.include(files, root);
        assert.include(files, root.join('bar'));
        assert.include(files, root.join('boo'));
    });

    root.tree(2, function (err, files) {
        assert.equal  (files.length, 4);
        assert.include(files, root);
        assert.include(files, root.join('bar'));
        assert.include(files, root.join('boo'));
        assert.include(files, root.join('boo/moo'));
    });

    root.tree(3, function (err, files) {
        assert.equal  (files.length, 5);
        assert.include(files, root);
        assert.include(files, root.join('bar'));
        assert.include(files, root.join('boo'));
        assert.include(files, root.join('boo/moo'));
        assert.include(files, root.join('boo/moo/zoo'));

        root.tree(undefined, function (err, files2) { assert.equal(files2.length, files.length); });
        root.tree(null,      function (err, files2) { assert.equal(files2.length, files.length); });
        root.tree(           function (err, files2) { assert.equal(files2.length, files.length); });
    });
});


// deletes directory tree
withTmpdir(function (path) {
    try {
        var root = new Pathname(path);
        root.join('bar'        ).touch();
        root.join('boo'        ).mkdir().symlink(root.join('baz'));
        root.join('boo/moo'    ).mkdir();
        root.join('boo/moo/zoo').touch();

        // make sure root is a tmp dir
        var regexp = new RegExp('^'+RegExp.escape(temp.dir));
        assert.match(root.realpath().toString(), regexp);

        var removedPath = root.rmR();

        assert.ok(! root.join('boo').exists());
        assert.equal(removedPath.constructor, Pathname);
        assert.equal(removedPath.toString(), root.toString());

    } catch(e) {
        up(e);
    } finally {
        if (val(root) && root.exists()) {
            root.join('boo/moo/zoo').unlink();
            root.join('boo/moo'    ).rmdir();
            root.join('boo'        ).rmdir();
            root.join('baz'        ).unlink();
            root.join('bar'        ).unlink();
            root.mkdir();
        }
    }
});

withTmpdir(function (path) {
    var root = new Pathname(path);
    root.join('bar'        ).touch();
    root.join('boo'        ).mkdir().symlink(root.join('baz'));
    root.join('boo/moo'    ).mkdir();
    root.join('boo/moo/zoo').touch;

    // make sure root is a tmp dir
    var regexp = new RegExp('^'+RegExp.escape(temp.dir));
    assert.match(root.realpath().toString(), regexp);

    assert.throws(function () { root.rmdir(); }, /ENOTEMPTY/);
    root.rmR(function (err, removedPath) {
        assert.ifError(err);
        assert.ok(! root.join('boo').exists());

        assert.equal(removedPath.constructor, Pathname);
        assert.equal(removedPath.toString(), root.toString());
    });
});


// test reads directory contents
withTmpdir(function (path) {
    try {
        var root = new Pathname(path);
        root.join('bar'    ).touch();
        root.join('boo'    ).mkdir();
        root.join('boo/moo').touch();

        assert.ok      (root.readdir().every(function (path) { return path.constructor == Pathname; }));
        assert.equal   (root.readdir().length, 2);
        assert.include (root.readdir(), root.join('bar').basename());
        assert.include (root.readdir(), root.join('boo').basename());
    } catch(e) {
        up(e);
    } finally {
        if (val(root) && root.exists()) {
            root.rmR();
        }
    }
});

withTmpdir(function (path) {
    var root = new Pathname(path);
    root.join('bar'    ).touch();
    root.join('boo'    ).mkdir();
    root.join('boo/moo').touch();

    root.readdir(function (err, files) {
        assert.ok      (files.every(function (path) { return path.constructor == Pathname; }));
        assert.equal   (files.length, 2);
        assert.include (files, root.join('bar').basename());
        assert.include (files, root.join('boo').basename());
    });
});


// test creates many levels of directories
withTmpdir(function (path) {
    var root = new Pathname(path);
    assert.ok(! root.join('foo').isDirectory());

    var newpath = root.join('foo/bar/baz').mkdirP();
    assert.ok(root.join('foo/bar/baz').isDirectory());

    assert.equal(newpath.constructor, Pathname);
    assert.equal(newpath.toString(), root.join('foo/bar/baz').toString());
});

withTmpdir(function (path) {
    var root = new Pathname(path);
    assert.ok(! root.join('foo').isDirectory());

    root.join('foo/bar/baz').mkdirP(function (err, createdPath) {
        assert.ifError(err);
        assert.ok(root.join('foo/bar/baz').isDirectory());

        assert.equal(createdPath.constructor, Pathname);
        assert.equal(createdPath.toString(), root.join('foo/bar/baz').toString());
    });
});


// test retrieves paths in same directory
withTmpdir(function (path) {
    var root = new Pathname(path);
    root.join('foo').mkdir();
    root.join('bar').mkdir();
    root.join('baz').mkdir();

    assert.equal  (root.join('foo').siblings().length, 2);
    assert.include(root.join('foo').siblings(), root.join('bar').basename());
    assert.include(root.join('foo').siblings(), root.join('baz').basename());
});

withTmpdir(function (path) {
    var root = new Pathname(path);
    root.join('foo').mkdir();
    root.join('bar').mkdir();
    root.join('baz').mkdir();

    root.join('foo').siblings(function (err, paths) {
        assert.equal   (paths.length, 2);
        assert.include (paths, root.join('bar').basename());
        assert.include (paths, root.join('baz').basename());
    });
});

