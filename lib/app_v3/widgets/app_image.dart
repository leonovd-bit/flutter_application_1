import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Runtime normalization helpers for legacy / misconfigured Firebase Storage URLs.
/// We observed 412 errors for URLs containing the bucket segment
/// `freshpunk-48db1.firebasestorage.app` which should be `freshpunk-48db1.appspot.com`.
/// These helpers transparently rewrite and retry without requiring an immediate
/// Firestore data migration.
String _normalizeStorageUrl(String url) {
  if (url.isEmpty) return url;
  const wrongBucket = 'freshpunk-48db1.firebasestorage.app';
  const correctBucket = 'freshpunk-48db1.appspot.com';
  // Replace bucket segment inside /b/<bucket>/ occurrences
  if (url.contains('/b/$wrongBucket/')) {
    url = url.replaceAll('/b/$wrongBucket/', '/b/$correctBucket/');
  }
  // Ensure alt=media for direct serving
  if (url.startsWith('https://firebasestorage.googleapis.com') &&
      url.contains('/o/') && !url.contains('alt=media')) {
    url = url.contains('?') ? '$url&alt=media' : '$url?alt=media';
  }
  return url;
}

/// AppImage picks the right image provider based on the given path:
/// - http/https URL -> NetworkImage
/// - assets/... -> AssetImage
/// - empty/null -> renders a decorated fallback with an icon
class AppImage extends StatefulWidget {
  final String? path;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackBg;
  final Color? fallbackIconColor;

  const AppImage(
    this.path, {
    super.key,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.fastfood,
    this.fallbackBg,
    this.fallbackIconColor,
  });

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  String? _resolvedUrl;
  bool _resolving = false;
  bool _didNetworkRetry = false; // prevent infinite retry loops

  @override
  void initState() {
    super.initState();
    _maybeResolveStorageUrl();
  }

