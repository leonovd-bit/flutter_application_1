// Web implementation using dart:html
import 'dart:html' as html;

void openUrlImpl(String url) {
  html.window.location.href = url;
}