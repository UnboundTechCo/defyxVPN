/// Full country names for plan locations.
///
/// The backend writes a location's country as free text: an ISO code (`DE`),
/// one of its plan country names (`germany`, `south_korea`, `usa`) or
/// anything else. Ones this list doesn't know are shown as written.
abstract class CountryNames {
  /// [location]'s full country name in [languageCode] (English when that
  /// language has none), or null for a location this list doesn't know.
  static String? of(String location, String languageCode) {
    final code = _codes[_key(location)];
    if (code == null) return null;
    final names = _names[code]!;
    return names[languageCode] ?? names['en'];
  }

  /// [location]'s ISO country code, or null for a location this list doesn't
  /// know.
  static String? codeOf(String location) => _codes[_key(location)];

  /// The flag image for [location]: its country's flag, or the app's
  /// unknown-country flag when there is none.
  static String flagAsset(String location) {
    final code = codeOf(location);
    final flag = code != null && flagCodes.contains(code) ? code : 'xx';
    return 'assets/flags/$flag.svg';
  }

  /// The countries with a flag in assets/flags.
  static const flagCodes = {
    'at', 'au', 'az', 'be', 'ca', 'ch', 'cz', 'de', 'dk', 'ee', 'es', //
    'fi', 'fr', 'gb', 'hr', 'hu', 'in', 'ir', 'it', 'jp', 'lv', 'nl', //
    'no', 'pl', 'pt', 'ro', 'rs', 'ru', 'se', 'sg', 'sk', 'tr', 'us', //
  };

