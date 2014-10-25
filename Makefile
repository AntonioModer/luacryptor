all: twofish_c_code.lua test_ctr.exe twofish.so

twofish-cpy/tables.h: twofish-cpy/makeCtables.py
	python $< > $@

twofish_lib.c: twofish-cpy/tables.h twofish-cpy/opt2.c
	cat twofish-cpy/tables.h > $@
	cat twofish-cpy/opt2.c | sed -e '/TESTING FUNCTIONS/,$$d' \
		>> $@
	echo '*/' >> $@

sha256_lib.c: sha256/sha256.h sha256/sha256.c
	cat sha256/sha256.h > $@
	cat sha256/sha256.c | sed -e '/ifdef TEST/,$$d' >> $@

twofish_and_sha256.c: twofish_lib.c sha256_lib.c
	cat $^ | sed -e 's/^u/static u/' \
		-e 's/^void/static void/' \
		-e 's/^inline/static/' > $@

twofish.c: twofish_and_sha256.c lua_bindings.c
	cat $^ > $@

twofish.so: twofish.c
	gcc -shared -fpic -I /usr/include/lua5.1/ \
		$^ -o $@ -llua5.1

twofish_c_code.lua: twofish.c
	echo 'return [===[' > $@
	cat $< >> $@
	echo ']===]' >> $@

test_ctr.exe: test_ctr.c twofish.c
	gcc -I /usr/include/lua5.1/ $< -o $@ -llua5.1

test: test_ctr.exe
	./test_ctr.exe

.PHONY: all

