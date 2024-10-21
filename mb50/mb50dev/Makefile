# Makefile for GNU Make

CXXFLAGS_DBG ?= -g
CXXFLAGS_OPT ?= -O2

CXXFLAGS += \
	${CXXFLAGS_DBG} ${CXXFLAGS_OPT} \
	-std=c++23 -Wall -Wextra -pedantic -Werror \
	-Wconversion -Wsign-conversion \
	-Wswitch-default -Wswitch-enum \
	-Wno-mismatched-new-delete \
	-Wimplicit-fallthrough \
	-Wno-sign-conversion

SRCS = mb50as.cpp mb50dbg.cpp
BINS = ${basename ${SRCS}}

COMPILE_DB ?= compile_commands.json

.DEFAULT: all
.PHONY: all clean compile_commands.json

%: %.cpp
	${CXX} ${CPPFLAGS} ${CXXFLAGS} -o $@ $^

# Build all programs
all: ${COMPILE_DB} ${BINS}

# Clean build results
clean:
	rm -f ${COMPILE_DB} ${BINS}

# Build compile_commands.json
COMPILE_DB_ENTRY = echo '{"directory": "'`pwd`'","file":"'`pwd`'${B}.cpp","command":"${CXX} ${CPPFLAGS} ${CXXFLAGS} -c ${B}.cpp"},';
${COMPILE_DB}:
	{ \
	echo '['; \
	{ ${foreach B, ${BINS}, ${COMPILE_DB_ENTRY}} } | sed '$$s/,$$//'; \
	echo ']'; \
	} > ${COMPILE_DB}

# Build individual programs
define bin_src_dep
${1}: ${1}.cpp
endef

${foreach B, ${BINS}, ${eval ${call bin_src_dep ${B}}}}
