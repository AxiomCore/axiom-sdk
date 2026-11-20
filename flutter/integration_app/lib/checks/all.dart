import 'auth.dart';
import 'cache.dart';
import 'checks_a.dart';
import 'checks_b.dart';
import 'checks_c.dart';
import 'checks_d.dart';
import 'checks_f.dart';
import 'checks_fixn.dart';
import 'checks_fixg.dart';
import 'checks_g.dart';
import 'checks_h.dart';
import 'checks_h2.dart';
import 'checks_webspeed.dart';
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
  ...checksH,
  ...checksFixn,
  ...checksFixg,
  ...checksWebspeed,
  ...checksH2, // h2.failed_initialize_is_retryable restarts the runtime
  ...checksB, // keep last: ends with b.shutdown_restart
];
