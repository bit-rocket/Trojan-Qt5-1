# The major issue with using protoc & qmake is a question of emiting proper
# dependencies between source files (user written & generated) and generated
# header files.
#
# Protoc's generated header files can include other generated headers, but
# qmake doesn't know this (because deps are calculated at configure time)
# depend_command could theoretically be used to add a false dependency at a
# higher level, but qmake silently removes non-existant files from the output
# of depend_command. And the headers we want to depend on are generated, so
# they don't exist most of the time.
#
# There are a few not-so-nice options:
#  - use system() to (in some cases) invoke protoc as part of qmake
#    - pluses: 1 project
#    - downsides: build occurs durring configure (sometimes). qmake may end up
#      running more than necessary
#  - use system() to create empty headers prior to qmake trying to see if they
#    exist so dependencies are emitted properly.
#    - similar to the previous.
#  - use 3 project files & subdirs
#    - pluses: absolutely correct as far as qmake is concerned, build all
#      occurs durring build
#    - downsides: technically more deps (all protoc headers) than strictly
#      required, and 3 project files instead of 1.
#
# Note that all of this mess is only needed in cases where "import" is used in
# the proto files. Otherwise, one can just include `protobuf.pri` and have it
# work without issue.
#
# Long term: use cmake (or anything but qmake)

isEmpty(PROTOS):error("Define PROTOS before including grpc.pri")

win32 {
    isEmpty(PROTOC):PROTOC = C:\TQLibraries\Grpc\tools\protobuf\protoc.exe
    isEmpty(PROTOC_GRPC):PROTOC_GRPC = C:\TQLibraries\Grpc\tools\grpc\grpc_cpp_plugin.exe
}

mac {
    isEmpty(PROTOC):PROTOC = /opt/homebrew/bin/protoc
    isEmpty(PROTOC_GRPC):PROTOC_GRPC = /opt/homebrew/bin/grpc_cpp_plugin
}

unix:!mac {
    isEmpty(PROTOC):PROTOC = /usr/bin/protoc
    isEmpty(PROTOC_GRPC):PROTOC_GRPC = /usr/bin/grpc_cpp_plugin
}

grpc_decl.name = grpc headers
grpc_decl.input = PROTOS
grpc_decl.output = ${QMAKE_FILE_IN_PATH}/${QMAKE_FILE_BASE}.grpc.pb.h
grpc_decl.depend_command = $$PWD/protobuf_deps.sh ${QMAKE_FILE_IN_PATH} ${QMAKE_FILE_NAME}
#grpc_decl.dependency_type = TYPE_C
grpc_decl.commands = $${PROTOC} --grpc_out=${QMAKE_FILE_IN_PATH} --proto_path=${QMAKE_FILE_IN_PATH} --plugin=protoc-gen-grpc=$${PROTOC_GRPC} ${QMAKE_FILE_NAME}
grpc_decl.variable_out = HEADERS
QMAKE_EXTRA_COMPILERS += grpc_decl

# GENERATED_FILES (or whatever variable we use above) doesn't get populated
# early enough for us to use this variable everywhere we want to (for example,
# it won't be set when qmake is making choices about INSTALLS).
#
# As a work-around, generate it ourselves
# Note that this does require that PROTOS is set before including this file.
PROTOBUF_HEADERS =
for(proto, PROTOS) {
        headers = $$replace(proto, .proto, .grpc.pb.h)
        #message("headers: $${headers}")
        for (header, headers) {
                PROTOBUF_HEADERS += $${header}
                #message("header: $${header}")
        }
}
#message("protobuf_headers: $${PROTOBUF_HEADERS}")


grpc_impl.name = grpc sources
grpc_impl.input = PROTOS
grpc_impl.output = ${QMAKE_FILE_IN_PATH}/${QMAKE_FILE_BASE}.grpc.pb.cc

# Ideally, we would omit the "$${PROTOBUF_HEADERS}", but we need to
# (potentially) wait for other protobuf headers to be generated before we can
# allow the protobuf source files to be built. Including it makes us wait for
# _all_ protobuf headers to be built.  We can't specify exactly what headers we
# want, as they don't exist & scanning
# requires using depend_command which ignores non-existant files.
grpc_impl.depends = ${QMAKE_FILE_IN_PATH}/${QMAKE_FILE_BASE}.grpc.pb.h $${PROTOBUF_HEADERS}

grpc_impl.commands = $$escape_expand(\\n)
#grpc_impl.dependency_type = TYPE_C
grpc_impl.variable_out = SOURCES
QMAKE_EXTRA_COMPILERS += grpc_impl

#QMAKE_EXTRA_TARGETS += $${PROTOBUF_HEADERS}
# XXX: this _trys_ to have the protobuf headers generated first, but in reality
# they are still generated in parallel to object compilation.
#PRE_TARGETDEPS += $${PROTOBUF_HEADERS}
