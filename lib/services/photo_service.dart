import 'package:photo_manager/photo_manager.dart';
import '../models/photo.dart';
import '../models/photo_section.dart';

class PhotoService {
  static const List<int> _picsumIds = [
    1015, 1018, 1020, 1024, 1025, 1027, 1029, 1033, 1035, 1036,
    1037, 1038, 1039, 1040, 1041, 1043, 1045, 1047, 1048, 1050,
    1051, 1053, 1054, 1056, 1059, 1060, 1062, 1065, 1066, 1067,
    1069, 1070, 1071, 1073, 1074, 1075, 1076, 1077, 1078, 1080,
    1081, 1082, 1083, 1084, 110, 111, 112, 113, 114, 116,
    117, 118, 119, 120, 122, 123, 124, 125, 127, 128,
  ];
  static const List<double> _ratioPool = [
    1.5, 1.5, 1.5, 1.5,
    1.333, 1.333, 1.333,
    1.778, 1.778,
    1.0, 1.0,
    0.75, 0.75, 0.75,
    0.667, 0.667,
    0.5625,
  ];

  static Future<PermissionState> requestPermission() =>
      PhotoManager.requestPermissionExtend();

  static List<Photo> loadFake({int count = 300, int seed = 42}) {
    int s = seed;
    double rand() {
      s = (s + 0x6D2B79F5) & 0xFFFFFFFF;
      var t = ((s ^ (s >>> 15)) * (s | 1)) & 0xFFFFFFFF;
      t = (t ^ (t + (((t ^ (t >>> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF;
      return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 0xFFFFFFFF;
    }
    final now = DateTime.now();
    final out = <Photo>[];
    for (var i = 0; i < count; i++) {
      final ratio = _ratioPool[(rand() * _ratioPool.length).floor()];
      const base = 800;
      final w = base;
      final h = (base / ratio).round();
      final picsumId = _picsumIds[i % _picsumIds.length];
      final r = rand();
      int dayOffset;
      final minOff = (rand() * 1440).floor();
      if (r < 0.04) {
        dayOffset = 0;
      } else if (r < 0.10) {
        dayOffset = 1;
      } else if (r < 0.20) {
        dayOffset = 2 + (rand() * 5).floor();
      } else if (r < 0.45) {
        dayOffset = 7 + (rand() * 23).floor();
      } else if (r < 0.75) {
        dayOffset = 30 + (rand() * 60).floor();
      } else {
        dayOffset = 90 + (rand() * 275).floor();
      }
      out.add(FakePhoto(
        id: 'fake_$i',
        width: w,
        height: h,
        dateTaken: now
            .subtract(Duration(days: dayOffset))
            .subtract(Duration(minutes: minOff)),
        picsumId: picsumId,
      ));
    }
    out.sort((a, b) => b.dateTaken.compareTo(a.dateTaken));
    return out;
  }

  static List<PhotoSection> bucketize(List<Photo> photos) =>
      bucketizeAt(photos, DateTime.now());

  static List<PhotoSection> bucketizeAt(List<Photo> photos, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final todayList = <Photo>[];
    final yesterdayList = <Photo>[];
    final weekList = <Photo>[];
    final monthList = <Photo>[];
    final byMonth = <String, List<Photo>>{};
    final monthLabels = <String, String>{};

    for (final p in photos) {
      final d = p.dateTaken;
      final dd = DateTime(d.year, d.month, d.day);
      if (dd == today) {
        todayList.add(p);
      } else if (dd == yesterday) {
        yesterdayList.add(p);
      } else if (!dd.isBefore(weekStart) && dd.isBefore(today)) {
        weekList.add(p);
      } else if (d.year == now.year && d.month == now.month) {
        monthList.add(p);
      } else {
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        byMonth.putIfAbsent(key, () => []).add(p);
        monthLabels[key] = '${_monthName(d.month)} ${d.year}';
      }
    }

    final sections = <PhotoSection>[];
    if (todayList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'today',
        label: 'Today',
        sub: _weekdayDate(today),
        photos: todayList,
      ));
    }
    if (yesterdayList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'yesterday',
        label: 'Yesterday',
        sub: _weekdayDate(yesterday),
        photos: yesterdayList,
      ));
    }
    if (weekList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'week',
        label: 'This Week',
        sub: '${weekList.length} photos',
        photos: weekList,
      ));
    }
    if (monthList.isNotEmpty) {
      sections.add(PhotoSection(
        key: 'month',
        label: 'Earlier in ${_monthName(now.month)}',
        sub: '${monthList.length} photos',
        photos: monthList,
      ));
    }
    final keys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final k in keys) {
      sections.add(PhotoSection(
        key: k,
        label: monthLabels[k]!,
        sub: '${byMonth[k]!.length} photos',
        photos: byMonth[k]!,
      ));
    }
    return sections;
  }

  static String _monthName(int m) {
    const names = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    return names[m - 1];
  }

  static String _weekdayDate(DateTime d) {
    const w = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${w[d.weekday - 1]}, ${_monthName(d.month)} ${d.day}';
  }

  static FilterOptionGroup get _newestFirstFilter => FilterOptionGroup(
        imageOption: const FilterOption(),
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      );

  static Future<List<Photo>> loadDevice() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: _newestFirstFilter,
    );
    if (paths.isEmpty) return const [];
    final all = paths.first;
    final count = await all.assetCountAsync;
    if (count == 0) return const [];
    final assets = await all.getAssetListRange(start: 0, end: count);
    return assets.map<Photo>(DevicePhoto.new).toList();
  }

  /// Streams device photos in chunks (default 200) so the UI can paint the
  /// first chunk immediately and append the rest as they arrive. Explicitly
  /// ordered newest-first so chunk 1 = today / yesterday.
  static Stream<List<Photo>> loadDeviceChunked({int chunk = 200}) async* {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: _newestFirstFilter,
    );
    if (paths.isEmpty) return;
    final all = paths.first;
    final count = await all.assetCountAsync;
    if (count == 0) return;
    for (var start = 0; start < count; start += chunk) {
      final end = start + chunk < count ? start + chunk : count;
      final assets = await all.getAssetListRange(start: start, end: end);
      yield assets.map<Photo>(DevicePhoto.new).toList();
    }
  }
}
