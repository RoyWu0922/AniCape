.PHONY: build test clean gui app
build:
	swift build -c release
test:
	swift run AniCapeTests
gui:
	swift run AniCapeGUI
app:
	bash Tools/make_app.sh
clean:
	swift package clean
