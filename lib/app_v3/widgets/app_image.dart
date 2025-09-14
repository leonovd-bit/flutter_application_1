import 'package:flutter/material.dart';

/// AppImage picks the right image provider based on the given path:
/// - http/https URL -> NetworkImage
/// - assets/... -> AssetImage
/// - empty/null -> renders a decorated fallback with an icon
class AppImage extends StatelessWidget {
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

  bool get _isNetwork => (path ?? '').startsWith('http');
  bool get _isAsset => (path ?? '').startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    
    // Debug logging
    print('AppImage: path="$path", _isAsset=$_isAsset, _isNetwork=$_isNetwork');
    
    Widget child;
    if (path != null && path!.isNotEmpty) {
      if (_isNetwork) {
        child = Image.network(
          path!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stack) {
            print('AppImage Network Error for "$path": $error');
            return _fallback(context);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('AppImage Network Success for "$path"');
              return child;
            }
            return _fallback(context);
          },
        );
      } else if (_isAsset) {
        child = Image.asset(
          path!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stack) {
            print('AppImage Asset Error for "$path": $error');
            return _fallback(context);
          },
        );
      } else {
        print('AppImage: Unknown format for "$path"');
        child = _fallback(context);
      }
    } else {
      print('AppImage: Empty/null path');
      child = _fallback(context);
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: width, height: height, child: child),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: fallbackBg ?? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        size: (width < height ? width : height) * 0.5,
        color: fallbackIconColor ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
