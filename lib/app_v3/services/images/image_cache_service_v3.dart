import 'package:flutter/material.dart';

/// Lightweight in-memory ImageProvider cache with optional precache hook.
/// Avoids re-instantiating NetworkImage/AssetImage repeatedly for identical URLs
/// and lets calling code trigger a precache to warm image decoding.
class ImageCacheServiceV3 {
  ImageCacheServiceV3._();
  static final ImageCacheServiceV3 instance = ImageCacheServiceV3._();

  final Map<String, ImageProvider> _providers = <String, ImageProvider>{};

  ImageProvider providerFor(String path) {
    final key = path.trim();
    if (key.isEmpty) {
      return const AssetImage('assets/images/placeholder.png');
    }
    final existing = _providers[key];
    if (existing != null) return existing;

    ImageProvider created;
    if (key.startsWith('http')) {
      created = NetworkImage(key);
    } else if (key.startsWith('assets/')) {
      created = AssetImage(key);
    } else {
      created = NetworkImage(key); // fallback; may 404 but keeps type uniform
    }
    _providers[key] = created;
    return created;
  }

  Future<void> precache(BuildContext context, String path) async {
    final key = path.trim();
    if (key.isEmpty) return;
    try {
      final provider = providerFor(key);
      await precacheImage(provider, context);
    } catch (_) {
      // Silent ignore; precache is opportunistic
    }
  }

  int get size => _providers.length;
  void clear() => _providers.clear();
}
