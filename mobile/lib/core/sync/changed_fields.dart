/// Bir güncellemede GERÇEKTEN değişen alanları bulur.
///
/// Neden gerekli: kuyruğa yazılan yük kaydın TAMAMINI taşıyor. Sunucu
/// yalnızca yüke bakarak hangi alanın kullanıcı tarafından değiştirildiğini,
/// hangisinin sadece eski değeriyle birlikte taşındığını ayıramıyor.
///
/// Bu ayrım olmadan her sürüm uyuşmazlığı elle çözülmesi gereken bir
/// çakışmaya dönüşüyordu — oysa çakışmaların çoğu gerçek çakışma değil:
/// ofis müşterinin telefonunu, saha görevlisi notunu değiştirmişse kimse
/// kimsenin işini ezmiyor. Sunucu bunu ancak iki tarafın hangi alanlara
/// dokunduğunu bilirse anlayabiliyor.
///
/// Bkz. backend `DetectsSyncConflicts`.
library;

/// [eski] ile [yeni] arasında değeri farklı olan anahtarlar.
///
/// [eski] null ise (kayıt yerelde bulunamadıysa) tüm anahtarlar değişmiş
/// sayılır. Bu, birleştirmenin reddedilmesine yol açar — bilmediğimiz bir
/// durumda çakışma göstermek, yanlış birleştirmekten iyidir.
List<String> degisenAlanlar(
  Map<String, dynamic>? eski,
  Map<String, dynamic> yeni,
) {
  if (eski == null) return yeni.keys.toList();

  final degisen = <String>[];
  for (final girdi in yeni.entries) {
    if (!_esit(eski[girdi.key], girdi.value)) {
      degisen.add(girdi.key);
    }
  }
  return degisen;
}

/// Liste alanları (ör. etiketler) referansla değil İÇERİKLE karşılaştırılır.
///
/// Aksi halde her kaydetmede yeni bir liste nesnesi üretildiği için alan
/// "değişti" görünür, sunucu tarafında gereksiz çakışma üretirdi.
bool _esit(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_esit(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
