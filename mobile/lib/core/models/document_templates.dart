/// Belge metinleri için hazır şablonlar.
///
/// Saha işletmecisinin her teklifte "ödeme koşulları" cümlesini sıfırdan
/// yazması beklenemez; boş bir alan gördüğünde çoğu kullanıcı orayı boş
/// bırakıyor ve belge yarım kalıyor. Buradaki hazır ifadeler tek dokunuşla
/// seçilir, sonra istenirse serbestçe düzenlenir — şablon bir zorunluluk
/// değil, başlangıç noktasıdır.
///
/// Metinler bilinçli olarak sektör-nötr tutulmuştur (elektrik, kamera,
/// bilgisayar servisi hepsi aynı ifadeleri kullanabilsin).
abstract final class DocumentTemplates {
  /// Belgenin giriş/hitap metni. `{musteri}` yer tutucusu belge
  /// hazırlanırken müşteri adıyla değiştirilir.
  static const intros = <DocumentTemplate>[
    DocumentTemplate(
      label: 'Standart',
      text:
          'Sayın Yetkili,\n'
          'Talebiniz doğrultusunda hazırlanan fiyat teklifimiz aşağıda '
          'bilgilerinize sunulmuştur. Belirtilen fiyatlar, geçerlilik '
          'tarihine kadar bağlayıcıdır. Konuyla ilgili sorularınız için her '
          'zaman ulaşabilirsiniz. Saygılarımızla.',
    ),
    DocumentTemplate(
      label: 'Keşif sonrası',
      text:
          'Sayın Yetkili,\n'
          'Yerinde yaptığımız keşif ve inceleme sonucunda, ihtiyacınıza en '
          'uygun çözüm için hazırladığımız fiyat teklifimiz aşağıdadır. '
          'Kullanılacak malzemeler ve işçilik kalemleri ayrıntılı olarak '
          'belirtilmiştir. Saygılarımızla.',
    ),
    DocumentTemplate(
      label: 'Bakım / periyodik hizmet',
      text:
          'Sayın Yetkili,\n'
          'Mevcut sisteminizin periyodik bakımı ve sürekliliği için '
          'hazırladığımız hizmet teklifimiz aşağıda bilgilerinize '
          'sunulmuştur. Bakım kapsamı dışındaki arızalar ayrıca '
          'fiyatlandırılır. Saygılarımızla.',
    ),
    DocumentTemplate(
      label: 'Arıza / onarım',
      text:
          'Sayın Yetkili,\n'
          'Bildirdiğiniz arıza için yapılan inceleme sonucunda tespit edilen '
          'işlemler ve kullanılacak parçalar aşağıda listelenmiştir. '
          'Onayınız sonrasında işleme başlanacaktır. Saygılarımızla.',
    ),
    DocumentTemplate(
      label: 'Kısa ve resmi',
      text:
          'Sayın Yetkili,\n'
          'Talebiniz üzerine hazırlanan fiyat teklifimiz aşağıdadır. '
          'Saygılarımızla.',
    ),
  ];

  static const paymentTerms = <DocumentTemplate>[
    DocumentTemplate(
      label: 'Peşin',
      text: 'İş bitiminde peşin, nakit veya havale/EFT ile.',
    ),
    DocumentTemplate(
      label: '%50 avans',
      text: '%50 sipariş onayında avans, %50 teslimatta.',
    ),
    DocumentTemplate(
      label: '%40 - %40 - %20',
      text:
          '%40 sipariş onayında, %40 malzeme teslimatında, %20 devreye alma '
          'sonrasında.',
    ),
    DocumentTemplate(
      label: '30 gün vadeli',
      text: 'Fatura tarihinden itibaren 30 gün vadeli.',
    ),
    DocumentTemplate(
      label: 'Kredi kartı / taksit',
      text: 'Nakit, havale/EFT veya kredi kartına taksit imkânı.',
    ),
  ];

  static const deliveryTimes = <DocumentTemplate>[
    DocumentTemplate(label: 'Aynı gün', text: 'Onay sonrası aynı gün içinde.'),
    DocumentTemplate(
      label: '3 iş günü',
      text: 'Sipariş onayından sonra 3 iş günü içinde.',
    ),
    DocumentTemplate(
      label: '5 iş günü',
      text: 'Sipariş onayından sonra 5 iş günü içinde.',
    ),
    DocumentTemplate(
      label: '10-15 iş günü',
      text: 'Sipariş onayından sonra 10-15 iş günü içinde.',
    ),
    DocumentTemplate(
      label: 'Stok durumuna göre',
      text: 'Stok durumuna göre planlanır; onay sonrası bilgi verilir.',
    ),
  ];

  static const warrantyTerms = <DocumentTemplate>[
    DocumentTemplate(
      label: '2 yıl ürün + 1 yıl işçilik',
      text: '2 yıl ürün garantisi, 1 yıl işçilik garantisi.',
    ),
    DocumentTemplate(
      label: 'Üretici garantisi',
      text: 'Tüm ürünler üretici garantisi kapsamındadır.',
    ),
    DocumentTemplate(
      label: '1 yıl işçilik',
      text: 'Yapılan işçilik 1 yıl garantilidir.',
    ),
    DocumentTemplate(
      label: '6 ay onarım garantisi',
      text: 'Yapılan onarım ve değişen parçalar 6 ay garantilidir.',
    ),
    DocumentTemplate(
      label: 'Kullanıcı hatası hariç',
      text:
          'Garanti; kullanıcı hatası, sıvı teması ve yetkisiz müdahale '
          'durumlarını kapsamaz.',
    ),
  ];

  /// Serbest not alanı için sık kullanılan ifadeler.
  static const notes = <DocumentTemplate>[
    DocumentTemplate(
      label: 'Montaj dahil',
      text:
          'Fiyatlarımıza montaj, kablolama ve devreye alma dahildir. '
          'Çalışma alanındaki elektrik altyapısının hazır olması '
          'gerekmektedir.',
    ),
    DocumentTemplate(
      label: 'Nakliye hariç',
      text: 'Nakliye ve şehir dışı ulaşım bedeli fiyata dahil değildir.',
    ),
    DocumentTemplate(
      label: 'Keşif şartlı',
      text:
          'Fiyatlar yerinde yapılan keşfe göre hazırlanmıştır; sahada '
          'öngörülemeyen ek işler çıkması hâlinde ayrıca bilgi verilir.',
    ),
    DocumentTemplate(
      label: 'Eğitim dahil',
      text:
          'Teslim sonrası sistem kullanımına dair personel eğitimi '
          'tarafımızca ücretsiz verilir.',
    ),
    DocumentTemplate(
      label: 'Kur farkı',
      text:
          'Döviz kurundaki değişimler nedeniyle fiyatlar, geçerlilik '
          'tarihinden sonra güncellenebilir.',
    ),
  ];
}

/// Tek bir hazır metin: listede görünen kısa etiket ve belgeye giren metin.
class DocumentTemplate {
  const DocumentTemplate({required this.label, required this.text});

  final String label;
  final String text;
}
