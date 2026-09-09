.PHONY: build test clean
build:
	swift build -c release
test:
	swift test
clean:
	swift package clean
