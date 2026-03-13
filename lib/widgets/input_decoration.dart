import 'package:delay_messenger/widgets/general/app_localization.dart';
import 'package:delay_messenger/widgets/general/assets.dart';
import 'package:delay_messenger/widgets/general/general_designs.dart';
import 'package:delay_messenger/widgets/general/my_colors.dart';
import 'package:delay_messenger/widgets/general/paddings.dart';
import 'package:delay_messenger/widgets/text_styles.dart';
import 'package:flutter/material.dart';

final dropdownBorder = RoundedRectangleBorder(
    borderRadius: globalRadius,
    side: BorderSide(
      width: 1.0,
      color: MyColors.primaryColor,
      strokeAlign: BorderSide.strokeAlignInside,
    )
    //set border radius more than 50% of height and width to make circle
    );

final popupBorder = RoundedRectangleBorder(
  borderRadius: globalRadius,
);

InputDecoration buildSearchDecoration(
    BuildContext context, String label, String placeholder,
    {Widget? suffixIcon}) {
  return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      enabledBorder: buildInputBorder(MyColors.primaryColor),
      fillColor: MyColors.white,
      focusedBorder: buildInputBorder(MyColors.primaryColor),
      filled: true,
      //hoverColor: MyColors.hoverColor,
      labelText: label,
      hintText: placeholder,
      hintStyle: inputTextHintStyle(MyColors.inputInnerTextHint,
          fontWeight: FontWeight.w400),
      labelStyle: inputTextHintStyle(MyColors.inputInnerTextHint,
          fontWeight: FontWeight.w400),
      prefixIcon: IconButton(
        icon: Assets.buildAssetSVG(
          "assets/icons/search.svg",
          color: MyColors.primaryColor,
          width: 20,
          height: 20,
        ),
        onPressed: null,
      ),
      suffixIcon: suffixIcon);
}

InputDecoration buildInputDecoration(
    String label, bool readOnly, BuildContext context, String? placeholder,
    {Widget? prefixIcon,
    Widget? suffixIcon,
    Widget? suffixWidget,
    Widget? prefixWidget,
    String? errorText,
    bool? isTextField,
    String? helperText,
    bool? hideErrorMessage,
    int? maxHintText,
    String? itemWrapper,
    double? fontSize,
    FontWeight? fontWeight}) {
  return InputDecoration(
    errorText: errorText,
    errorStyle: hideErrorMessage == true
        ? const TextStyle(height: 0, fontSize: 0.2)
        : helperTextHint.copyWith(
            color: MyColors.errorColor,
          ),
    contentPadding: ((isTextField != null && isTextField) && isTextField)
        ? innerInputMaxLinesPadding
        : innerInputPadding,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    enabledBorder: buildInputBorder(
        readOnly ? MyColors.mainGreyColor : MyColors.primaryColor),
    errorBorder: buildInputBorder(MyColors.errorColor),
    focusedErrorBorder: buildInputBorder(MyColors.errorColor),
    focusedBorder: buildInputBorder(
        readOnly ? MyColors.mainGreyColor : MyColors.primaryColor),
    fillColor: MyColors.inputInnerColor,
    filled: true,
    hintText: placeholder != null
        ? getTextWrapped(placeholder, maxHintText ?? 30, itemWrapper ?? "...")
        : getTextWrapped(
            AppLocalizations.of(context).translate("Select") + " " + label,
            maxHintText ?? 30,
            itemWrapper ?? "..."),
    hintStyle: inputTextHintStyle(MyColors.inputInnerTextHint,
        fontSize: fontSize, fontWeight: fontWeight),
    hintMaxLines: 1,
    labelStyle: inputTextHintStyle(MyColors.inputInnerTextHint,
        fontSize: fontSize, fontWeight: fontWeight),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    suffix: suffixWidget,
    prefix: prefixWidget,
    hoverColor: Colors.transparent,
    helperMaxLines: 1,
    helperText: helperText,
    helperStyle: helperTextHint.copyWith(
      color: readOnly
          ? MyColors.primaryColor.withOpacity(0.5)
          : MyColors.primaryColor,
    ),
  );
}

getTextWrapped(String text, int maxText, String itemWrapper) {
  return (text.length < maxText)
      ? text
      : text.substring(0, maxText) + itemWrapper;
}

BoxDecoration buildCounterDecoration(Color borderColor) {
  return BoxDecoration(
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(10.0),
      topRight: Radius.circular(10.0),
      bottomLeft: Radius.circular(10.0),
      bottomRight: Radius.circular(10.0),
    ),
    border: Border.all(color: borderColor, width: 1.0),
  );
}

