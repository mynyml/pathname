var mods    = {};
mods.fs     = require('fs');
mods.path   = require('path');
mods.util   = require('util');

// --------------------------------------------------
// Helpers
// --------------------------------------------------
function nil(o) { return (typeof o === typeof (void 0)) || (o === null); }
function val(o) { return !nil(o); }

function flatten(array) {
    return (array.reduce(function (memo, value) {
        if (Array.isArray(value)) { var value = flatten(value); }
        return memo.concat(value);
    }, []));
}

function xcb(args) {
    for (var k = args.length; k--;) {
        if (typeof args[k] == 'function') {
            var fn = args[k];
            delete args[k];
            return fn;
        }
    }
}

// --------------------------------------------------

function Pathname(path) {
    this.path = mods.path.normalize(path.toString()).replace(/(.)\/$/,'$1');
}

// --------------------------------------------------
// Pathname Methods
// --------------------------------------------------
Pathname.prototype.toString = function toString() {
    return this.path;
};

Pathname.prototype.parent = function parent() {
    return this.dirname();
};

Pathname.prototype.touch = function touch(mode, cb) {
    cb = xcb(arguments);

    if (cb) {
        var that = this;
        this.open('w+', mode, function (err) { cb(err, that); });
    } else {
        this.open('w+', mode); this.close();
        return this;
    }
};

function _tree(path, depth, state, cb) {
    var paths   = [path];
    var divable = (!path.isSymbolicLink() && path.isDirectory() && (nil(depth) || depth > 0));

    if (cb) {
        if (divable) {
            mods.fs.readdir(path.toString(), function (err, files) {
                if (state.done) { return } // avoid calling cb more than once
                if (err) { state.done = true; cb(err); }
                else {
                    var count = files.length;
                    files.forEach(function (fname) {
                        _tree(path.join(fname), (depth && (depth - 1)), state, function (err, _paths) {
                            if (state.done) { return } // avoid calling cb more than once
                            if (err) { state.done = true; cb(err); }
                            else {
                                paths.push(_paths);
                                if (--count == 0) {
                                    cb(null, flatten(paths));
                                }
                            }
                        });
                    });
                }
            });
        } else {
            cb(null, paths);
        }
    } else {
        if (divable) {
            mods.fs.readdirSync(path.toString()).forEach(function (fname) {
                paths.push(_tree(path.join(fname), depth && (depth - 1), state));
            });
        }

        return flatten(paths);
    }
};

Pathname.prototype.tree = function tree(depth, cb) {
    cb = xcb(arguments);

    return _tree(this, depth, {done:false}, cb);
};

Pathname.prototype.rmR = function rmR(cb) {
    if (cb) {
        this.tree(function (err, tree) {
            if (err) {
                cb(err);
            } else {
                tree.reverse().forEach(function (path) {
                    if      (path.isSymbolicLink() || path.isFile()) { path.unlink(); }
                    else if (path.isDirectory())                     { path.rmdir();  }
                });
                cb(null, this);
            }
        });
    } else {
        this.tree().reverse().forEach(function (path) {
            if      (path.isSymbolicLink() || path.isFile()) { path.unlink(); }
            else if (path.isDirectory())                     { path.rmdir();  }
        });
        return this;
    }
};

Pathname.prototype.mkdirP = function mkdirP(cb) {

    function create(path) {
        path.traverse(function (path) {
            if (!path.exists()) { path.mkdir(); }
        });
        return path;
    }

    if (cb) {
        var that = this;
        process.nextTick(function () {
            // create sync, to garantee order
            try      { cb(null, create(that)); }
            catch(e) { cb(e); }
        });
    } else {
        return create(this);
    }
};

Pathname.prototype.traverse = function traverse(cb) {
    var ctor = this.constructor;
    cb(this.components()
        .map    (function (path) { return new ctor(path); })
        .reduce (function (prev, curr) { cb(prev); return prev.join(curr); }));

    return this;
};

Pathname.prototype.components = function components() {
    var elements = this.path.split('/').filter(function (e) { return e.length != 0 });
    if (this.path[0] == '/') {
        elements.unshift('/');
    }
    return elements;
};

//Pathname.prototype.children = Pathname.prototype.readdir;
Pathname.prototype.children = function children(/* args... */) {
    var args = Array.prototype.slice.call(arguments);
    return this.readdir.apply(this, args);
};