  @override
  void didUpdateWidget(covariant AppImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _resolvedUrl = null;
      _maybeResolveStorageUrl();
    }
  }

  bool _isNetwork(String? p) => (p ?? '').startsWith('http');
  bool _isAsset(String? p) => (p ?? '').startsWith('assets/');

  Future<void> _maybeResolveStorageUrl() async {
    final p = widget.path ?? '';
    if (p.isEmpty) return;

    // If it's a Firebase Storage public endpoint but missing token, try to generate a proper download URL
    final isGcsHttp = p.contains('firebasestorage.googleapis.com');
    final hasToken = p.contains('token=');

    // Also support direct storage path via a custom prefix
    final isStoragePrefix = p.startsWith('storage://');

    String? storagePath;
    if (isStoragePrefix) {
      storagePath = p.substring('storage://'.length);
    } else if (isGcsHttp && !hasToken) {
      storagePath = _extractStoragePathFromUrl(p);
    }

    if (storagePath == null || storagePath.isEmpty) return;

    if (_resolving) return;
    _resolving = true;
    try {
      print('🔐 AppImage: Resolving Storage URL for "$storagePath"');
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      String? url;
      try {
        url = await ref.getDownloadURL();
      } catch (e) {
        // If object not found, probe common extensions by swapping the file extension
        try {
          final lastSlash = storagePath.lastIndexOf('/');
          final dir = lastSlash >= 0 ? storagePath.substring(0, lastSlash) : '';
          final file = lastSlash >= 0 ? storagePath.substring(lastSlash + 1) : storagePath;
          final dot = file.lastIndexOf('.');
          final base = dot >= 0 ? file.substring(0, dot) : file;
          final currentExt = dot >= 0 ? file.substring(dot + 1).toLowerCase() : '';
          final exts = <String>{
            if (currentExt.isNotEmpty) currentExt,
            // Try most common web image extensions
            'jpg','jpeg','png','webp','jfif','avif',
          }.toList();

          for (final ext in exts) {
            final candidate = (dir.isEmpty) ? '$base.$ext' : '$dir/$base.$ext';
            try {
              final candidateUrl = await FirebaseStorage.instance.ref().child(candidate).getDownloadURL();
              print('🔎 AppImage: Resolved by probing "$candidate"');
              url = candidateUrl;
              break;
            } catch (_) {
              continue;
            }
          }
        } catch (_) {
          // ignore
        }
      }
      if (url != null && mounted) {
        setState(() {
          _resolvedUrl = url;
        });
        print('✅ AppImage: Resolved download URL');
      }
    } catch (e) {
      print('❌ AppImage: Failed to resolve download URL for "$storagePath": $e');
    } finally {
      _resolving = false;
    }
  }

  String? _extractStoragePathFromUrl(String url) {
    try {
      final idx = url.indexOf('/o/');
      if (idx == -1) return null;
      final start = idx + 3;
      final q = url.indexOf('?', start);
      final encoded = q == -1 ? url.substring(start) : url.substring(start, q);
      return Uri.decodeComponent(encoded);
    } catch (_) {
      return null;
    }
  }

  // Attempt to resolve a valid download URL from any Firebase Storage URL or path,
  // probing common extensions if the exact object is missing. On success, sets _resolvedUrl.
  Future<void> _resolveFromUrlAndRetry(String originalUrl) async {
    if (_didNetworkRetry) return;
    _didNetworkRetry = true;

    String? storagePath = _extractStoragePathFromUrl(originalUrl);
    if (storagePath == null || storagePath.isEmpty) {
      // Try to treat the original as a plain storage path if it looks like one
      if (originalUrl.contains('/')) storagePath = originalUrl;
    }
    if (storagePath == null || storagePath.isEmpty) return;

    try {
      print('🛠️ AppImage: Retrying via Storage SDK for "$storagePath"');
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      String? url;
      try {
        url = await ref.getDownloadURL();
      } catch (_) {
        // Probe alternate extensions from the original
        final lastSlash = storagePath.lastIndexOf('/');
        final dir = lastSlash >= 0 ? storagePath.substring(0, lastSlash) : '';
        final file = lastSlash >= 0 ? storagePath.substring(lastSlash + 1) : storagePath;
        final dot = file.lastIndexOf('.');
        final base = dot >= 0 ? file.substring(0, dot) : file;
        final currentExt = dot >= 0 ? file.substring(dot + 1).toLowerCase() : '';
        final candidates = <String>{
          if (currentExt.isNotEmpty) currentExt,
          'jpg','jpeg','png','webp','jfif','avif',
        };
        for (final ext in candidates) {
          final candidatePath = (dir.isEmpty) ? '$base.$ext' : '$dir/$base.$ext';
          try {
            final candidateUrl = await FirebaseStorage.instance.ref().child(candidatePath).getDownloadURL();
            print('🔎 AppImage: Retry resolved "$candidatePath"');
            url = candidateUrl;
            break;
          } catch (_) {
            continue;
          }
        }
      }
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _resolvedUrl = url;
        });
        print('✅ AppImage: Retry got download URL');
      }
    } catch (e) {
      print('❌ AppImage: Retry via Storage SDK failed for "$storagePath": $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(12);

  // Apply normalization before using the path so that incorrect bucket names are corrected on the fly.
  final chosen = _normalizeStorageUrl(_resolvedUrl ?? widget.path ?? '');
    final isNet = _isNetwork(chosen);
    final isAsset = _isAsset(chosen);

    print('🖼️ AppImage: path="${widget.path}", resolved="$_resolvedUrl", width=${widget.width}, height=${widget.height}, isAsset=$isAsset, isNetwork=$isNet');

    Widget child;
    if (chosen.isNotEmpty) {
      if (isNet) {
        child = Image.network(
          chosen,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stack) {
            print('❌ AppImage Network Error for "$chosen": $error');
            // One-time recovery path:
            // 1) If original URL had a wrong bucket/params, normalize and retry
            // 2) Otherwise, attempt to resolve via Storage SDK and probe common extensions
            if (_resolvedUrl == null && (widget.path?.contains('firebasestorage.googleapis.com') ?? false)) {
              final original = widget.path ?? '';
              final normalizedOriginal = _normalizeStorageUrl(original);
              if (normalizedOriginal != original) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _resolvedUrl = normalizedOriginal;
                  });
                });
              } else {
                // Attempt SDK-based resolve/probe regardless of existing token
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _resolveFromUrlAndRetry(original);
                });
              }
            }
            return _fallback(context);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('✅ AppImage Network Success for "$chosen"');
              return child;
            }
            return Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
        );
      } else if (isAsset) {
        print('📁 AppImage: Attempting to load asset "$chosen"');
        child = Image.asset(
          chosen,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null) {
              print('✅ AppImage Asset Success for "$chosen"');
            }
            return child;
          },
          errorBuilder: (context, error, stack) {
            print('❌ AppImage Asset Error for "$chosen": $error');
            return _fallback(context);
          },
        );
      } else {
        print('⚠️ AppImage: Unknown path format for "$chosen"');
        child = _fallback(context);
      }
    } else {
      print('⚠️ AppImage: Empty/null path provided');
      child = _fallback(context);
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: widget.width, height: widget.height, child: child),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.fallbackBg ?? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      alignment: Alignment.center,
      child: Icon(
        widget.fallbackIcon,
        size: (widget.width < widget.height ? widget.width : widget.height) * 0.5,
        color: widget.fallbackIconColor ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
