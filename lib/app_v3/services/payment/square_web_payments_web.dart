// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/widgets.dart';
import 'dart:ui_web' as ui;

class SquareWebPayments {
  SquareWebPayments._();

  static final SquareWebPayments instance = SquareWebPayments._();

  static const String _viewType = 'square-card-container';
  static bool _viewRegistered = false;
  static bool _initialized = false;

  void _ensureViewRegistered() {
    if (_viewRegistered) return;
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final element = html.DivElement()
        ..id = _viewType
        ..style.width = '100%'
        ..style.height = '56px'
        ..style.minHeight = '48px';
      return element;
    });
    _viewRegistered = true;
  }

  Future<void> initialize({
    required String applicationId,
    required String locationId,
    required String env,
  }) async {
    _ensureViewRegistered();

    if (_initialized) return;

    final initFn = js_util.getProperty(html.window, 'initializeSquarePayments');
    if (initFn == null) {
      throw StateError('Square Web Payments JS helper is not loaded');
    }

    await js_util.promiseToFuture(js_util.callMethod(
      html.window,
      'initializeSquarePayments',
      [applicationId, locationId, _viewType, env],
    ));

    _initialized = true;
  }

  Future<String> tokenize() async {
    final tokenizeFn = js_util.getProperty(html.window, 'tokenizeSquareCard');
    if (tokenizeFn == null) {
      throw StateError('Square Web Payments tokenization is not available');
    }

    final result = await js_util.promiseToFuture<String>(
      js_util.callMethod(html.window, 'tokenizeSquareCard', []),
    );

    return result;
  }

  Widget buildCardView() {
    _ensureViewRegistered();
    return const HtmlElementView(viewType: _viewType);
  }
}