InputDecoration buildEmptyBorderDecoration(
    String label, bool readOnly, BuildContext context,
    {Widget? prefixIcon, String? placeholder}) {
  return InputDecoration(
    hintText: placeholder ??
        AppLocalizations.of(context).translate("Enter") + " " + label,
    hintStyle: inputTextHintStyle(
        readOnly ? MyColors.disabledColor2 : MyColors.inputInnerTextHint),
    contentPadding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    enabledBorder: buildNoBorder(),
    errorBorder: buildNoBorder(),
    focusedErrorBorder: buildNoBorder(),
    focusedBorder: buildNoBorder(),
    hoverColor: MyColors.inputInnerColor,
    fillColor: MyColors.inputInnerColor,
    filled: true,
    errorStyle: const TextStyle(height: 0, fontSize: 0.1),
    errorMaxLines: 1,
    errorText: null,
    labelStyle: inputTextHint,
    prefixIcon: prefixIcon,
  );
}

OutlineInputBorder buildInputBorder(Color color) {
  return OutlineInputBorder(
    gapPadding: 20,
    borderSide: BorderSide(color: color, width: 1.0),
    borderRadius: BorderRadius.circular(10.0),
  );
}

OutlineInputBorder buildNoBorder() {
  return OutlineInputBorder(
      gapPadding: 20, borderSide: BorderSide.none, borderRadius: globalRadius
      // borderRadius: BorderRadius.only(topRight: globalRadiusBorder,topLeft: globalRadiusBorder),
      );
}

InputDecoration buildCounterInputDecoration(
    String label, bool readOnly, BuildContext context,
    {Widget? prefixIcon}) {
  return InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    enabledBorder: buildInputBorder(
        readOnly ? MyColors.lightGrey1 : MyColors.primaryColor),
    errorBorder: buildInputBorder(MyColors.errorColor),
    focusedErrorBorder: buildInputBorder(MyColors.errorColor),
    focusedBorder: buildInputBorder(
        readOnly ? MyColors.lightGrey1 : MyColors.primaryColor),
    fillColor: readOnly
        ? MyColors.lightGreySelected
        : MyColors.lightPrimaryColor2.withOpacity(0.3),
    filled: true,
    labelStyle: inputTextHint,
    prefixIcon: prefixIcon,
  );
}

InputDecoration buildDropdownInputDecoration(String label, bool readOnly,
    {Widget? prefixIcon}) {
  return InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    enabledBorder: buildInputBorder(
        readOnly ? MyColors.lightGrey1 : MyColors.primaryColor),
    errorBorder: buildInputBorder(MyColors.errorColor),
    focusedErrorBorder: buildInputBorder(MyColors.errorColor),
    focusedBorder: buildInputBorder(
        readOnly ? MyColors.lightGrey1 : MyColors.primaryColor),
    fillColor: readOnly
        ? MyColors.lightGreySelected
        : MyColors.lightPrimaryColor2.withOpacity(0.3),
    filled: true,
    hintText: label,
    hintStyle: inputTextHint,
    labelStyle: inputTextHint,
    labelText: label,
    prefixIcon: prefixIcon,
  );
}

InputDecoration buildMutiInputDecoration(String label, bool readOnly,
    BuildContext context, String startText, bool isUnit, double paddingLeft,
    {Widget? prefixIcon,
    Widget? suffixIcon,
    Widget? suffixWidget,
    Widget? prefixWidget,
    String? errorText,
    bool? isTextField}) {
  return InputDecoration(
    errorText: errorText,
    contentPadding: isUnit == true
        ? EdgeInsets.only(
            left: paddingLeft,
            top: 2.0,
            bottom: 2,
            right: 0.0,
          )
        : innerInputPadding,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    border: buildNoBorder(),
    fillColor: MyColors.inputInnerColor,
    filled: true,
    // hintText: AppLocalizations.of(context).translate(startText) + " " + label,
    hintStyle: inputTextHint,
    labelStyle: inputTextHint,
  );
}

InputDecoration mutiInputTextDecoration(
    String label, bool readOnly, BuildContext context,
    {Widget? prefixIcon}) {
  return InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    enabledBorder: buildNoBorder(),
    errorBorder: buildNoBorder(),
    focusedErrorBorder: buildNoBorder(),
    focusedBorder: buildNoBorder(),
    fillColor: MyColors.inputInnerColor,
    filled: true,
    labelText: label,
    labelStyle: inputTextHint,
  );
}
