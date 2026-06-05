import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VibeAssetIcons {
  static const arrowBack = 'assets/icons/arrow_back.svg';
  static const arrowRight = 'assets/icons/arrow_right.svg';
  static const bell = 'assets/icons/bell.svg';
  static const blocked = 'assets/icons/blocked.svg';
  static const camera = 'assets/icons/camera.svg';
  static const filter = 'assets/icons/filter.svg';
  static const group = 'assets/icons/group.svg';
  static const invite = 'assets/icons/invite.svg';
  static const loopLogo = 'assets/icons/loop_logo.svg';
  static const mailbox = 'assets/icons/mailbox.svg';
  static const moon = 'assets/icons/moon.svg';
  static const paperclip = 'assets/icons/paperclip.svg';
  static const pause = 'assets/icons/pause.svg';
  static const photos = 'assets/icons/photos.svg';
  static const refresh = 'assets/icons/refresh.svg';
  static const screenshot = 'assets/icons/screenshot.svg';
  static const send = 'assets/icons/send.svg';
  static const settings = 'assets/icons/settings.svg';
  static const share = 'assets/icons/share.svg';
  static const shield = 'assets/icons/shield.svg';
}

class VibeSvgIcon extends StatelessWidget {
  const VibeSvgIcon(
    this.asset, {
    super.key,
    required this.size,
    this.color,
  });

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
