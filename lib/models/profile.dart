import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../constants.dart';

class Profile {
  final String id;
  String name;
  int colorValue;
  List<String> blockedAppPackages;
  List<String> blockedWebsites;
  String? unlockCode;
  int failsafeMinutes;

  bool get isDefault => name == 'Default';

  Profile({
    String? id,
    required this.name,
    this.colorValue = 0xFFFFB800, // Signature Gold
    List<String>? blockedAppPackages,
    List<String>? blockedWebsites,
    this.unlockCode,
    this.failsafeMinutes = kDefaultFailsafeMinutes,
  })  : id = id ?? const Uuid().v4(),
        blockedAppPackages = blockedAppPackages ?? [],
        blockedWebsites = blockedWebsites ?? [];

  factory Profile.defaultProfile() {
    return Profile(name: 'Default');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'blockedAppPackages': blockedAppPackages,
        'blockedWebsites': blockedWebsites,
        'unlockCode': unlockCode,
        'failsafeMinutes': failsafeMinutes,
      };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: (json['colorValue'] as int?) ??
          (json.containsKey('iconCodePoint') ? 0xFFFFB800 : 0xFFFFB800),
      blockedAppPackages: List<String>.from(json['blockedAppPackages'] ?? []),
      blockedWebsites: List<String>.from(json['blockedWebsites'] ?? []),
      unlockCode: json['unlockCode'] as String?,
      failsafeMinutes: (json['failsafeMinutes'] as int?) ?? kDefaultFailsafeMinutes,
    );
  }

  static String encodeList(List<Profile> profiles) {
    return jsonEncode(profiles.map((p) => p.toJson()).toList());
  }

  static List<Profile> decodeList(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    return list.map((e) => Profile.fromJson(e as Map<String, dynamic>)).toList();
  }
}