Pathname.prototype.siblings = function siblings(cb) {
    var that = this;

    if (cb) {
        this.parent().children(function (err, paths) {
            if (err) { cb(err); }
            else {
                var _paths = paths.filter(function (path) {
                    return path.toString() != that.basename().toString();
                });
                cb(null, _paths);
            }
        });
    } else {
        var paths = this.parent().children().filter(function (path) {
            return path.toString() != that.basename().toString();
        });
        return paths;
    }
};

// --------------------------------------------------
// Path Methods
// --------------------------------------------------
Pathname.prototype.join = function join(/* paths... */) {
    var paths = Array.prototype.slice.call(arguments).map(function (path) { return path.toString() });
    paths.unshift(this.toString());

    return new this.constructor(mods.path.join.apply(null, paths));
};

Pathname.prototype.dirname = function dirname() {
    return new this.constructor(mods.path.dirname(this.path));
};

Pathname.prototype.basename = function basename(ext) {
    return new this.constructor(mods.path.basename(this.path, ext));
};

Pathname.prototype.extname = function extname() {
    return mods.path.extname(this.path);
};

Pathname.prototype.exists = function exists(cb) {
    if (val(cb)) {
        mods.path.exists(this.path, cb);
    } else {
        return mods.path.existsSync(this.path);
    }
};

Pathname.prototype.stat = function stat(cb) {
    if (val(cb)) {
        mods.fs.stat(this.path, cb);
    } else {
        return mods.fs.statSync(this.path);
    }
};

Pathname.prototype.lstat = function lstat(cb) {
    if (val(cb)) {
        mods.fs.lstat(this.path, cb);
    } else {
        return mods.fs.lstatSync(this.path);
    }
};

Pathname.prototype.realpath = function realpath(cb) {
    if (val(cb)) {
        var ctor = this.constructor;
        mods.fs.realpath(this.path, function (err, resolvedPath) {
            if (val(err)) {
                cb(err, null);
            } else {
                cb(null, new ctor(resolvedPath));
            }
        });
    } else {
        return new this.constructor(mods.fs.realpathSync(this.path));
    }
};

Pathname.prototype.unlink = function unlink(cb) {
    if (val(cb)) {
        var that = this;
        mods.fs.unlink(this.path, function (err) {
            cb(err, that);
        });
    } else {
        mods.fs.unlinkSync(this.path);
        return this;
    }
};

Pathname.prototype.rmdir = function rmdir(cb) {
    if (val(cb)) {
        var that = this;
        mods.fs.rmdir(this.path, function (err) { cb(err, that); });
    } else {
        mods.fs.rmdirSync(this.path);
        return this;
    }
};

Pathname.prototype.mkdir = function mkdir(mode, cb) {
    cb = xcb(arguments);
    mode = mode || '0700';

    if (cb) {
        var that = this;
        mods.fs.mkdir(this.path, mode, function (err) { cb(err, that); });
    } else {
        mods.fs.mkdirSync(this.path, mode);
        return this;
    }
};

Pathname.prototype.open = function open(flags, mode, cb) {
    cb = xcb(arguments);
    mode = mode || '0666';

    if (cb) {
        var that = this;
        if (this.fd) {
            process.nextTick(function () { cb(null, that.fd) });
        } else {
            mods.fs.open(this.path, flags, mode, function (err, fd) {
                that.fd = fd;
                cb(err, that.fd);
            });
        }
    } else {
        if (this.fd) { return this.fd; }
        return (this.fd = mods.fs.openSync(this.path, flags, mode));
    }
};

Pathname.prototype.close = function close(cb) {
    if (cb) {
        if (this.fd) {
            var that = this;
            // NOTE: Async closing introduces a race condition, because of how
            // the fd gets reused. This construct behaves like the async
            // version interface-wise, but prevents the race condition.
            try {
                mods.fs.closeSync(this.fd);
            } catch(e) {
                process.nextTick(function () { cb(e, that); });
            }
        } else {
            cb(null, this);
        }
    } else {
        if (this.fd) {
            mods.fs.closeSync(this.fd);
            delete this.fd;
            return this;
        }
    }
};

Pathname.prototype.rename = function rename(path, cb) {
    cb = xcb(arguments);

    if (cb) {
        var ctor = this.constructor;
        mods.fs.rename(this.path, path.toString(), function (err) {
            cb(err, new ctor(path.toString()));
        });
    } else {
        mods.fs.renameSync(this.path, path.toString());
        return new this.constructor(path.toString());
    }
};

