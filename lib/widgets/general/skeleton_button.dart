import 'package:delay_messenger/widgets/general/assets.dart';
import 'package:delay_messenger/widgets/general/general_designs.dart';
import 'package:delay_messenger/widgets/general/my_colors.dart';
import 'package:delay_messenger/widgets/general/paddings.dart';
import 'package:delay_messenger/widgets/text_styles.dart';
import 'package:flutter/material.dart';

/*
* Apliman button with latest UI design
* This button can be used in any place
* It can be customized to accept icon, label, or both
* Doc writer: Issa loubani
* */
class SkeletonButton extends StatelessWidget {
  /*
  * Optional widget to be displayed instead of the predefined header and body
  * */
  // final Widget? labelWidget;
  final Widget? templateIcon;
  final Widget? prefixIcon, suffixIcon;
  /*
  * Parameters to customize the card
  * */
  final String label;
  final String? iconPath;
  final String? prefixIconPath, suffixIconPath;
  final Color? color;
  final bool isLoading;
  final Color? contentColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final Decoration? decoration;
  final EdgeInsetsGeometry? padding;
  final TextStyle? labelStyle;
  final bool? isPrimary;
  final bool? isActive;
  final Size? size;
  final double? radiusWidth;
  final double? fontSize;
  final double? textHeight;
  final FontWeight? fontWeight;
  final BorderRadius? buttonRadius;
  // callback function to be called when the button is pressed
  final Function()? onPressed;

  const SkeletonButton({
    super.key,
    this.label = "",
    this.decoration,
    this.isLoading = false,
    this.color,
    this.onPressed,
    @Deprecated(
        'Use prefixIconPath instead, by default it will be used as prefixIconPath')
    this.iconPath,
    @Deprecated(
        'Use prefixIcon instead, by default it will be used as prefixIcon')
    this.templateIcon,
    this.padding,
    this.isPrimary = true,
    this.isActive,
    this.labelStyle,
    this.size,
    this.contentColor,
    this.borderColor,
    this.backgroundColor,
    this.radiusWidth,
    this.prefixIconPath,
    this.suffixIconPath,
    this.suffixIcon,
    this.prefixIcon,
    this.buttonRadius,
    this.fontSize,
    this.fontWeight,
    this.textHeight,
  });

  TextStyle get _labelStyle =>
      labelStyle ??
      buttonTextStyle(
        (isPrimary)!
            ? MyColors.white
            : (isActive == false)
                ? MyColors.disabledColor
                : contentColor ?? color!,
        fontWeight: fontWeight,
        fontSize: fontSize,
        textHeight: textHeight,
      );

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: TextButton.styleFrom(
        fixedSize: size,
        padding: padding ?? buttonPadding,
        backgroundColor: (isPrimary)!
            ? (isActive!)
                ? backgroundColor ?? color
                : MyColors.disabledColor
            : backgroundColor ?? MyColors.white,
        side: BorderSide(
          width: radiusWidth ?? getButtonRadiusWidth(),
          color: (isActive == false)
              ? MyColors.disabledColor
              : borderColor ?? color!,
        ),
        shape:
            RoundedRectangleBorder(borderRadius: buttonRadius ?? globalRadius),
      ),
      onPressed: (isActive!) ? () => onPressed?.call() : null,
      autofocus: false,
      child: Container(
        padding: padding ?? buttonPadding,
        height: size != null ? size?.height : null,
        child: ButtonData(),
      ),
    );
  }

  Widget ButtonData() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        (templateIcon ?? prefixIcon) ??
            (iconPath != null || prefixIconPath != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Assets.buildAsset(
                      iconPath ?? prefixIconPath!,
                      width: 20,
                      height: 20,
                      color: (isPrimary)!
                          ? backgroundColor ?? MyColors.white
                          : (isActive!)
                              ? backgroundColor ?? color
                              : MyColors.disabledColor,
                    ),

/*                    child: Image.asset(
                      iconPath ?? prefixIconPath!,
                      width: 20,
                      height: 20,
                      color: (isPrimary)!
                          ? backgroundColor ?? MyColors.white
                          : (isActive!)
                              ? backgroundColor ?? color
                              : MyColors.disabledColor,
                    ),*/
                  )
                : const SizedBox()),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              label,
              style: _labelStyle,
            )),
        suffixIcon ??
            (suffixIconPath != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Assets.buildAsset(
                      suffixIconPath!,
                      width: 20,
                      height: 20,
                      color: (isPrimary)!
                          ? backgroundColor ?? MyColors.white
                          : (isActive!)
                              ? backgroundColor ?? color
                              : MyColors.disabledColor,
                    ),
                    /*           child: Image.asset(
                  suffixIconPath!,
                  width: 20,
                  height: 20,
                  color: (isPrimary)!
                      ? backgroundColor ?? MyColors.white
                      : (isActive!)
                      ? backgroundColor ?? color
                      : MyColors.disabledColor,
                ),*/
                  )
                : const SizedBox()),
      ],
    );
  }
}
