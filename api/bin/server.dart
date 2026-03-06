import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:car_detector_api/config.dart';
import 'package:car_detector_api/router.dart';

Future<void> main() async {
  final handler = buildRouter();
  final port = Config.port;

  final server = await shelf_io.serve(handler, '0.0.0.0', port);
  print('Car Detector API listening on port ${server.port}');
  print('Auth: ${Config.authEnabled ? "enabled" : "open/dev mode"}');
}
