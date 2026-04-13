import 'package:flutter/material.dart';

enum ButtonVariant { filled, outlined, text }
enum ButtonSize { small, medium, large }

/// A unified button widget supporting filled, outlined, and text variants
/// with optional loading state, icon, and size control.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool fullWidth;
  final bool isLoading;
  final ButtonVariant variant;
  final ButtonSize size;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.fullWidth = true,
    this.isLoading = false,
    this.variant = ButtonVariant.filled,
    this.size = ButtonSize.medium,
  });

  EdgeInsetsGeometry get _padding => switch (size) {
        ButtonSize.small => const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        ButtonSize.large => const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
        ButtonSize.medium => const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      };

  double get _fontSize => switch (size) {
        ButtonSize.small => 14,
        ButtonSize.large => 18,
        ButtonSize.medium => 16,
      };

  Size? get _minSize => fullWidth ? const Size(double.infinity, 0) : null;

  Widget get _child => isLoading
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: _fontSize)),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnPressed = isLoading ? null : onPressed;

    switch (variant) {
      case ButtonVariant.outlined:
        return OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor ?? theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: _minSize,
          ),
          child: _child,
        );
      case ButtonVariant.text:
        return TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor ?? theme.colorScheme.primary,
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: _minSize,
          ),
          child: _child,
        );
      case ButtonVariant.filled:
        return ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed == null
                ? Colors.grey
                : backgroundColor ?? theme.colorScheme.primary,
            foregroundColor: foregroundColor ?? theme.colorScheme.onPrimary,
            padding: _padding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: _minSize,
          ),
          child: _child,
        );
    }
  }
}
