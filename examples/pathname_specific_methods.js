
var Pathname = require('pathname')

/*
/tmp
|-- foo/
    |-- bar
    |-- baz/
        |-- boo
        |-- moo
        |-- zoo
*/

path = new Pathname('/tmp/foo')

console.log( path.toString() )
console.log( path.parent()   )
console.log( path.children() )
console.log( path.siblings() )
console.log( path.tree()     )

console.log( path.join('bar').components()                       )
console.log( path.join('bar').traverse(function (path) { path }) )

path.join('quux/bax').mkdirP()
path.join('file.txt').touch()

path.rmR()

