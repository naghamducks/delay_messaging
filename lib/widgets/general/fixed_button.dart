import 'package:delay_messenger/widgets/general/my_colors.dart';
import 'package:delay_messenger/widgets/general_button.dart';
import 'package:flutter/cupertino.dart';

buildFixedButton(
    {required bool isConfirm,
    required BuildContext context,
    Color? color,
    bool isLoading = false,
    String? text,
    bool? isActive,
    Function()? callbackFunction,
    String? destination,
    bool? isExpanded}) {
  return GeneralButton(
    label: text ?? (isConfirm ? "Confirm" : "Cancel"),
    isPrimary: isConfirm,
    isExpanded: isExpanded ?? true,
    isLoading: isLoading,
    isActive: isActive ?? true,
    color: color ?? MyColors.primaryColor,
    onPressed: () async {
      if (callbackFunction != null) {
        callbackFunction.call();
        return;
      }
      if (callbackFunction != null) {
        callbackFunction();
        return;
      }
      if (destination != null) {
        Navigator.of(context).pushNamed(destination);
        return;
      } else {
        Navigator.of(context).pop();
      }
    },
  );
}
