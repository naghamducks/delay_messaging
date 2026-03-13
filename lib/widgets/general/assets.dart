import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract class Assets {
  static const String package = "dtn_messenger";

  static AssetImage buildIconAssetsImage(String path) {
    return AssetImage(package: package, path);
  }

  static Image buildAssetImage(String path, {Color? color, double? width, double? height, Alignment? alignment}) {
    return Image.asset(
      package: package,
      path,
      color: color,
      height: height ?? 20,
      width: width ?? 20,
      alignment: alignment ?? Alignment.center,
    );
  }

  static SvgPicture buildAssetSVG(String path, {Color? color, double? width, double? height, Alignment? alignment}) {
    return SvgPicture.asset(
      package: package,
      path,
      color: color,
      height: height ?? 20,
      width: width ?? 20,
      alignment: alignment ?? Alignment.center,
    );
  }

  static Widget buildAssetWithPackage(String path, {Color? color, double? width, double? height, Alignment? alignment}) {
    return path.endsWith("svg")?SvgPicture.asset(
      package: package,
      path,
      color: color,
      height: height ?? 20,
      width: width ?? 20,
      alignment: alignment ?? Alignment.center,
    ): Image.asset(
      package: package,
      path,
      color: color,
      height: height ?? 20,
      width: width ?? 20,
      alignment: alignment ?? Alignment.center,
    );
  }

  static Widget buildAsset(String path, {Color? color, double? width, double? height, Alignment? alignment,bool? libraryPackage=false}) {
    return path.endsWith("svg")?SvgPicture.asset(
      package:null,
      path,
      color: color,
      height: height ?? 20,
      width: width ?? 20,
      fit: BoxFit.scaleDown,
      alignment: alignment ?? Alignment.center,
    ): Image.asset(
      path,
      package: libraryPackage==true?package:null,
      color: color,
      height: height ?? 20,
      width: width ?? 20,
      alignment: alignment ?? Alignment.center,
    );
  }

}
