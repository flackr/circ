build:
	mkdir -p bin
	cp src/*.* bin/
	cp src/chat/* bin/
	cp src/irc/* bin/
	cp third_party/* bin/
	coffee -c bin/*.coffee
	rm bin/*.coffee

clean:
	-rm -rf bin

all: build
