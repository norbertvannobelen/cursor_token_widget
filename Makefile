.PHONY: build test install clean

build:
	./scripts/build.sh

test:
	./scripts/test.sh

install: build
	./scripts/install.sh

clean:
	rm -rf build
