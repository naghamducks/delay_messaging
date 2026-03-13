import 'package:flutter/material.dart';

final globalRadius = BorderRadius.circular(10);
final iconGlobalRadius = BorderRadius.circular(5);
const globalRadiusBorder = Radius.circular(10);
const double appBarHeight = 60;

// pagination
final paginationButtonRadius = BorderRadius.circular(5);
// grid view
const double gridViewVerticalSpacing = 16;
const double gridViewHorizontalSpacing = 16;

double getGridViewDefaultWidth(BuildContext context) {
  return double.infinity;
}

// popupmenu
const Size popupMenuIconSize = Size(20, 20);

// small highlighted titles
final smallHighlightedTextRadius = BorderRadius.circular(10);

getButtonRadiusWidth() {
  return 1;
}

getInputHeight() {
  return 95;
}

getFooterHeight() {
  return 85;
}

getCardHeight(context) {
  return (MediaQuery.of(context).size.height - appBarHeight - getFooterHeight());
}

getPageHeight(context) {
  return (MediaQuery.of(context).size.height - appBarHeight);
}

getButtonHeight() {
  return 45;
}

getCounterInputHeight() {
  return 100;
}

getCounterMinWidth() {
  return 290;
}

getNavigationHeaderHeight(bool openNavigator){

  return openNavigator? 70:0;
}

getNavigationFooterHeight(bool openNavigator){

  return openNavigator? 107:65;
  // return openNavigator? 107:64;
}

