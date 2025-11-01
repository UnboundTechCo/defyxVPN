import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcons {
  static const String logoPath = 'assets/icons/logo.svg';
  static const String defyxCheckPath = 'assets/icons/defyx_check.svg';
  static const String defyxLoadingPath = 'assets/icons/defyx_loading.svg';
  static const String defyxStandbyPath = 'assets/icons/defyx_standby.svg';
  static const String defyxReloadPath = 'assets/icons/defyx_reload.svg';
  static const String defyxErrorPath = 'assets/icons/defyx_error.svg';

  static const String wifiPath = 'assets/icons/wifi.svg';
  static const String arrowLeftPath = 'assets/icons/arrow_left.svg';
  static const String noWifiPath = 'assets/icons/no_wifi.svg';
  static const String shieldPath = 'assets/icons/chield.svg';
  static const String sharePath = 'assets/icons/share.svg';
  static const String speedTestPath = 'assets/icons/speed.svg';
  static const String copyPath = 'assets/icons/copy.svg';
  static const String chevronLeftPath = 'assets/icons/chevron-left.svg';
  static const String shieldAnimePath = 'assets/icons/Shield.svg';
  static const String infoPath = 'assets/icons/info.svg';
  static const String checkCirclePath = 'assets/icons/check-circle.svg';

  static const String telegramPath = 'assets/icons/telegram.svg';
  static const String instagramPath = 'assets/icons/instagram.svg';
  static const String xPath = 'assets/icons/x.svg';
  static const String facebookPath = 'assets/icons/facebook.svg';
  static const String linkedinPath = 'assets/icons/linkedin.svg';

  static SvgPicture logo({double? width, double? height}) {
    return SvgPicture.asset(logoPath, width: width, height: height);
  }

  static SvgPicture defyxCheck({double? width, double? height}) {
    return SvgPicture.asset(defyxCheckPath, width: width, height: height);
  }

  static SvgPicture defyxLoading({double? width, double? height}) {
    return SvgPicture.asset(defyxLoadingPath, width: width, height: height);
  }

  static SvgPicture defyxStandby({double? width, double? height}) {
    return SvgPicture.asset(defyxStandbyPath, width: width, height: height);
  }

  static SvgPicture defyxReload({double? width, double? height}) {
    return SvgPicture.asset(defyxReloadPath, width: width, height: height);
  }

  static SvgPicture defyxError({double? width, double? height}) {
    return SvgPicture.asset(defyxErrorPath, width: width, height: height);
  }

  static SvgPicture wifi({double? width, double? height}) {
    return SvgPicture.asset(wifiPath, width: width, height: height);
  }

  static SvgPicture arrowLeft({double? width, double? height}) {
    return SvgPicture.asset(arrowLeftPath, width: width, height: height);
  }

  static SvgPicture noWifi({double? width, double? height}) {
    return SvgPicture.asset(noWifiPath, width: width, height: height);
  }

  static SvgPicture shield({double? width, double? height}) {
    return SvgPicture.asset(shieldPath, width: width, height: height);
  }

  static SvgPicture share({double? width, double? height}) {
    return SvgPicture.asset(sharePath, width: width, height: height);
  }

  static SvgPicture speedTest({double? width, double? height}) {
    return SvgPicture.asset(speedTestPath, width: width, height: height);
  }

  static SvgPicture copy({double? width, double? height}) {
    return SvgPicture.asset(copyPath, width: width, height: height);
  }

  static SvgPicture chevronLeft({double? width, double? height}) {
    return SvgPicture.asset(chevronLeftPath, width: width, height: height);
  }

  static SvgPicture info({double? width, double? height}) {
    return SvgPicture.asset(infoPath, width: width, height: height);
  }

  static SvgPicture checkCircle({double? width, double? height}) {
    return SvgPicture.asset(checkCirclePath, width: width, height: height);
  }

  static SvgPicture telegram({double? width, double? height}) {
    return SvgPicture.asset(telegramPath, width: width, height: height);
  }

  static SvgPicture instagram({double? width, double? height}) {
    return SvgPicture.asset(instagramPath, width: width, height: height);
  }

  static SvgPicture x({double? width, double? height}) {
    return SvgPicture.asset(xPath, width: width, height: height);
  }

  static SvgPicture facebook({double? width, double? height}) {
    return SvgPicture.asset(facebookPath, width: width, height: height);
  }

  static SvgPicture linkedin({double? width, double? height}) {
    return SvgPicture.asset(linkedinPath, width: width, height: height);
  }

  static Widget shieldAnime({
    double? width,
    double? height,
    List<Widget>? children,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.asset(shieldAnimePath, width: width, height: height),
        if (children != null) ...children,
      ],
    );
  }
}
