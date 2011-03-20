
shell = (cmd) ->
  require('child_process').exec cmd, (args...) ->
    console.log msg for msg in args when arg? and arg isnt ""

task 'docs', "Compile man pages", (options) ->
  shell 'ronn --pipe --roff --date=`date +%Y-%m-%d` --manual=Pathname --organization="Martin Aumont (mynyml)" README.md > doc/man/pathname.1'

