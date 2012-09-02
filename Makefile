build:
	mkdir -p bin
	cp src/*.* bin/
	cp src/chat/* bin/
	cp src/irc/* bin/
	cp src/net/* bin/
	cp third_party/* bin/
	coffee -c bin/*.coffee
	rm bin/*.coffee

tester:
	mkdir -p bin
	cp test/mock_chrome_api/*.* bin/
	coffee -c bin/*.coffee
	rm bin/*.coffee

clean:
	-rm -rf bin

all: build
