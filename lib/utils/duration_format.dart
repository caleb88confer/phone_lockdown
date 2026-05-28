String formatDurationShort(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

/// A two-line, human-readable rendering of a long cumulative duration for the
/// dashboard hero: a punchy `big` line ("3d 4h") and a plain-units `sub` line
/// ("76 hours total").
({String big, String sub}) formatDurationFriendly(Duration d) {
  final days = d.inDays;
  final hours = d.inHours.remainder(24);
  final minutes = d.inMinutes.remainder(60);

  final String big;
  if (days > 0) {
    big = '${days}d ${hours}h';
  } else if (d.inHours > 0) {
    big = '${d.inHours}h ${minutes}m';
  } else {
    big = '${d.inMinutes}m';
  }

  final String sub;
  if (d.inHours > 0) {
    sub = '${d.inHours} hours total';
  } else {
    sub = '${d.inMinutes} minutes total';
  }

  return (big: big, sub: sub);
}
