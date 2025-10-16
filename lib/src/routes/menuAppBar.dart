import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Menuappbar extends StatefulWidget implements PreferredSizeWidget {
  const Menuappbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(75); // AppBar 높이 지정

  @override
  State<Menuappbar> createState() => _MenuappbarState();
}

class _MenuappbarState extends State<Menuappbar> {

  int _hearts = 100;

  @override
  void initState() {
    super.initState();
    _loadHearts();
  }

  Future<void> _loadHearts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hearts = prefs.getInt('hearts') ?? 100;
    });
  }

  Future<void> _decreaseHeart() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hearts -= 1;
      if (_hearts <= 0) _hearts = 100;
      prefs.setInt('hearts', _hearts);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 3,
      centerTitle: true,
      leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                  'assets/menu/common/Heart.svg'),
              Positioned(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$_hearts',
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'moulpali',
                        letterSpacing: 0,
                        fontSize: 16
                      ),
                    ),
                  ))
            ],
          )
      ),
      actions: [
        Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () {

                  },
                  child: SvgPicture.asset('assets/menu/common/Setting.svg'),
                )
              ],
            ),
        ),

      ],
    );
  }
}
