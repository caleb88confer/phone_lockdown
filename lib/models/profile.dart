import 'dart:convert';
import 'package:uuid/uuid.dart';

class Profile {
  final String id;
  String name;
  int iconCodePoint;
  List<String> blockedAppPackages;
  List<String> blockedWebsites;

  bool get isDefault => name == 'Default';

  Profile({
    String? id,
    required this.name,
    this.iconCodePoint = 0xe7f5, // Icons.notifications_off
    List<String>? blockedAppPackages,
    List<String>? blockedWebsites,
  })  : id = id ?? const Uuid().v4(),
        blockedAppPackages = blockedAppPackages ?? [],
        blockedWebsites = blockedWebsites ?? [];

  factory Profile.defaultProfile() {
    return Profile(name: 'Default');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'blockedAppPackages': blockedAppPackages,
        'blockedWebsites': blockedWebsites,
      };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      blockedAppPackages: List<String>.from(json['blockedAppPackages'] ?? []),
      blockedWebsites: List<String>.from(json['blockedWebsites'] ?? []),
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
