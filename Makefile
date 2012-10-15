all: test

build: clean
	mkdir -p bin
	cp src/*.* bin/
	cp src/chat/* bin/
	cp src/irc/* bin/
	cp src/net/* bin/
	cp src/script/* bin/
	cp third_party/*.js bin/
	cp -r static/font bin/
	coffee -c bin/*.coffee
	rm bin/*.coffee

test: build
	mkdir -p bin
	cp test/*.* bin/
	cp test/mocks/* bin/
	cp -r third_party/jasmine-1.2.0 bin/
	coffee -c bin/*.coffee
	rm bin/*.coffee

package: build
	-rm -rf package
	mkdir package
	cp -r bin package
	cp -r static package
	cp manifest.json package

clean:
	-rm -rf bin

