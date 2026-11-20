#!/usr/bin/env bash
# Copies the generated benchmark models without the Flutter import so the
# Dart VM (dart run / dart compile exe) can run them.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../../app/lib/axiom_generated/models.dart"
sed "s#import 'package:axiom_flutter/axiom_flutter.dart';#import 'stub.dart';#" "$src" > "$here/lib/gen/models.dart"
