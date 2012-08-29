build:
	mkdir -p bin
	-cp src/*.* bin/
	coffee -c bin/*.coffee
	cp third_party/* bin/
	rm bin/*.coffee

all: build
