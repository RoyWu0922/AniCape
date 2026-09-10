.PHONY: build test clean gui app
build:
	swift build -c release
test:
	swift run anicap-tests
gui:
	swift run anicap-gui
app:
	bash Tools/make_app.sh
clean:
	swift package clean
