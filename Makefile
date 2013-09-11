SRC_FILES     := $(shell find coffee/lib  -name '*.coffee' | sed -e :a -e '$$!N;s/\n/ /;ta')
TEST_FILES    := $(shell find coffee/test -name '*.test.*' | sed -e :a -e '$$!N;s/\n/ /;ta')
JS_SRC_FILES  := $(shell find js/lib  -name '*.js' | sed -e :a -e '$$!N;s/\n/ /;ta')
JS_TEST_FILES := $(shell find js/test -name '*.test.*' | sed -e :a -e '$$!N;s/\n/ /;ta')

clean:
	@rm -fr js/

js: clean
	./node_modules/.bin/coffee -c -o ./js ./coffee

run: js
	node ./js/lib/proxy.js
