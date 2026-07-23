.PHONY: build app install run clean

build:
	swift build

app:
	sh scripts/build-app.sh

install: app
	sh scripts/install-app.sh

run: app
	open "dist/Simple Screenshot.app"

clean:
	swift package clean
	rm -rf dist
