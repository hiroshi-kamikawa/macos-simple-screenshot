.PHONY: build app run clean

build:
	swift build

app:
	sh scripts/build-app.sh

run: app
	open "dist/Simple Screenshot.app"

clean:
	swift package clean
	rm -rf dist
