import 'package:flutter/material.dart';

enum AppTextFieldVariant { outlined, standard }

enum AppTextFieldSize { small, medium, large }

class AppTextField extends StatefulWidget {
  final String? label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final AppTextFieldVariant variant;
  final AppTextFieldSize size;

  const AppTextField({
    super.key,
    this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.variant = AppTextFieldVariant.outlined,
    this.size = AppTextFieldSize.medium,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final isStandard = widget.variant == AppTextFieldVariant.standard;

    final verticalPadding = switch (widget.size) {
      AppTextFieldSize.small => 8.0,
      AppTextFieldSize.medium => 14.0,
      AppTextFieldSize.large => 18.0,
    };

    final fontSize = switch (widget.size) {
      AppTextFieldSize.small => 13.0,
      AppTextFieldSize.medium => 15.0,
      AppTextFieldSize.large => 32.0,
    };

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          style: TextStyle(fontSize: fontSize, color: Colors.black),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: fontSize),

            // Standard is explicitly transparent.
            filled: isStandard ? true : false,
            fillColor: Colors.transparent,

            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: verticalPadding,
            ),

            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: fontSize + 5)
                : null,
            prefixIconColor: Colors.grey[400],

            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      size: fontSize + 5,
                    ),
                    onPressed: () {
                      setState(() => _obscureText = !_obscureText);
                    },
                    color: Colors.grey[400],
                  )
                : null,

            border: isStandard ? InputBorder.none : border,
            enabledBorder: isStandard ? InputBorder.none : border,
            focusedBorder: isStandard
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[500]!, width: 1),
                  ),
            errorBorder: isStandard
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
            focusedErrorBorder: isStandard
                ? InputBorder.none
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
          ),
        ),
      ],
    );
  }
}
