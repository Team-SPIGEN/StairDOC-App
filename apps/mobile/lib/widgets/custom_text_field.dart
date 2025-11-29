import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onEditingComplete,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    this.enabled = true,
    this.isPassword = false,
    this.enableObscureToggle = false,
    this.readOnly = false,
    this.maxLines = 1,
  });

  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;
  final bool enabled;
  final bool isPassword;
  final bool enableObscureToggle;
  final bool readOnly;
  final int maxLines;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  late bool _obscured = widget.isPassword;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocus() {
    setState(() {});
  }

  void _toggleObscure() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.isPassword ? _obscured : false,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        onTap: widget.onTap,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        maxLines: widget.isPassword ? 1 : widget.maxLines,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon != null
              ? Icon(widget.prefixIcon, color: theme.colorScheme.primary)
              : null,
          suffixIcon: widget.enableObscureToggle && widget.isPassword
              ? IconButton(
                  tooltip: _obscured ? 'Show password' : 'Hide password',
                  onPressed: _toggleObscure,
                  icon: Icon(
                    _obscured ? Icons.visibility_off : Icons.visibility,
                  ),
                )
              : widget.suffixIcon,
        ),
      ),
    );
  }
}
