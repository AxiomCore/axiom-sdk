// Web-only benchmark hooks (unit webspeed): toggle the web runtime's C1.1
// body hand-over and C3.1 fast start for interleaved A/B runs.
// ignore: implementation_imports
import 'package:axiom_flutter/src/runtime_web.dart';

void benchSetExternalBodies(bool on) => AxiomRuntimeWeb.debugSetExternalBodies(on);
void benchSetFastStart(bool on) => AxiomRuntimeWeb.fastStart = on;
int benchExternalCount() => AxiomRuntimeWeb.debugExternalBodyCount;
int benchFastStartCount() => AxiomRuntimeWeb.debugFastStartCount;
