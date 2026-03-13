import 'dart:convert';

import 'package:flutter/services.dart';

class MyColors {
  ///list of chart colors
  static List<Color> graphColors = [graphColor1, graphColor2, graphColor3, graphColor4];

  //main Colors
  static Color backgroundColor = const Color(0xffF6FAFF);
  static Color white = const Color(0xFFFFFFFF);
  static Color black = const Color(0xFF000000);
  static const Color black2 = Color(0xFF162149);
  static const Color inputInnerColor = Color(0xFFFBFBFB);
  static const Color chartBarTitleColor = Color(0xFF162149);


  //grey Colors
  static const Color mainGreyColor=Color(0xFFA2A6B5);
  static const Color footerShadowColor = Color(0x0F000000);
  static const Color inputInnerTextHint = Color(0xFFA8A9A9);
  static Color descriptionColor = const Color(0xFFA8A8A8);
  static const Color disabledColor = Color(0xFFCACED0);
  static const Color disabledColor2 = Color(0xFFD8D8D8);
  static const Color inputInnerText = Color(0xFF424242);
  static const Color switchtrackColor = Color(0x7E858E99);
  static const Color listViewSeparatorColor = Color(0x4D7e858e);
  static const Color lightGrey1 = Color(0xFF667085);
  static const Color lightGrey2 = Color(0xFFA1A6B6);
  static const Color lightGrey3 = Color(0xFF707070);
  static const Color lightGrey4 = Color(0xFF737991);
  static const Color lightGreySelected = Color(0x33C4C4C4);


  //error colors
  static const Color errorColor = Color(0xffea071d);
  static Color errorMessageColor = const Color(0xFF6E2727);


  //Success
  static const Color successColor = Color(0xff1DB05F);
  static const Color lightSuccessColor = Color(0xffD9FFE9);

  //warning
  static const Color warningColor = Color(0xffFFB800);

  //primary colors
  static Color primaryColor = const Color(0xFF0B79F4);
  static Color appBackgroundColor = const Color(0xfffafcff);
  static Color lightPrimaryColor= const Color(0xFF3695FF);
  static Color lightPrimaryColor1= const Color(0xFFDAE8FB);
  static Color lightPrimaryColor2= const Color(0xFFE7F1FE);
  static Color lightPrimaryColor3= const Color(0xFFF0F7FF);
  static Color lightPrimaryColor4= const Color(0xFFF6FAFF);
  static Color darkPrimaryColor1= const Color(0xFF0C6BD6);
  static Color darkPrimaryColor2= const Color(0xFF085CCD);
  static Color darkPrimaryColor3= const Color(0xFF162149);
  static Color darkPrimaryColor4= const Color(0xFF032449);


  //check with ux/ui
  // static Color lightPrimary = const Color(0xFF3695FF);


  //others
  static Color shadowColor = const Color(0xFF0b79f4).withOpacity(0.25);
  static Color tooltipBackgroundColor = const Color(0xFF032449).withOpacity(0.9);


  //action button
  static const Color actionButtonBackgroundDismissColor = Color(0xffffffff); // the color of cancel/dismiss button
  static const Color actionButtonTextConfirmColor = Color.fromRGBO(255, 255, 255, 1); // the color of  titles of Next/Save button
  static const Color disabledButtonColor = Color(0xFFCACED0);

  //chart Colors
  static Color graphColor1 = const Color(0xFF8035DF);
  static Color lightPink = const Color(0xFFEBE3FC);
  static Color graphColor2 = const Color(0xFFFF8E26);
  static Color graphColor3 = const Color(0xFF12D8AA);
  static Color graphColor4 = const Color(0xFF0B79F4);
  //icons colors
  static Color iconColor1 = const Color(0x3335abdf);
  static Color iconColor2 = const Color(0x33992692);
  static Color iconColor3 = const Color(0x33784f99);
  static Color iconColor4 = const Color(0x33de0000);








  static loadFromJson(Map<String, dynamic> json) {
    primaryColor = json['primary_color']!=null?Color(int.parse(json['primary_color'], radix: 16)):primaryColor;
    backgroundColor =json['background_color']!=null?Color(int.parse(json['background_color'], radix: 16)):backgroundColor;
    lightPrimaryColor =json['light_primary_color']!=null?Color(int.parse(json['light_primary_color'], radix: 16)):lightPrimaryColor;
    lightPrimaryColor1 =json['light_primary_color1']!=null?Color(int.parse(json['light_primary_color1'], radix: 16)):lightPrimaryColor1;
    lightPrimaryColor2 =json['light_primary_color2']!=null?Color(int.parse(json['light_primary_color2'], radix: 16)):lightPrimaryColor2;
    lightPrimaryColor3 =json['light_primary_color3']!=null?Color(int.parse(json['light_primary_color3'], radix: 16)):lightPrimaryColor3;
    lightPrimaryColor4 =json['light_primary_color4']!=null?Color(int.parse(json['light_primary_color4'], radix: 16)):lightPrimaryColor4;
    darkPrimaryColor1 =json['dark_primary_color1']!=null?Color(int.parse(json['dark_primary_color1'], radix: 16)):darkPrimaryColor1;
    darkPrimaryColor2 =json['dark_primary_color2']!=null?Color(int.parse(json['dark_primary_color2'], radix: 16)):darkPrimaryColor2;
    darkPrimaryColor3 =json['dark_primary_color3']!=null?Color(int.parse(json['dark_primary_color3'], radix: 16)):darkPrimaryColor3;
    darkPrimaryColor4 =json['dark_primary_color4']!=null?Color(int.parse(json['dark_primary_color4'], radix: 16)):darkPrimaryColor4;
    graphColor1 =json['graph_color_1']!=null ?Color(int.parse(json['graph_color_1'], radix: 16)):graphColor1;
    graphColor2 =json['graph_color_2']!=null ?Color(int.parse(json['graph_color_2'], radix: 16)):graphColor2;
    graphColor3 = json['graph_color_3']!=null?Color(int.parse(json['graph_color_3'], radix: 16)):graphColor3;
    graphColor4 = json['graph_color_4']!=null?Color(int.parse(json['graph_color_4'], radix: 16)):graphColor4;
    shadowColor =json['primary_color']!=null?Color(int.parse(json['primary_color'], radix: 16)).withOpacity(0.25):primaryColor.withOpacity(0.25);
   tooltipBackgroundColor =json['dark_primary_color4']!=null?Color(int.parse(json['dark_primary_color4'], radix: 16)).withOpacity(0.9):darkPrimaryColor4.withOpacity(0.9);
  }



  static Future<void> loadFromFile(String? file) async {
    // set default to dev if nothing was passed
    String colorFile = file ?? "colors";

    // load the json file
    String contents = await rootBundle.loadString(
      'assets/config/$colorFile.json',
    );

    // decode our json
    var json = jsonDecode(contents);
    MyColors.loadFromJson(json);
  }
}
