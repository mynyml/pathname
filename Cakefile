
shell = (cmd) ->
  require('child_process').exec cmd, (err, stdout, stderr) ->
    throw err if err?
    console.log(stdout)   if stdout? and stdout isnt ""
    console.error(stderr) if stderr? and stderr isnt ""

task 'docs', "Compile man pages", ->
  shell 'mkdir -p doc/man'
  shell 'ronn --pipe --roff --date=`date +%Y-%m-%d` --manual=Pathname --organization="Martin Aumont (mynyml)" doc/pathname.md > doc/man/pathname.1'

task 'build', "Compile source", ->
  shell 'coffee -o lib/ -cb src/pathname.coffee'

task 'install', "Install package locally", ->
  invoke 'docs'
  invoke 'build'
  shell 'npm install'

task 'publish', "Build, install and publish package", ->
  invoke 'install'
  shell 'npm publish'

