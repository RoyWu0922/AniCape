.PHONY: build test clean
build:
	swift build -c release
test:
	swift run anicap-tests
clean:
	swift package clean
