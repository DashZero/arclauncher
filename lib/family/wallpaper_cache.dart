import 'dart:io';

import 'package:path/path.dart' as p;

/// Total size in bytes of the regular files directly inside [dir].
int cacheSizeBytes(Directory dir) {
  if (!dir.existsSync()) return 0;
  var total = 0;
  for (final f in dir.listSync().whereType<File>()) {
    total += f.lengthSync();
  }
  return total;
}

/// Deletes the oldest files until the directory is at most [capBytes]. Files in
/// [keep] are never deleted (the wallpaper on screen), so the cap can only be
/// exceeded by those. Returns the number of files removed.
int enforceCacheCap(Directory dir, int capBytes, {Set<String> keep = const {}}) {
  if (!dir.existsSync()) return 0;
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
  var total = files.fold<int>(0, (sum, f) => sum + f.lengthSync());
  final protected = keep.map(p.normalize).toSet();
  var removed = 0;
  for (final f in files) {
    if (total <= capBytes) break;
    if (protected.contains(p.normalize(f.path))) continue;
    total -= f.lengthSync();
    f.deleteSync();
    removed++;
  }
  return removed;
}
