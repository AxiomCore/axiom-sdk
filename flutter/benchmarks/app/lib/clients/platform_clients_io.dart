import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

Dio? newDioHttp2(String baseUrl) => Dio(BaseOptions(baseUrl: baseUrl))
  ..httpClientAdapter = Http2Adapter(
    ConnectionManager(
      idleTimeout: const Duration(seconds: 30),
      onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
    ),
  );

({String name, http.Client client})? platformHttpClient() {
  if (Platform.isAndroid) {
    return (name: 'cronet_http', client: CronetClient.defaultCronetEngine());
  }
  if (Platform.isIOS || Platform.isMacOS) {
    return (name: 'cupertino_http', client: CupertinoClient.defaultSessionConfiguration());
  }
  return null;
}

http.Client? newInsecureHttpClient() => IOClient(HttpClient()..badCertificateCallback = (_, _, _) => true);

Dio? newInsecureDio(String baseUrl) => Dio(BaseOptions(baseUrl: baseUrl))
  ..httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()..badCertificateCallback = (_, _, _) => true,
  );
