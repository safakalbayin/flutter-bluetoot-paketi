import 'dart:io';

const mimeTypes = {
  'html': 'text/html; charset=utf-8',
  'js': 'application/javascript; charset=utf-8',
  'mjs': 'application/javascript; charset=utf-8',
  'json': 'application/json',
  'css': 'text/css; charset=utf-8',
  'wasm': 'application/wasm',
  'png': 'image/png',
  'ico': 'image/x-icon',
  'svg': 'image/svg+xml',
  'ttf': 'font/ttf',
  'woff': 'font/woff',
  'woff2': 'font/woff2',
};

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '');
  final base = Platform.environment['BASE_PATH'] ?? '/device-identity/';
  if (port == null || port < 1 || port > 65535 ||
      !base.startsWith('/') || !base.endsWith('/')) {
    stderr.writeln('Provide valid PORT and a BASE_PATH starting/ending with /.');
    exit(1);
  }
  final root = Directory.fromUri(Platform.script.resolve('../dist/public/'));
  if (!File.fromUri(root.uri.resolve('index.html')).existsSync()) {
    stderr.writeln('Flutter build missing. Run dart run tool/build.dart first.');
    exit(1);
  }
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Flutter/Dart preview listening on 0.0.0.0:$port$base');
  await for (final request in server) {
    await _serve(request, root, base);
  }
}

Future<void> _serve(HttpRequest request, Directory root, String base) async {
  try {
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
      return;
    }
    final path = request.uri.path;
    if (path == base.substring(0, base.length - 1)) {
      await request.response.redirect(
        request.uri.replace(path: base), status: HttpStatus.permanentRedirect,
      );
      return;
    }
    if (!path.startsWith(base)) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    var relative = Uri.decodeComponent(path.substring(base.length));
    if (relative.split('/').any((part) => part == '..' || part.startsWith('.')) ||
        relative.contains('\\') || relative.contains('\u0000')) {
      request.response.statusCode = HttpStatus.forbidden;
      return;
    }
    // Existing standalone links still work, with the new Flutter-owned page.
    if (relative == 'flutter/index.html' || relative == 'flutter/') {
      await request.response.redirect(request.uri.replace(
        path: base,
        queryParameters: {...request.uri.queryParameters, 'screen': 'device'},
      ));
      return;
    }
    if (relative.isEmpty) relative = 'index.html';
    final file = File('${root.path}/$relative');
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    request.response.headers
      ..set(HttpHeaders.contentTypeHeader,
          mimeTypes[relative.split('.').last] ?? 'application/octet-stream')
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff');
    request.response.contentLength = await file.length();
    if (request.method == 'GET') {
      await request.response.addStream(file.openRead());
    }
  } catch (error, stack) {
    stderr.writeln('Preview request failed: $error\n$stack');
    request.response.statusCode = HttpStatus.internalServerError;
  } finally {
    await request.response.close();
  }
}
