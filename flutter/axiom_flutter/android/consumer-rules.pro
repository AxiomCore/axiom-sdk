# axiom_flutter talks to libaxiom_runtime.so through dart:ffi only: there are
# no JNI entry points or Java classes to keep, so R8 needs no rules. The file
# exists so apps can see that this was checked.
