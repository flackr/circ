build:
	mkdir -p bin
	-cp src/*.* bin/
	coffee -c bin/*.coffee
	rm bin/*.coffee

clean:
	-rm -r bin/

all: build
