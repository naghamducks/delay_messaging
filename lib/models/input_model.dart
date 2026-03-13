import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RadioButtonModel {
  String name;
  String? helperText;
  Object value;
  final double? width;
  final double? withPer;

  RadioButtonModel({
    required this.name,
    required this.value,
    this.helperText,
    this.width,
    this.withPer,
  });
}

class GeneralModel {
  String name;
  int value;

  GeneralModel({required this.name, required this.value});
}

class ButtonModel {
  Color? color;
  String? text;
  String? destination;
  bool? isActive;
  Function()? callbackFunction;

  ButtonModel({this.text, this.color, this.isActive, this.callbackFunction, this.destination});
}



class SwitchModel {
  String label;
  bool value;
  final Function(bool)? onChanged;
  SwitchModel({required this.label, required this.value,this.onChanged});
}

class CheckBoxModel {
  String name;
  final Object value;
  final String? helperText;
  final double? width;
  final double? widthPercentage;
late final bool booleanValue;
  CheckBoxModel({required this.value, required this.name, this.helperText, this.width, this.widthPercentage, required this.booleanValue});
}