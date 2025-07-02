import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'src/OneSecondGame.dart';

void main() {

  runApp(GameWidget(game: OneSecondGame()));
}