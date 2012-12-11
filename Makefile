all: test

build: clean
	mkdir -p bin
	cp src/*.* bin/
	cp src/chat/* bin/
	cp src/irc/* bin/
	cp src/net/* bin/
	cp src/script/*.* bin/
	cp src/script/prepackaged/source_array.coffee bin/
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

package-scripts:
	python src/script/prepackaged/prepackage_scripts.py

package: package-scripts build
	-rm -rf package
	mkdir package
	cp -r bin package
	mkdir package/static
	mkdir package/static/icon
	cp static/icon/icon16.png package/static/icon/
	cp static/icon/icon48.png package/static/icon/
	cp static/icon/icon128.png package/static/icon/
	cp manifest.json package

pub: package
	cp manifest_public.json package/manifest.json

clean:
	-rm -rf bin

