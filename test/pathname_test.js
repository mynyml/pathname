(function() {
  var Pathname, assert, core, path, temp, up, with_tmpdir, with_tmpfile, _;
  core = {
    fs: require('fs'),
    sys: require('sys'),
    path: require('path'),
    util: require('util')
  };
  global.puts = core.sys.puts;
  global.inspect = core.util.inspect;
  global.l = console.log;
  global.d = function(x) {
    return console.log("DEBUG: " + inspect(x));
  };
  _ = require('underscore');
  assert = require('assert');
  temp = require('temp');
  Pathname = require('../src/index');
  process._events = {};
  process.setMaxListeners(50);
  with_tmpdir = function(cb) {
    return temp.mkdir("Pathname-", function(err, dirPath) {
      assert.ifError(err);
      return cb(dirPath);
    });
  };
  with_tmpfile = function(cb) {
    return temp.open("Pathname-", function(err, info) {
      assert.ifError(err);
      return cb(info.path, info.fd);
    });
  };
  assert.include = function(enumerable, value, message) {
    message != null ? message : message = "Expected '" + (inspect(enumerable)) + "' to include '" + (inspect(value)) + "'";
    return assert.ok(enumerable.some(function(item) {
      return _.isEqual(item, value);
    }), message);
  };
  assert.closed = function(fd) {
    return assert.throws((function() {
      return core.fs.readSync(fd, new Buffer(1), 0, 1, 0);
    }), Error, "fd '" + fd + "' is open, expected it to be closed");
  };
  assert.open = function(fd) {
    return assert.doesNotThrow((function() {
      return core.fs.readSync(fd, new Buffer(1), 0, 1, 0);
    }), Error, "fd '" + fd + "' is closed, expected it to be open");
  };
  assert.match = function(actual, expected) {
    return assert.ok(expected.test(actual), "Expected " + expected + " to match " + actual);
  };
  RegExp.escape = function(exp) {
    return exp.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
  };
  up = function(e) {
    console.log(e.stack);
    if (e.message != null) {
      console.log(e.message);
    }
    throw e;
  };
  assert.equal(new Pathname('/tmp/foo').toString(), '/tmp/foo');
  assert.equal(new Pathname('/tmp/foo/').toString(), '/tmp/foo');
  assert.equal(new Pathname('/tmp/foo/bar/../').toString(), '/tmp/foo');
  assert.equal(new Pathname("/tmp/foo").join("bar").constructor, Pathname);
  assert.equal(new Pathname("/tmp/foo").join("bar").toString(), "/tmp/foo/bar");
  assert.equal(new Pathname("/tmp/foo").join("bar/").toString(), "/tmp/foo/bar");
  assert.equal(new Pathname("/tmp/foo").join("/bar").toString(), "/tmp/foo/bar");
  assert.equal(new Pathname("/tmp/foo/").join("/bar").toString(), "/tmp/foo/bar");
  assert.equal(new Pathname("/tmp/foo/").join("bar", "baz").toString(), "/tmp/foo/bar/baz");
  assert.equal(new Pathname('/tmp/foo/bar.txt').dirname().constructor, Pathname);
  assert.equal(new Pathname('/tmp/foo').basename(), 'foo');
  assert.equal(new Pathname('/tmp/foo.ext').basename(), 'foo.ext');
  assert.equal(new Pathname('/tmp/foo').extname(), '');
  assert.equal(new Pathname('/tmp/foo.ext').extname(), '.ext');
  assert.equal(new Pathname('/tmp/foo.txt.ext').extname(), '.ext');
  with_tmpdir(function(path) {
    return assert.ok(new Pathname(path).exists());
  });
  with_tmpdir(function(path) {
    return new Pathname(path).exists(function(exists) {
      return assert.ok(exists);
    });
  });
  with_tmpfile(function(path) {
    return assert.ok(new Pathname(path).exists());
  });
  with_tmpfile(function(path) {
    return new Pathname(path).exists(function(exists) {
      return assert.ok(exists);
    });
  });
  assert.ok(!new Pathname(temp.path()).exists());
  with_tmpdir(function(path) {
    return assert.equal(new Pathname(path).stat().ino, core.fs.statSync(path).ino);
  });
  with_tmpdir(function(path) {
    return new Pathname(path).stat(function(err, info) {
      assert.ifError(err);
      return assert.equal(info.ino, core.fs.statSync(path).ino);
    });
  });
  with_tmpfile(function(path) {
    path = new Pathname(path);
    return path.unlink(function(err) {
      assert.ifError(err);
      assert.ok(!path.exists());
      return assert.ok(!path.isFile());
    });
  });
  with_tmpfile(function(path) {
    path = new Pathname(path);
    path.unlink();
    assert.ok(!path.exists());
    return assert.ok(!path.isFile());
  });
  with_tmpdir(function(path) {
    path = new Pathname(path);
    return path.rmdir(function(err) {
      assert.ifError(err);
      assert.ok(!path.exists());
      return assert.ok(!path.isDirectory());
    });
  });
  with_tmpdir(function(path) {
    path = new Pathname(path);
    path.rmdir();
    assert.ok(!path.exists());
    return assert.ok(!path.isDirectory());
  });
  try {
    path = new Pathname(temp.path()).mkdir();
    assert.ok(path.exists());
    assert.ok(path.isDirectory());
  } finally {
    if (path != null) {
      core.fs.rmdirSync(path.toString());
    }
  }
  new Pathname(temp.path()).mkdir(void 0, function(err, path) {
    try {
      assert.ifError(err);
      assert.ok(path.exists());
      return assert.ok(path.isDirectory());
    } finally {
      if (path != null) {
        core.fs.rmdirSync(path.toString());
      }
    }
  });
  new Pathname(temp.path()).mkdir(function(err, path) {
    try {
      assert.ifError(err);
      assert.ok(path.exists());
      return assert.ok(path.isDirectory());
    } finally {
      if (path != null) {
        core.fs.rmdirSync(path.toString());
      }
    }
  });
  with_tmpfile(function(path, fd) {
    var buffer, _fd;
    try {
      core.fs.writeFileSync(path, 'foo');
      core.fs.closeSync(fd);
      _fd = new Pathname(path).open('r', 0666);
      buffer = new Buffer(3);
      core.fs.readSync(_fd, buffer, 0, 3, 0);
      assert.equal(buffer.toString(), 'foo');
      _fd = new Pathname(path).open('r');
      buffer = new Buffer(3);
      core.fs.readSync(_fd, buffer, 0, 3, 0);
      return assert.equal(buffer.toString(), 'foo');
    } finally {
      core.fs.close(fd);
    }
  });
  with_tmpfile(function(path, fd) {
    core.fs.writeFileSync(path, 'foo');
    core.fs.closeSync(fd);
    new Pathname(path).open('r', 0666, function(err, _fd) {
      var buffer;
      assert.ifError(err);
      buffer = new Buffer(3);
      core.fs.readSync(_fd, buffer, 0, 3, 0);
      assert.equal(buffer.toString(), 'foo');
      return process.on('exit', function() {
        return assert.closed(_fd);
      });
    });
    return new Pathname(path).open('r', function(err, _fd) {
      var buffer;
      assert.ifError(err);
      buffer = new Buffer(3);
      core.fs.readSync(_fd, buffer, 0, 3, 0);
      assert.equal(buffer.toString(), 'foo');
      return process.on('exit', function() {
        return assert.closed(_fd);
      });
    });
  });
  with_tmpfile(function(path) {
    return assert.ok(new Pathname(path).isFile());
  });
  with_tmpdir(function(path) {
    return assert.ok(!new Pathname(path).isFile());
  });
  assert.ok(!new Pathname(temp.path()).isFile());
  with_tmpfile(function(path) {
    return new Pathname(path).isFile(function(err, isFile) {
      assert.ifError(err);
      return assert.ok(isFile);
    });
  });
  with_tmpdir(function(path) {
    return new Pathname(path).isFile(function(err, isFile) {
      assert.ifError(err);
      return assert.ok(!isFile);
    });
  });
  new Pathname(temp.path()).isFile(function(err, isFile) {
    assert.ifError(err);
    return assert.ok(!isFile);
  });
  with_tmpdir(function(path) {
    return assert.ok(new Pathname(path).isDirectory());
  });
  with_tmpfile(function(path) {
    return assert.ok(!new Pathname(path).isDirectory());
  });
  assert.ok(!new Pathname(temp.path()).isDirectory());
  with_tmpdir(function(path) {
    return new Pathname(path).isDirectory(function(err, isDirectory) {
      assert.ifError(err);
      return assert.ok(isDirectory);
    });
  });
  with_tmpfile(function(path) {
    return new Pathname(path).isDirectory(function(err, isDirectory) {
      assert.ifError(err);
      return assert.ok(!isDirectory);
    });
  });
  new Pathname(temp.path()).isDirectory(function(err, isDirectory) {
    assert.ifError(err);
    return assert.ok(!isDirectory);
  });
  assert.deepEqual(new Pathname('/tmp/foo/bar.txt').parent(), new Pathname('/tmp/foo'));
  assert.deepEqual(new Pathname('/tmp/foo/bar').parent(), new Pathname('/tmp/foo'));
  try {
    path = new Pathname(temp.path()).touch();
    assert.ok(path.exists());
    assert.ok(path.isFile());
  } finally {
    if (path != null) {
      core.fs.unlinkSync(path.toString());
    }
  }
  new Pathname(temp.path()).touch(function(err, path) {
    try {
      assert.ok(path.exists());
      return assert.ok(path.isFile());
    } finally {
      if (path != null) {
        core.fs.unlinkSync(path.toString());
      }
    }
  });
  with_tmpdir(function(path) {
    var root, tree;
    try {
      root = new Pathname(path);
      root.join('bar').touch();
      root.join('boo').mkdir();
      root.join('boo/moo').mkdir();
      root.join('boo/moo/zoo').touch();
      assert.ok(root.treeSync().every(function(path) {
        return path.constructor === Pathname;
      }));
      tree = root.treeSync(0);
      assert.equal(tree.length, 1);
      assert.include(tree, root);
      assert.equal(root.treeSync(-1).length, tree.length);
      tree = root.treeSync(1);
      assert.equal(tree.length, 3);
      assert.include(tree, root);
      assert.include(tree, root.join('bar'));
      assert.include(tree, root.join('boo'));
      tree = root.treeSync(2);
      assert.equal(tree.length, 4);
      assert.include(tree, root);
      assert.include(tree, root.join('bar'));
      assert.include(tree, root.join('boo'));
      assert.include(tree, root.join('boo/moo'));
      tree = root.treeSync(3);
      assert.equal(tree.length, 5);
      assert.include(tree, root);
      assert.include(tree, root.join('bar'));
      assert.include(tree, root.join('boo'));
      assert.include(tree, root.join('boo/moo'));
      assert.include(tree, root.join('boo/moo/zoo'));
      assert.equal(root.treeSync(void 0).length, tree.length);
      return assert.equal(root.treeSync(null).length, tree.length);
    } catch (e) {
      return up(e);
    } finally {
      if (root != null) {
        root.join('boo/moo/zoo').unlink();
        root.join('boo/moo').rmdir();
        root.join('boo').rmdir();
        root.join('bar').unlink();
      }
    }
  });
  with_tmpdir(function(path) {
    var regexp, root;
    try {
      root = new Pathname(path);
      root.join('bar').touch();
      root.join('boo').mkdir();
      root.join('boo/moo').mkdir();
      root.join('boo/moo/zoo').touch();
      regexp = new RegExp("^" + (RegExp.escape(temp.dir)));
      assert.match(root.realpathSync().toString(), regexp);
      root.rmRSync();
      return assert.ok(!root.join('boo').exists());
    } catch (e) {
      return up(e);
    } finally {
      if (root != null ? root.exists() : void 0) {
        root.join('boo/moo/zoo').unlink();
        root.join('boo/moo').rmdir();
        root.join('boo').rmdir();
        root.join('bar').unlink();
        root.rmdir();
      }
    }
  });
}).call(this);
