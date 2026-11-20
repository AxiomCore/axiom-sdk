import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

/// dio over HTTP/2 (dio_http2_adapter), trusting the bench server's self-signed certificate.
/// null where not available (web).
Dio? newDioHttp2(String baseUrl) => null;

/// Name and client of the platform HTTP stack (cronet_http on Android, cupertino_http on
/// iOS/macOS); null elsewhere.
({String name, http.Client client})? platformHttpClient() => null;

/// package:http IOClient trusting the self-signed certificate (for the https/h2 base URL on the
/// VM: dart:io HttpClient speaks HTTP/1.1 over TLS). null on web (Chrome flag instead).
http.Client? newInsecureHttpClient() => null;

/// dio (default HTTP/1.1 adapter) trusting the self-signed certificate; null on web.
Dio? newInsecureDio(String baseUrl) => null;
