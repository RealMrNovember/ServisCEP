import 'package:flutter/material.dart';

/// İş durumları — bkz. docs/02 § İş Durumları.
const jobStatusLabels = {
  'TALEP': 'Talep',
  'PLANLANDI': 'Planlandı',
  'DEVAM_EDIYOR': 'Devam Ediyor',
  'BEKLEMEDE': 'Beklemede',
  'TAMAMLANDI': 'Tamamlandı',
  'IPTAL': 'İptal',
};

const jobStatusColors = {
  'TALEP': Colors.blueGrey,
  'PLANLANDI': Colors.indigo,
  'DEVAM_EDIYOR': Colors.orange,
  'BEKLEMEDE': Colors.amber,
  'TAMAMLANDI': Colors.green,
  'IPTAL': Colors.red,
};

const jobPriorityLabels = {'YUKSEK': 'Yüksek', 'NORMAL': 'Normal', 'DUSUK': 'Düşük'};

const jobPriorityColors = {'YUKSEK': Colors.red, 'NORMAL': Colors.blue, 'DUSUK': Colors.grey};

/// Hazır iş türü kataloğu — bkz. docs/02 § İş Türleri.
const jobTypeCatalog = {
  'Elektrik': ['Arıza', 'Tesisat', 'Aydınlatma', 'Priz', 'Sigorta', 'Kablo', 'Montaj', 'Bakım'],
  'Güvenlik Sistemleri': [
    'IP Kamera',
    'Analog Kamera',
    'DVR',
    'NVR',
    'Alarm',
    'İnterkom',
    'Access Control',
    'Kamera bakımı',
    'Kamera arızası',
    'Kamera kurulumu',
  ],
  'Bilgisayar': [
    'Format',
    'Windows kurulumu',
    'SSD değişimi',
    'RAM değişimi',
    'Donanım arızası',
    'Yazılım kurulumu',
    'Virüs temizleme',
    'Bakım',
  ],
  'Diğer': ['Network', 'Diğer'],
};
