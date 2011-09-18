
.PHONY: all test docs install

all : test

test :
	node test/pathname-test.js

docs :
	mkdir -p doc/man
	ronn --pipe --roff --date=`date +%Y-%m-%d` --manual=Pathname --organization="Martin Aumont (mynyml)" doc/pathname.md > doc/man/pathname.1

install : docs
	npm install

publish : install
	npm publish

