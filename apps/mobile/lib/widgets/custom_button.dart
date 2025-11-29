import 'package:flutter/material.dart';

enum CustomButtonVariant { primary, secondary, text }

enum CustomButtonSize { fullWidth, auto }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.size = CustomButtonSize.fullWidth,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final CustomButtonSize size;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final buttonChild = _ButtonContent(
      label: label,
      isLoading: isLoading,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      variant: variant,
    );

    final button = switch (variant) {
      CustomButtonVariant.primary => FilledButton(
        onPressed: _effectiveOnPressed,
        child: buttonChild,
      ),
      CustomButtonVariant.secondary => OutlinedButton(
        onPressed: _effectiveOnPressed,
        child: buttonChild,
      ),
      CustomButtonVariant.text => TextButton(
        onPressed: _effectiveOnPressed,
        child: buttonChild,
      ),
    };

    if (size == CustomButtonSize.auto) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }

  VoidCallback? get _effectiveOnPressed =>
      enabled && !isLoading ? onPressed : null;
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.isLoading,
    required this.variant,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final bool isLoading;
  final CustomButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final textStyle = switch (variant) {
      CustomButtonVariant.primary => Theme.of(context).textTheme.labelLarge,
      CustomButtonVariant.secondary => Theme.of(context).textTheme.labelLarge,
      CustomButtonVariant.text => Theme.of(context).textTheme.labelMedium,
    };

    if (isLoading) {
      final colorScheme = Theme.of(context).colorScheme;
      final indicatorColor = switch (variant) {
        CustomButtonVariant.primary => colorScheme.onPrimary,
        CustomButtonVariant.secondary => colorScheme.primary,
        CustomButtonVariant.text => colorScheme.primary,
      };
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
        ),
      );
    }

    final children = <Widget>[];

    if (leadingIcon != null) {
      children.add(Icon(leadingIcon, size: 20));
      children.add(const SizedBox(width: 8));
    }

    children.add(Text(label, style: textStyle));

    if (trailingIcon != null) {
      children.add(const SizedBox(width: 8));
      children.add(Icon(trailingIcon, size: 20));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }
}
