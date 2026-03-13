import 'package:delay_messenger/widgets/general/my_colors.dart';
import 'package:delay_messenger/widgets/general/skeleton_button.dart';
import 'package:flutter/cupertino.dart';

class GeneralButton extends StatelessWidget {
/*
  * Parameters to customize the card
  * */
  final String label;
  final String? iconPath;
  final String? prefixIconPath, suffixIconPath;
  final Widget? prefixIcon, suffixIcon;
  final Color? color;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final bool? isPrimary;
  final bool? isActive;
  final Size? size; //Size(100,45)
  final bool? isExpanded;
  final BorderRadius? buttonRadius;
// callback function to be called when the button is pressed
  final Function()? onPressed;
// change font
  final double? fontSize;
  final double? textHeight;
  final FontWeight? fontWeight;

  const GeneralButton({
    super.key,
    this.label = "",
    this.color,
    this.isLoading = false,
    this.onPressed,
    @Deprecated(
        'Use prefixIconPath instead, by default it will be used as prefixIconPath')
    this.iconPath,
    this.padding,
    this.isPrimary,
    this.isActive,
    this.isExpanded,
    this.size,
    this.prefixIconPath,
    this.suffixIconPath,
    this.prefixIcon,
    this.suffixIcon,
    this.buttonRadius,
    this.fontSize,
    this.fontWeight,
    this.textHeight,
  });

  @override
  Widget build(BuildContext context) {
    return isExpanded == true
        ? Expanded(
            child: SkeletonButton(
                label: label,
                isLoading: isLoading,
                color: color ?? MyColors.primaryColor,
                onPressed: onPressed,
                iconPath: iconPath,
                padding: padding,
                isPrimary: isPrimary ?? true,
                isActive: isActive ?? true,
                size: size,
                prefixIconPath: prefixIconPath,
                suffixIconPath: suffixIconPath,
                prefixIcon: prefixIcon,
                suffixIcon: suffixIcon,
                buttonRadius: buttonRadius,
                fontSize: fontSize,
                fontWeight: fontWeight,
                textHeight: textHeight))
        : SkeletonButton(
            label: label,
            isLoading: isLoading,
            color: color ?? MyColors.primaryColor,
            onPressed: onPressed,
            iconPath: iconPath,
            padding: padding,
            isPrimary: isPrimary ?? true,
            isActive: isActive ?? true,
            size: size,
            prefixIconPath: prefixIconPath,
            suffixIconPath: suffixIconPath,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            buttonRadius: buttonRadius,
            fontSize: fontSize,
            fontWeight: fontWeight,
            textHeight: textHeight,
          );
  }
}
