# git init config
# cd config
#
# git submodule add https://github.com/hilbix/gen.git
# git submodule update --init
# 
# ln -s gen/Makefile .
#
# ln gen/example.org .
# make
#
# cp example.org example.net
# vim example.net
# make

GEN=gen/gen.sh

.PHONY:	love
love:	all

.PHONY:	all
all:	gen

.PHONY:	gen
gen:
	@[ -f '$(GEN)' ] || $(MAKE) -sC .. $@
	'$(GEN)' || { echo; echo "	make debug	# for better diagnose"; echo; false; } >&2

.PHONY:	debug
debug:
	@[ -f '$(GEN)' ] || $(MAKE) -sC .. $@
	DEBUG=1 '$(GEN)'

