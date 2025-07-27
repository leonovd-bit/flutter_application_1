import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Enhanced Color Palette
  static const Color background = Color(0xFF000000);        // Pure Black
  static const Color surface = Color(0xFF111111);           // Rich Charcoal
  static const Color surfaceElevated = Color(0xFF1A1A1A);   // Elevated surface
  static const Color textPrimary = Color(0xFFFFFFFF);       // Pure White
  static const Color textSecondary = Color(0xFFB3B3B3);     // Muted white
  static const Color accent = Color(0xFF013220);            // Deep Forest Green
  static const Color accentLight = Color(0xFF0F5132);       // Lighter green
  static const Color border = Color(0xFF1C1C1C);            // Dark Gray
  static const Color borderLight = Color(0xFF2A2A2A);       // Lighter border
  static const Color hover = Color(0xFF0F2F25);             // Muted Dark Green Tint
  static const Color success = Color(0xFF10B981);           // Success green
  static const Color warning = Color(0xFFF59E0B);           // Warning amber
  static const Color error = Color(0xFFEF4444);             // Error red

  // Enhanced shadows and effects
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: accent.withValues(alpha: 0.1),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: accent.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, surfaceElevated],
  );

  // Typography
  static TextTheme get textTheme => GoogleFonts.poppinsTextTheme(
    const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 0.25,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.25,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.25,
      ),
      headlineLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 0.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.25,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: 0.25,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        letterSpacing: 0.25,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: 1.25,
        textBaseline: TextBaseline.alphabetic,
      ),
    ),
  );

  // Theme Data
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: textPrimary,
      secondary: hover,
      onSecondary: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      error: Color(0xFFCF6679),
      onError: Color(0xFF000000),
      outline: border,
    ),
    textTheme: textTheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: textTheme.headlineMedium,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: textPrimary,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.25,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.all(hover),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textPrimary,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.25,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(hover.withValues(alpha: 0.1)),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: border, width: 1),
      ),
      margin: const EdgeInsets.all(12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      labelStyle: const TextStyle(color: textPrimary),
      hintStyle: TextStyle(color: textPrimary.withValues(alpha: 0.6)),
    ),
  );
}

// Enhanced Custom Widgets
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool isElevated;
  final bool hasGradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.isElevated = true,
    this.hasGradient = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      } : null,
      onTapUp: widget.onTap != null ? (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap?.call();
      } : null,
      onTapCancel: widget.onTap != null ? () {
        setState(() => _isPressed = false);
        _controller.reverse();
      } : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: widget.hasGradient ? AppTheme.surfaceGradient : null,
                color: widget.hasGradient ? null : AppTheme.surface,
                border: Border.all(
                  color: _isPressed ? AppTheme.accent : AppTheme.border,
                  width: 1.5,
                ),
                boxShadow: widget.isElevated ? AppTheme.cardShadow : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: widget.padding ?? const EdgeInsets.all(20),
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double? height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onPressed != null ? (_) {
        _controller.reverse();
        widget.onPressed?.call();
      } : null,
      onTapCancel: widget.onPressed != null ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height ?? 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: widget.isPrimary ? AppTheme.primaryGradient : null,
                color: widget.isPrimary ? null : Colors.transparent,
                border: widget.isPrimary ? null : Border.all(
                  color: AppTheme.accent,
                  width: 2,
                ),
                boxShadow: widget.isPrimary ? [
                  ...AppTheme.buttonShadow,
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.3 * _glowAnimation.value),
                    blurRadius: 24,
                    offset: const Offset(0, 0),
                    spreadRadius: 4,
                  ),
                ] : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.isLoading ? null : widget.onPressed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.isPrimary ? AppTheme.textPrimary : AppTheme.accent,
                              ),
                            ),
                          )
                        else if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: widget.isPrimary ? AppTheme.textPrimary : AppTheme.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!widget.isLoading)
                          Text(
                            widget.text.toUpperCase(),
                            style: AppTheme.textTheme.labelLarge?.copyWith(
                              color: widget.isPrimary ? AppTheme.textPrimary : AppTheme.accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Custom Input Field
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool isPassword;
  final bool isEmail;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.isPassword = false,
    this.isEmail = false,
    this.prefixIcon,
    this.validator,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _borderAnimation;
  late Animation<double> _glowAnimation;
  bool _obscureText = true;
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _borderAnimation = ColorTween(
      begin: AppTheme.border,
      end: AppTheme.accent,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
      if (_focusNode.hasFocus) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.2 * _glowAnimation.value),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.isPassword && _obscureText,
            keyboardType: widget.isEmail ? TextInputType.emailAddress : TextInputType.text,
            validator: widget.validator,
            onTap: widget.onTap,
            readOnly: widget.readOnly,
            maxLines: widget.maxLines,
            style: AppTheme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              labelStyle: AppTheme.textTheme.bodyMedium?.copyWith(
                color: _isFocused ? AppTheme.accent : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: AppTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused ? AppTheme.accent : AppTheme.textSecondary,
                      size: 22,
                    )
                  : null,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: _isFocused ? AppTheme.accent : AppTheme.textSecondary,
                        size: 22,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _borderAnimation.value ?? AppTheme.accent, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.error, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.error, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
          ),
        );
      },
    );
  }
}

// Loading Indicator
class AppLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final String? message;

  const AppLoadingIndicator({
    super.key,
    this.size = 50,
    this.color,
    this.message,
  });

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_rotationAnimation, _pulseAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color?.withValues(alpha: 0.3) ?? AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// Premium Floating Action Button
class AppFloatingActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final bool isExtended;
  final String? label;

  const AppFloatingActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.tooltip,
    this.isExtended = false,
    this.label,
  });

  @override
  State<AppFloatingActionButton> createState() => _AppFloatingActionButtonState();
}

class _AppFloatingActionButtonState extends State<AppFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onPressed != null ? (_) {
        _controller.reverse();
        widget.onPressed?.call();
      } : null,
      onTapCancel: widget.onPressed != null ? () => _controller.reverse() : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: widget.isExtended
                    ? BorderRadius.circular(28)
                    : BorderRadius.circular(28),
                boxShadow: [
                  ...AppTheme.buttonShadow,
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.4 * _glowAnimation.value),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: widget.onPressed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: Icon(
                  widget.icon,
                  color: AppTheme.textPrimary,
                  size: 24,
                ),
                label: widget.isExtended && widget.label != null
                    ? Text(
                        widget.label!.toUpperCase(),
                        style: AppTheme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      )
                    : const SizedBox.shrink(),
                tooltip: widget.tooltip,
              ),
            ),
          );
        },
      ),
    );
  }
}
