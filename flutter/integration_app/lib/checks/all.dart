import 'auth.dart';
import 'cache.dart';
import 'checks_b.dart';
import 'checks_d.dart';
import 'checks_f.dart';
import 'ctx.dart';
import 'failures.dart';
import 'streams.dart';
import 'types.dart';
import 'unary.dart';

final List<CheckDef> allChecks = [
  ...unaryChecks,
  ...typeChecks,
  ...failureChecks,
  ...cacheChecks,
  ...authChecks,
  ...streamChecks,
  ...runtimeChecks,
  ...dChecks,
  ...checksF,
  ...checksB, // keep last: ends with b.shutdown_restart
];
