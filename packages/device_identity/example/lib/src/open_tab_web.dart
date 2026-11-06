import 'dart:js_interop';

@JS('window.open')
external JSAny? _windowOpen(JSString url, JSString target, JSString features);

/// Opens [url] in a new browser tab without dart:html.
bool openInNewTab(String url) {
  _windowOpen(url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
  return true;
}