Pathname.prototype.truncate = function truncate(len, cb) {
    cb = xcb(arguments);

    if (cb) {
        var that = this;
        this.open('r+', '0666', function (err, fd) {
            if (err) { cb(err); }
            else     { mods.fs.truncate(fd, len, function (err) { cb(err, that); }); }
        });
    } else {
        mods.fs.truncateSync(this.open('r+', '0666'), len);
        return this;
    }
};

Pathname.prototype.chmod = function chmod(mode, cb) {
    cb = xcb(arguments);

    if (cb) {
        var that = this;
        mods.fs.chmod(this.path, mode, function (err) { cb(err, that); });
    } else {
        mods.fs.chmodSync(this.path, mode);
        return this;
    }
};

Pathname.prototype.readFile = function readFile(encoding, cb) {
    cb = xcb(arguments);

    if (cb) {
        mods.fs.readFile(this.path, encoding, cb);
    } else {
        return mods.fs.readFileSync(this.path, encoding);
    }
};

Pathname.prototype.writeFile = function writeFile(data, encoding, cb) {
    cb = xcb(arguments);

    if (cb) {
        var that = this;
        mods.fs.writeFile(this.path, data, encoding, function (err) { cb(err, that); });
    } else {
        mods.fs.writeFileSync(this.path, data, encoding);
        return this;
    }
};

Pathname.prototype.link = function link(dstpath, cb) {
    cb = xcb(arguments);

    if (cb) {
        var that = this;
        mods.fs.link(this.path, dstpath.toString(), function (err) { cb(err, that); });
    } else {
        mods.fs.linkSync(this.path, dstpath.toString());
        return this;
    }
};

Pathname.prototype.symlink = function symlink(dstpath, cb) {
    cb = xcb(arguments);

    if (cb) {
        var that = this;
        mods.fs.symlink(this.path, dstpath.toString(), function (err) { cb(err, that); });
    } else {
        mods.fs.symlinkSync(this.path, dstpath.toString());
        return this;
    }
};

Pathname.prototype.readlink = function readlink(cb) {
    if (cb) {
        var ctor = this.constructor;
        mods.fs.readlink(this.path, function (err, path) { cb(err, new ctor(path)); });
    } else {
        return new this.constructor(mods.fs.readlinkSync(this.path));
    }
};

Pathname.prototype.readdir = function readdir(cb) {
    if (cb) {
        var ctor = this.constructor;
        mods.fs.readdir(this.path, function (err, paths) {
            if (err) {
                cb(err);
            } else {
                cb(null, paths.map(function (path) { return new ctor(path); }));
            }
        });
    } else {
        var ctor = this.constructor;
        return mods.fs.readdirSync(this.path).map(function (path) { return new ctor(path); });
    }
};

Pathname.prototype.watchFile = function watchFile(options, listener) {
    mods.fs.watchFile(this.path, options, listener);
    return this;
};

Pathname.prototype.unwatchFile = function unwatchFile() {
    mods.fs.unwatchFile(this.path);
    return this;
};

// --------------------------------------------------
// fs.Stats functions
// --------------------------------------------------
['isFile', 'isDirectory', 'isBlockDevice', 'isCharacterDevice', 'isFIFO', 'isSocket'].forEach(function (func) {
    Pathname.prototype[func] = function (cb) {
        if (val(cb)) {
            var that = this;
            this.exists(function (exists) {
                if (exists) {
                    that.stat(function (err, stats) { cb(err, stats[func]()); });
                } else {
                    cb(null, false);
                }
            });
        } else {
            return this.exists() && this.stat()[func]();
        }
    };
    Pathname.prototype[func].name = func;
});

Pathname.prototype.isSymbolicLink = function isSymbolicLink(cb) {
    if (val(cb)) {
        this.lstat(function (err, stats) {
            if (val(err) && /^ENOENT/.test(err.message)) {
                cb(null, false);
            } else {
                cb(err, val(stats) && stats.isSymbolicLink());
            }
        });
    } else {
        try      { return this.lstat().isSymbolicLink(); }
        catch(e) { return false; }
    }
};

// --------------------------------------------------
// Exports
// --------------------------------------------------
this.Pathname = Pathname;

