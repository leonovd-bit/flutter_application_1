export 'square_web_payments_stub.dart'
    if (dart.library.html) 'square_web_payments_web.dart'
    if (dart.library.io) 'square_web_payments_mobile.dart';