  static String _key(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'[\s\-.]+'), '_');

  /// Every spelling this list accepts, by its country code.
  static final Map<String, String> _codes = {
    for (final MapEntry(key: code, value: names) in _names.entries) ...{
      code: code,
      _key(names['en']!): code,
    },
    ..._aliases,
  };

  /// Other spellings: the backend's plan countries and common names.
  static const _aliases = <String, String>{
    'usa': 'us',
    'america': 'us',
    'united_states_of_america': 'us',
    'uk': 'gb',
    'britain': 'gb',
    'great_britain': 'gb',
    'england': 'gb',
    'holland': 'nl',
    'the_netherlands': 'nl',
    'korea': 'kr',
    'czech_republic': 'cz',
    'turkiye': 'tr',
    'türkiye': 'tr',
    'uae': 'ae',
    'emirates': 'ae',
  };

  static const _names = <String, Map<String, String>>{
    'ae': {
      'en': 'United Arab Emirates',
      'fa': 'امارات متحده عربی',
      'ru': 'ОАЭ',
      'zh': '阿联酋',
    },
    'am': {'en': 'Armenia', 'fa': 'ارمنستان', 'ru': 'Армения', 'zh': '亚美尼亚'},
    'at': {'en': 'Austria', 'fa': 'اتریش', 'ru': 'Австрия', 'zh': '奥地利'},
    'au': {
      'en': 'Australia',
      'fa': 'استرالیا',
      'ru': 'Австралия',
      'zh': '澳大利亚',
    },
    'az': {
      'en': 'Azerbaijan',
      'fa': 'جمهوری آذربایجان',
      'ru': 'Азербайджан',
      'zh': '阿塞拜疆',
    },
    'be': {'en': 'Belgium', 'fa': 'بلژیک', 'ru': 'Бельгия', 'zh': '比利时'},
    'bg': {'en': 'Bulgaria', 'fa': 'بلغارستان', 'ru': 'Болгария', 'zh': '保加利亚'},
    'br': {'en': 'Brazil', 'fa': 'برزیل', 'ru': 'Бразилия', 'zh': '巴西'},
    'ca': {'en': 'Canada', 'fa': 'کانادا', 'ru': 'Канада', 'zh': '加拿大'},
    'ch': {'en': 'Switzerland', 'fa': 'سوئیس', 'ru': 'Швейцария', 'zh': '瑞士'},
    'cn': {'en': 'China', 'fa': 'چین', 'ru': 'Китай', 'zh': '中国'},
    'cz': {'en': 'Czechia', 'fa': 'جمهوری چک', 'ru': 'Чехия', 'zh': '捷克'},
    'de': {'en': 'Germany', 'fa': 'آلمان', 'ru': 'Германия', 'zh': '德国'},
    'dk': {'en': 'Denmark', 'fa': 'دانمارک', 'ru': 'Дания', 'zh': '丹麦'},
    'ee': {'en': 'Estonia', 'fa': 'استونی', 'ru': 'Эстония', 'zh': '爱沙尼亚'},
    'es': {'en': 'Spain', 'fa': 'اسپانیا', 'ru': 'Испания', 'zh': '西班牙'},
    'fi': {'en': 'Finland', 'fa': 'فنلاند', 'ru': 'Финляндия', 'zh': '芬兰'},
    'fr': {'en': 'France', 'fa': 'فرانسه', 'ru': 'Франция', 'zh': '法国'},
    'gb': {
      'en': 'United Kingdom',
      'fa': 'بریتانیا',
      'ru': 'Великобритания',
      'zh': '英国',
    },
    'ge': {'en': 'Georgia', 'fa': 'گرجستان', 'ru': 'Грузия', 'zh': '格鲁吉亚'},
    'hk': {'en': 'Hong Kong', 'fa': 'هنگ کنگ', 'ru': 'Гонконг', 'zh': '香港'},
    'hr': {'en': 'Croatia', 'fa': 'کرواسی', 'ru': 'Хорватия', 'zh': '克罗地亚'},
    'hu': {'en': 'Hungary', 'fa': 'مجارستان', 'ru': 'Венгрия', 'zh': '匈牙利'},
    'in': {'en': 'India', 'fa': 'هند', 'ru': 'Индия', 'zh': '印度'},
    'ir': {'en': 'Iran', 'fa': 'ایران', 'ru': 'Иран', 'zh': '伊朗'},
    'it': {'en': 'Italy', 'fa': 'ایتالیا', 'ru': 'Италия', 'zh': '意大利'},
    'jp': {'en': 'Japan', 'fa': 'ژاپن', 'ru': 'Япония', 'zh': '日本'},
    'kr': {
      'en': 'South Korea',
      'fa': 'کره جنوبی',
      'ru': 'Южная Корея',
      'zh': '韩国',
    },
    'kz': {
      'en': 'Kazakhstan',
      'fa': 'قزاقستان',
      'ru': 'Казахстан',
      'zh': '哈萨克斯坦',
    },
    'lt': {'en': 'Lithuania', 'fa': 'لیتوانی', 'ru': 'Литва', 'zh': '立陶宛'},
    'lv': {'en': 'Latvia', 'fa': 'لتونی', 'ru': 'Латвия', 'zh': '拉脱维亚'},
    'mx': {'en': 'Mexico', 'fa': 'مکزیک', 'ru': 'Мексика', 'zh': '墨西哥'},
    'nl': {'en': 'Netherlands', 'fa': 'هلند', 'ru': 'Нидерланды', 'zh': '荷兰'},
    'no': {'en': 'Norway', 'fa': 'نروژ', 'ru': 'Норвегия', 'zh': '挪威'},
    'pl': {'en': 'Poland', 'fa': 'لهستان', 'ru': 'Польша', 'zh': '波兰'},
    'pt': {'en': 'Portugal', 'fa': 'پرتغال', 'ru': 'Португалия', 'zh': '葡萄牙'},
    'ro': {'en': 'Romania', 'fa': 'رومانی', 'ru': 'Румыния', 'zh': '罗马尼亚'},
    'rs': {'en': 'Serbia', 'fa': 'صربستان', 'ru': 'Сербия', 'zh': '塞尔维亚'},
    'ru': {'en': 'Russia', 'fa': 'روسیه', 'ru': 'Россия', 'zh': '俄罗斯'},
    'se': {'en': 'Sweden', 'fa': 'سوئد', 'ru': 'Швеция', 'zh': '瑞典'},
    'sg': {'en': 'Singapore', 'fa': 'سنگاپور', 'ru': 'Сингапур', 'zh': '新加坡'},
    'sk': {'en': 'Slovakia', 'fa': 'اسلواکی', 'ru': 'Словакия', 'zh': '斯洛伐克'},
    'tr': {'en': 'Turkey', 'fa': 'ترکیه', 'ru': 'Турция', 'zh': '土耳其'},
    'ua': {'en': 'Ukraine', 'fa': 'اوکراین', 'ru': 'Украина', 'zh': '乌克兰'},
    'us': {'en': 'United States', 'fa': 'آمریکا', 'ru': 'США', 'zh': '美国'},
  };
}
