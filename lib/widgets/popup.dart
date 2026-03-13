import 'dart:ui';

import 'package:delay_messenger/models/input_model.dart';
import 'package:delay_messenger/widgets/general/fixed_button.dart';
import 'package:delay_messenger/widgets/general/my_colors.dart';
import 'package:delay_messenger/widgets/general/paddings.dart';
import 'package:delay_messenger/widgets/input_decoration.dart';
import 'package:delay_messenger/widgets/text_styles.dart';
import 'package:flutter/material.dart';

class GeneralPopup {
  final BuildContext context;
  final String? title;
  final Widget? titleWidget;
  final String? description;
  final Widget popupContent;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionPadding;
  Widget? actionButtons;

  bool? barrierDismissible;
  bool? blurBarrier;
  Color? barrierColor;
  String? barrierImage;
  bool? descriptionCentered;
  ButtonModel? cancelButtonModel;
  ButtonModel? confirmButtonModel;

  GeneralPopup({
    required this.context,
    this.title,
    this.titleWidget,
    this.description,
    required this.popupContent,
    this.actionButtons,
    this.cancelButtonModel,
    this.confirmButtonModel,
    this.contentPadding,
    this.actionPadding,
    this.barrierDismissible,
    this.blurBarrier = true,
    this.descriptionCentered = false,
    this.barrierColor,
    this.barrierImage,
  });

  Future showPopup() async {
    return showDialog(
        context: context,
        barrierDismissible: barrierDismissible ?? true,
        barrierColor: barrierColor,
        builder: (BuildContext context) {
          return blurBarrier == true
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: getPopup(),
                )
              : barrierImage != null
                  ? Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(barrierImage ?? ""),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: getPopup())
                  : getPopup();
        });
  }

  Widget getPopup() {
    return AlertDialog(
      elevation: 0,
      shape: popupBorder,
      contentPadding: contentPadding ?? popupPadding,
      actionsPadding: actionPadding ?? popupPadding,
      actionsAlignment: MainAxisAlignment.center,
      titlePadding: (title == null && titleWidget == null)
          ? EdgeInsets.zero
          : popupTitlePadding,
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: popupTitleStyle,
                )
              : Container()),
      content: popupContent,
      actions: [
        actionButtons ?? Container(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cancelButtonModel != null
                ? buildFixedButton(
                    isConfirm: false,
                    context: context,
                    color: cancelButtonModel != null
                        ? cancelButtonModel!.color
                        : MyColors.primaryColor,
                    isActive: cancelButtonModel != null
                        ? cancelButtonModel!.isActive
                        : true,
                    text: cancelButtonModel != null
                        ? cancelButtonModel!.text
                        : "Cancel",
                  )
                : Container(),
            (confirmButtonModel != null && confirmButtonModel != null)
                ? const SizedBox(
                    width: 20,
                  )
                : const SizedBox(),
            confirmButtonModel != null
                ? buildFixedButton(
                    isConfirm: true,
                    context: context,
                    color: confirmButtonModel != null
                        ? confirmButtonModel!.color
                        : MyColors.primaryColor,
                    isActive: confirmButtonModel != null
                        ? confirmButtonModel!.isActive
                        : true,
                    text: confirmButtonModel != null
                        ? confirmButtonModel!.text
                        : "Cancel",
                    callbackFunction:
                        confirmButtonModel!.callbackFunction ?? () {},
                    destination: confirmButtonModel != null
                        ? confirmButtonModel!.destination
                        : null,
                  )
                : Container(),
          ],
        )
      ],
    );
  }
}
