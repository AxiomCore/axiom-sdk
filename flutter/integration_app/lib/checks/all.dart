import 'auth.dart';
import 'cache.dart';
import 'checks_a.dart';
import 'checks_b.dart';
import 'checks_c.dart';
import 'checks_d.dart';
import 'checks_f.dart';
import 'checks_fixg.dart';
import 'checks_g.dart';
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
  ...androidChecks,
  ...checksC,
  ...dChecks,
  ...checksF,
  ...checksG,
  ...checksFixg,
  ...checksB, // keep last: ends with b.shutdown_restart
];
