import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../localization/app_localizations.dart';
import '../localization/language_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _loggingOut = false;

  bool _notificationsEnabled = false;
  bool _notificationLoading = false;

  final LanguageController _languageController =
      LanguageController.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationStatus();
  }

  String _t(String key) {
    return AppLocalizations.of(context).t(key);
  }

  String _localized(String key) {
    final code = _languageController.languageCode;

    const values = <String, Map<String, String>>{
      'notificationsTitle': {
        'en': 'Notifications',
        'zh': '通知',
        'es': 'Notificaciones',
        'fr': 'Notifications',
        'ar': 'الإشعارات',
        'hi': 'सूचनाएँ',
        'bn': 'বিজ্ঞপ্তি',
        'ru': 'Уведомления',
        'tr': 'Bildirimler',
        'id': 'Notifikasi',
      },
      'manageNotifications': {
        'en': 'Manage app notifications',
        'zh': '管理应用通知',
        'es': 'Gestionar las notificaciones de la aplicación',
        'fr': 'Gérer les notifications de l’application',
        'ar': 'إدارة إشعارات التطبيق',
        'hi': 'ऐप सूचनाएँ प्रबंधित करें',
        'bn': 'অ্যাপের বিজ্ঞপ্তি পরিচালনা করুন',
        'ru': 'Управление уведомлениями приложения',
        'tr': 'Uygulama bildirimlerini yönet',
        'id': 'Kelola notifikasi aplikasi',
      },
      'notificationDescription': {
        'en':
            'Mining reminders, reward updates, social tasks, and other important Power Fan Network notifications will appear here.',
        'zh':
            '挖矿提醒、奖励更新、社交任务以及其他重要的 Power Fan Network 通知将在这里显示。',
        'es':
            'Aquí aparecerán recordatorios de minería, actualizaciones de recompensas, tareas sociales y otras notificaciones importantes de Power Fan Network.',
        'fr':
            'Les rappels de minage, mises à jour des récompenses, tâches sociales et autres notifications importantes de Power Fan Network apparaîtront ici.',
        'ar':
            'ستظهر هنا تذكيرات التعدين وتحديثات المكافآت والمهام الاجتماعية وإشعارات Power Fan Network المهمة الأخرى.',
        'hi':
            'माइनिंग रिमाइंडर, रिवॉर्ड अपडेट, सोशल टास्क और Power Fan Network की अन्य महत्वपूर्ण सूचनाएँ यहाँ दिखाई देंगी।',
        'bn':
            'মাইনিং রিমাইন্ডার, রিওয়ার্ড আপডেট, সামাজিক কাজ এবং Power Fan Network-এর অন্যান্য গুরুত্বপূর্ণ বিজ্ঞপ্তি এখানে দেখা যাবে।',
        'ru':
            'Здесь будут отображаться напоминания о майнинге, обновления наград, социальные задания и другие важные уведомления Power Fan Network.',
        'tr':
            'Madencilik hatırlatmaları, ödül güncellemeleri, sosyal görevler ve diğer önemli Power Fan Network bildirimleri burada görünecek.',
        'id':
            'Pengingat mining, pembaruan hadiah, tugas sosial, dan notifikasi penting Power Fan Network lainnya akan muncul di sini.',
      },
      'notificationsEnabled': {
        'en': 'Notifications enabled',
        'zh': '通知已启用',
        'es': 'Notificaciones activadas',
        'fr': 'Notifications activées',
        'ar': 'الإشعارات مفعّلة',
        'hi': 'सूचनाएँ सक्षम हैं',
        'bn': 'বিজ্ঞপ্তি চালু আছে',
        'ru': 'Уведомления включены',
        'tr': 'Bildirimler etkin',
        'id': 'Notifikasi aktif',
      },
      'notificationsDisabled': {
        'en': 'Notifications disabled',
        'zh': '通知已禁用',
        'es': 'Notificaciones desactivadas',
        'fr': 'Notifications désactivées',
        'ar': 'الإشعارات معطّلة',
        'hi': 'सूचनाएँ अक्षम हैं',
        'bn': 'বিজ্ঞপ্তি বন্ধ আছে',
        'ru': 'Уведомления отключены',
        'tr': 'Bildirimler devre dışı',
        'id': 'Notifikasi nonaktif',
      },
      'notificationsCanSend': {
        'en':
            'POWER FAN NETWORK can send important app notifications.',
        'zh': 'POWER FAN NETWORK 可以发送重要的应用通知。',
        'es':
            'POWER FAN NETWORK puede enviar notificaciones importantes de la aplicación.',
        'fr':
            'POWER FAN NETWORK peut envoyer des notifications importantes de l’application.',
        'ar':
            'يمكن لـ POWER FAN NETWORK إرسال إشعارات مهمة للتطبيق.',
        'hi':
            'POWER FAN NETWORK महत्वपूर्ण ऐप सूचनाएँ भेज सकता है।',
        'bn':
            'POWER FAN NETWORK গুরুত্বপূর্ণ অ্যাপ বিজ্ঞপ্তি পাঠাতে পারে।',
        'ru':
            'POWER FAN NETWORK может отправлять важные уведомления приложения.',
        'tr':
            'POWER FAN NETWORK önemli uygulama bildirimleri gönderebilir.',
        'id':
            'POWER FAN NETWORK dapat mengirim notifikasi penting aplikasi.',
      },
      'allowNotifications': {
        'en':
            'Allow notifications to receive important app updates.',
        'zh': '允许通知以接收重要的应用更新。',
        'es':
            'Permite las notificaciones para recibir actualizaciones importantes de la aplicación.',
        'fr':
            'Autorisez les notifications pour recevoir les mises à jour importantes de l’application.',
        'ar':
            'اسمح بالإشعارات لتلقي تحديثات التطبيق المهمة.',
        'hi':
            'महत्वपूर्ण ऐप अपडेट प्राप्त करने के लिए सूचनाएँ अनुमति दें।',
        'bn':
            'গুরুত্বপূর্ণ অ্যাপ আপডেট পেতে বিজ্ঞপ্তির অনুমতি দিন।',
        'ru':
            'Разрешите уведомления, чтобы получать важные обновления приложения.',
        'tr':
            'Önemli uygulama güncellemelerini almak için bildirimlere izin verin.',
        'id':
            'Izinkan notifikasi untuk menerima pembaruan penting aplikasi.',
      },
      'refreshNotificationStatus': {
        'en': 'Refresh Notification Status',
        'zh': '刷新通知状态',
        'es': 'Actualizar estado de notificaciones',
        'fr': 'Actualiser l’état des notifications',
        'ar': 'تحديث حالة الإشعارات',
        'hi': 'सूचना स्थिति रीफ़्रेश करें',
        'bn': 'বিজ্ঞপ্তির অবস্থা রিফ্রেশ করুন',
        'ru': 'Обновить статус уведомлений',
        'tr': 'Bildirim durumunu yenile',
        'id': 'Segarkan status notifikasi',
      },
      'enableNotifications': {
        'en': 'Enable Notifications',
        'zh': '启用通知',
        'es': 'Activar notificaciones',
        'fr': 'Activer les notifications',
        'ar': 'تفعيل الإشعارات',
        'hi': 'सूचनाएँ सक्षम करें',
        'bn': 'বিজ্ঞপ্তি চালু করুন',
        'ru': 'Включить уведомления',
        'tr': 'Bildirimleri etkinleştir',
        'id': 'Aktifkan notifikasi',
      },
      'checkCurrentStatus': {
        'en': 'Check Current Status',
        'zh': '检查当前状态',
        'es': 'Comprobar estado actual',
        'fr': 'Vérifier l’état actuel',
        'ar': 'التحقق من الحالة الحالية',
        'hi': 'वर्तमान स्थिति जाँचें',
        'bn': 'বর্তমান অবস্থা পরীক্ষা করুন',
        'ru': 'Проверить текущий статус',
        'tr': 'Mevcut durumu kontrol et',
        'id': 'Periksa status saat ini',
      },
      'notificationsDisabledMessage': {
        'en':
            'Notifications are currently disabled. Please allow notifications for POWER FAN NETWORK.',
        'zh':
            '通知当前已禁用。请允许 POWER FAN NETWORK 发送通知。',
        'es':
            'Las notificaciones están desactivadas. Permite las notificaciones para POWER FAN NETWORK.',
        'fr':
            'Les notifications sont actuellement désactivées. Autorisez les notifications pour POWER FAN NETWORK.',
        'ar':
            'الإشعارات معطّلة حاليًا. يرجى السماح بإشعارات POWER FAN NETWORK.',
        'hi':
            'सूचनाएँ अभी अक्षम हैं। POWER FAN NETWORK के लिए सूचनाओं की अनुमति दें।',
        'bn':
            'বিজ্ঞপ্তি বর্তমানে বন্ধ আছে। POWER FAN NETWORK-এর জন্য বিজ্ঞপ্তির অনুমতি দিন।',
        'ru':
            'Уведомления сейчас отключены. Разрешите уведомления для POWER FAN NETWORK.',
        'tr':
            'Bildirimler şu anda devre dışı. POWER FAN NETWORK için bildirimlere izin verin.',
        'id':
            'Notifikasi saat ini nonaktif. Izinkan notifikasi untuk POWER FAN NETWORK.',
      },
      'securityTitle': {
        'en': 'Security',
        'zh': '安全',
        'es': 'Seguridad',
        'fr': 'Sécurité',
        'ar': 'الأمان',
        'hi': 'सुरक्षा',
        'bn': 'নিরাপত্তা',
        'ru': 'Безопасность',
        'tr': 'Güvenlik',
        'id': 'Keamanan',
      },
      'accountSecurity': {
        'en': 'Account Security',
        'zh': '账户安全',
        'es': 'Seguridad de la cuenta',
        'fr': 'Sécurité du compte',
        'ar': 'أمان الحساب',
        'hi': 'खाता सुरक्षा',
        'bn': 'অ্যাকাউন্ট নিরাপত্তা',
        'ru': 'Безопасность аккаунта',
        'tr': 'Hesap güvenliği',
        'id': 'Keamanan akun',
      },
      'securityDescription': {
        'en':
            'POWER FAN NETWORK is designed to protect the integrity of the network and its users.',
        'zh':
            'POWER FAN NETWORK 旨在保护网络及其用户的完整性。',
        'es':
            'POWER FAN NETWORK está diseñado para proteger la integridad de la red y sus usuarios.',
        'fr':
            'POWER FAN NETWORK est conçu pour protéger l’intégrité du réseau et de ses utilisateurs.',
        'ar':
            'تم تصميم POWER FAN NETWORK لحماية سلامة الشبكة ومستخدميها.',
        'hi':
            'POWER FAN NETWORK नेटवर्क और उसके उपयोगकर्ताओं की सुरक्षा के लिए बनाया गया है।',
        'bn':
            'POWER FAN NETWORK নেটওয়ার্ক এবং এর ব্যবহারকারীদের সুরক্ষার জন্য তৈরি করা হয়েছে।',
        'ru':
            'POWER FAN NETWORK создан для защиты целостности сети и её пользователей.',
        'tr':
            'POWER FAN NETWORK, ağın ve kullanıcılarının bütünlüğünü korumak için tasarlanmıştır.',
        'id':
            'POWER FAN NETWORK dirancang untuk melindungi integritas jaringan dan penggunanya.',
      },
      'onePersonOneAccount': {
        'en': 'One person = one account',
        'zh': '一人 = 一个账户',
        'es': 'Una persona = una cuenta',
        'fr': 'Une personne = un compte',
        'ar': 'شخص واحد = حساب واحد',
        'hi': 'एक व्यक्ति = एक खाता',
        'bn': 'একজন ব্যক্তি = একটি অ্যাকাউন্ট',
        'ru': 'Один человек = один аккаунт',
        'tr': 'Bir kişi = bir hesap',
        'id': 'Satu orang = satu akun',
      },
      'oneAccountDescription': {
        'en': 'Each user should maintain only one genuine account.',
        'zh': '每位用户只能维护一个真实账户。',
        'es': 'Cada usuario debe mantener una sola cuenta auténtica.',
        'fr': 'Chaque utilisateur doit conserver un seul compte authentique.',
        'ar': 'يجب على كل مستخدم الاحتفاظ بحساب حقيقي واحد فقط.',
        'hi': 'प्रत्येक उपयोगकर्ता को केवल एक वास्तविक खाता रखना चाहिए।',
        'bn': 'প্রত্যেক ব্যবহারকারীর শুধুমাত্র একটি আসল অ্যাকাউন্ট রাখা উচিত।',
        'ru': 'Каждый пользователь должен иметь только один настоящий аккаунт.',
        'tr': 'Her kullanıcı yalnızca bir gerçek hesap kullanmalıdır.',
        'id': 'Setiap pengguna harus memiliki satu akun asli saja.',
      },
      'noBots': {
        'en': 'No bots or automation',
        'zh': '禁止机器人或自动化',
        'es': 'Sin bots ni automatización',
        'fr': 'Aucun bot ni automatisation',
        'ar': 'لا روبوتات أو أتمتة',
        'hi': 'बॉट या स्वचालन नहीं',
        'bn': 'বট বা স্বয়ংক্রিয়তা নয়',
        'ru': 'Без ботов и автоматизации',
        'tr': 'Bot veya otomasyon yok',
        'id': 'Tanpa bot atau otomatisasi',
      },
      'noBotsDescription': {
        'en':
            'Bots, automated activity, fake activity, or attempts to abuse the system are not allowed.',
        'zh':
            '不允许使用机器人、自动化活动、虚假活动或试图滥用系统。',
        'es':
            'No se permiten bots, actividad automatizada, actividad falsa ni intentos de abusar del sistema.',
        'fr':
            'Les bots, activités automatisées, activités frauduleuses ou tentatives d’abus du système sont interdits.',
        'ar':
            'لا يُسمح بالروبوتات أو النشاط الآلي أو النشاط المزيف أو محاولات إساءة استخدام النظام.',
        'hi':
            'बॉट, स्वचालित गतिविधि, नकली गतिविधि या सिस्टम का दुरुपयोग करने के प्रयास की अनुमति नहीं है।',
        'bn':
            'বট, স্বয়ংক্রিয় কার্যকলাপ, ভুয়া কার্যকলাপ বা সিস্টেমের অপব্যবহারের চেষ্টা অনুমোদিত নয়।',
        'ru':
            'Боты, автоматическая или фиктивная активность, а также попытки злоупотребления системой запрещены.',
        'tr':
            'Botlar, otomatik etkinlikler, sahte etkinlikler veya sistemi kötüye kullanma girişimleri yasaktır.',
        'id':
            'Bot, aktivitas otomatis, aktivitas palsu, atau upaya menyalahgunakan sistem tidak diperbolehkan.',
      },
      'rewardProtection': {
        'en': 'Reward protection',
        'zh': '奖励保护',
        'es': 'Protección de recompensas',
        'fr': 'Protection des récompenses',
        'ar': 'حماية المكافآت',
        'hi': 'रिवॉर्ड सुरक्षा',
        'bn': 'রিওয়ার্ড সুরক্ষা',
        'ru': 'Защита наград',
        'tr': 'Ödül koruması',
        'id': 'Perlindungan hadiah',
      },
      'rewardProtectionDescription': {
        'en':
            'Accounts involved in suspicious or abusive activity may lose access to rewards and network features.',
        'zh':
            '涉及可疑或滥用活动的账户可能会失去奖励和网络功能的访问权限。',
        'es':
            'Las cuentas involucradas en actividades sospechosas o abusivas pueden perder el acceso a recompensas y funciones de la red.',
        'fr':
            'Les comptes impliqués dans des activités suspectes ou abusives peuvent perdre l’accès aux récompenses et aux fonctionnalités du réseau.',
        'ar':
            'قد تفقد الحسابات المتورطة في نشاط مشبوه أو مسيء الوصول إلى المكافآت وميزات الشبكة.',
        'hi':
            'संदिग्ध या दुरुपयोग वाली गतिविधि में शामिल खाते रिवॉर्ड और नेटवर्क सुविधाओं तक पहुँच खो सकते हैं।',
        'bn':
            'সন্দেহজনক বা অপব্যবহারমূলক কার্যকলাপে জড়িত অ্যাকাউন্ট রিওয়ার্ড এবং নেটওয়ার্ক সুবিধার অ্যাক্সেস হারাতে পারে।',
        'ru':
            'Аккаунты, связанные с подозрительной или злоупотребляющей активностью, могут потерять доступ к наградам и функциям сети.',
        'tr':
            'Şüpheli veya kötüye kullanımla ilişkili hesaplar ödüllere ve ağ özelliklerine erişimini kaybedebilir.',
        'id':
            'Akun yang terlibat dalam aktivitas mencurigakan atau penyalahgunaan dapat kehilangan akses ke hadiah dan fitur jaringan.',
      },
      'useNetworkFairly': {
        'en': 'Use the network fairly',
        'zh': '公平使用网络',
        'es': 'Usa la red de forma justa',
        'fr': 'Utilisez le réseau équitablement',
        'ar': 'استخدم الشبكة بعدل',
        'hi': 'नेटवर्क का निष्पक्ष उपयोग करें',
        'bn': 'নেটওয়ার্ক ন্যায্যভাবে ব্যবহার করুন',
        'ru': 'Используйте сеть честно',
        'tr': 'Ağı adil kullan',
        'id': 'Gunakan jaringan secara wajar',
      },
      'useNetworkFairlyDescription': {
        'en':
            'Please keep your account secure and use POWER FAN NETWORK fairly and genuinely.',
        'zh':
            '请保护您的账户安全，并公平、真实地使用 POWER FAN NETWORK。',
        'es':
            'Mantén tu cuenta segura y utiliza POWER FAN NETWORK de forma justa y auténtica.',
        'fr':
            'Gardez votre compte sécurisé et utilisez POWER FAN NETWORK de manière équitable et authentique.',
        'ar':
            'يرجى الحفاظ على أمان حسابك واستخدام POWER FAN NETWORK بعدل وبشكل حقيقي.',
        'hi':
            'अपने खाते को सुरक्षित रखें और POWER FAN NETWORK का निष्पक्ष एवं वास्तविक उपयोग करें।',
        'bn':
            'আপনার অ্যাকাউন্ট সুরক্ষিত রাখুন এবং POWER FAN NETWORK ন্যায্য ও বাস্তবভাবে ব্যবহার করুন।',
        'ru':
            'Защищайте свой аккаунт и используйте POWER FAN NETWORK честно и добросовестно.',
        'tr':
            'Hesabını güvende tut ve POWER FAN NETWORK’ü adil ve gerçek şekilde kullan.',
        'id':
            'Jaga keamanan akun Anda dan gunakan POWER FAN NETWORK secara wajar dan nyata.',
      },
      'aboutTitle': {
        'en': 'About Power Fan Network',
        'zh': '关于 Power Fan Network',
        'es': 'Acerca de Power Fan Network',
        'fr': 'À propos de Power Fan Network',
        'ar': 'حول Power Fan Network',
        'hi': 'Power Fan Network के बारे में',
        'bn': 'Power Fan Network সম্পর্কে',
        'ru': 'О Power Fan Network',
        'tr': 'Power Fan Network hakkında',
        'id': 'Tentang Power Fan Network',
      },
      'about': {
        'en': 'About',
        'zh': '关于',
        'es': 'Acerca de',
        'fr': 'À propos',
        'ar': 'حول',
        'hi': 'परिचय',
        'bn': 'সম্পর্কে',
        'ru': 'О проекте',
        'tr': 'Hakkında',
        'id': 'Tentang',
      },
      'aboutDescriptionOne': {
        'en':
            'POWER FAN NETWORK is built around consistency, patience, participation, and community.',
        'zh':
            'POWER FAN NETWORK 建立在坚持、耐心、参与和社区之上。',
        'es':
            'POWER FAN NETWORK se basa en la constancia, la paciencia, la participación y la comunidad.',
        'fr':
            'POWER FAN NETWORK repose sur la constance, la patience, la participation et la communauté.',
        'ar':
            'يعتمد POWER FAN NETWORK على الاستمرارية والصبر والمشاركة والمجتمع.',
        'hi':
            'POWER FAN NETWORK निरंतरता, धैर्य, भागीदारी और समुदाय पर आधारित है।',
        'bn':
            'POWER FAN NETWORK ধারাবাহিকতা, ধৈর্য, অংশগ্রহণ এবং সম্প্রদায়ের উপর ভিত্তি করে তৈরি।',
        'ru':
            'POWER FAN NETWORK построен на постоянстве, терпении, участии и сообществе.',
        'tr':
            'POWER FAN NETWORK; istikrar, sabır, katılım ve topluluk üzerine kuruludur.',
        'id':
            'POWER FAN NETWORK dibangun berdasarkan konsistensi, kesabaran, partisipasi, dan komunitas.',
      },
      'aboutDescriptionTwo': {
        'en':
            'Stay active, participate in daily activities, complete available tasks, build genuine connections, and keep moving forward with the network.',
        'zh':
            '保持活跃，参与每日活动，完成可用任务，建立真实联系，并继续与网络一起前进。',
        'es':
            'Mantente activo, participa en las actividades diarias, completa las tareas disponibles, crea conexiones auténticas y sigue avanzando con la red.',
        'fr':
            'Restez actif, participez aux activités quotidiennes, accomplissez les tâches disponibles, créez de vraies relations et continuez à avancer avec le réseau.',
        'ar':
            'كن نشطًا، وشارك في الأنشطة اليومية، وأكمل المهام المتاحة، وابنِ علاقات حقيقية، واستمر في التقدم مع الشبكة.',
        'hi':
            'सक्रिय रहें, दैनिक गतिविधियों में भाग लें, उपलब्ध कार्य पूरे करें, वास्तविक संबंध बनाएँ और नेटवर्क के साथ आगे बढ़ते रहें।',
        'bn':
            'সক্রিয় থাকুন, দৈনিক কার্যক্রমে অংশ নিন, উপলভ্য কাজ সম্পন্ন করুন, বাস্তব সংযোগ তৈরি করুন এবং নেটওয়ার্কের সাথে এগিয়ে চলুন।',
        'ru':
            'Будьте активны, участвуйте в ежедневных мероприятиях, выполняйте доступные задания, создавайте настоящие связи и продолжайте развиваться вместе с сетью.',
        'tr':
            'Aktif kal, günlük etkinliklere katıl, mevcut görevleri tamamla, gerçek bağlantılar kur ve ağ ile ilerlemeye devam et.',
        'id':
            'Tetap aktif, ikuti aktivitas harian, selesaikan tugas yang tersedia, bangun koneksi nyata, dan terus maju bersama jaringan.',
      },
      'aboutDescriptionThree': {
        'en':
            'Mining is only one part of the journey. Your consistency and genuine participation help you make the most of the Power Fan Network experience.',
        'zh':
            '挖矿只是这段旅程的一部分。您的坚持和真实参与将帮助您充分体验 Power Fan Network。',
        'es':
            'La minería es solo una parte del camino. Tu constancia y participación auténtica te ayudan a aprovechar al máximo la experiencia de Power Fan Network.',
        'fr':
            'Le minage n’est qu’une partie du parcours. Votre constance et votre participation authentique vous aident à profiter pleinement de l’expérience Power Fan Network.',
        'ar':
            'التعدين هو جزء واحد فقط من الرحلة. تساعدك استمراريتك ومشاركتك الحقيقية على الاستفادة من تجربة Power Fan Network.',
        'hi':
            'माइनिंग इस यात्रा का केवल एक हिस्सा है। आपकी निरंतरता और वास्तविक भागीदारी आपको Power Fan Network के अनुभव का अधिकतम लाभ उठाने में मदद करती है।',
        'bn':
            'মাইনিং এই যাত্রার একটি অংশ মাত্র। আপনার ধারাবাহিকতা এবং প্রকৃত অংশগ্রহণ আপনাকে Power Fan Network-এর অভিজ্ঞতা থেকে সর্বাধিক সুবিধা পেতে সাহায্য করবে।',
        'ru':
            'Майнинг — лишь одна часть пути. Ваша постоянная и искренняя активность помогает максимально использовать возможности Power Fan Network.',
        'tr':
            'Madencilik yolculuğun yalnızca bir parçasıdır. İstikrarın ve gerçek katılımın Power Fan Network deneyiminden en iyi şekilde yararlanmanı sağlar.',
        'id':
            'Mining hanyalah salah satu bagian dari perjalanan. Konsistensi dan partisipasi nyata Anda membantu memaksimalkan pengalaman Power Fan Network.',
      },
      'stayActive': {
        'en': 'STAY ACTIVE.',
        'zh': '保持活跃。',
        'es': 'MANTENTE ACTIVO.',
        'fr': 'RESTEZ ACTIF.',
        'ar': 'كُن نشطًا.',
        'hi': 'सक्रिय रहें।',
        'bn': 'সক্রিয় থাকুন।',
        'ru': 'БУДЬТЕ АКТИВНЫ.',
        'tr': 'AKTİF KAL.',
        'id': 'TETAP AKTIF.',
      },
      'stayGenuine': {
        'en': 'STAY GENUINE.',
        'zh': '保持真实。',
        'es': 'SÉ AUTÉNTICO.',
        'fr': 'RESTEZ AUTHENTIQUE.',
        'ar': 'كُن حقيقيًا.',
        'hi': 'वास्तविक रहें।',
        'bn': 'বাস্তব থাকুন।',
        'ru': 'БУДЬТЕ ИСКРЕННИМИ.',
        'tr': 'GERÇEK KAL.',
        'id': 'TETAP NYATA.',
      },
      'stayConsistent': {
        'en': 'STAY CONSISTENT.',
        'zh': '保持坚持。',
        'es': 'MANTENTE CONSTANTE.',
        'fr': 'RESTEZ CONSTANT.',
        'ar': 'كُن مستمرًا.',
        'hi': 'निरंतर बने रहें।',
        'bn': 'ধারাবাহিক থাকুন।',
        'ru': 'БУДЬТЕ ПОСЛЕДОВАТЕЛЬНЫ.',
        'tr': 'İSTİKRARLI KAL.',
        'id': 'TETAP KONSISTEN.',
      },
      'languageSelected': {
        'en': 'Language changed',
        'zh': '语言已更改',
        'es': 'Idioma cambiado',
        'fr': 'Langue modifiée',
        'ar': 'تم تغيير اللغة',
        'hi': 'भाषा बदल दी गई',
        'bn': 'ভাষা পরিবর্তন হয়েছে',
        'ru': 'Язык изменён',
        'tr': 'Dil değiştirildi',
        'id': 'Bahasa diubah',
      },
      'mineFanEarnMore': {
        'en': 'mine FAN. earn more.',
        'zh': '挖掘 FAN，赚取更多。',
        'es': 'mina FAN. gana más.',
        'fr': 'minez FAN. gagnez plus.',
        'ar': 'استخرج FAN. واربح المزيد.',
        'hi': 'FAN माइन करें। अधिक कमाएँ।',
        'bn': 'FAN মাইন করুন। আরও উপার্জন করুন।',
        'ru': 'майните FAN. зарабатывайте больше.',
        'tr': 'FAN madenciliği yap. daha fazla kazan.',
        'id': 'mine FAN. dapatkan lebih banyak.',
      },
      'settingsApp': {
        'en': 'App',
        'zh': '应用',
        'es': 'Aplicación',
        'fr': 'Application',
        'ar': 'التطبيق',
        'hi': 'ऐप',
        'bn': 'অ্যাপ',
        'ru': 'Приложение',
        'tr': 'Uygulama',
        'id': 'Aplikasi',
      },
      'notificationsEnabledSubtitle': {
        'en': 'Notifications are enabled',
        'zh': '通知已启用',
        'es': 'Las notificaciones están activadas',
        'fr': 'Les notifications sont activées',
        'ar': 'الإشعارات مفعّلة',
        'hi': 'सूचनाएँ सक्षम हैं',
        'bn': 'বিজ্ঞপ্তি চালু আছে',
        'ru': 'Уведомления включены',
        'tr': 'Bildirimler etkin',
        'id': 'Notifikasi aktif',
      },
      'notificationsDisabledSubtitle': {
        'en': 'Notifications are disabled',
        'zh': '通知已禁用',
        'es': 'Las notificaciones están desactivadas',
        'fr': 'Les notifications sont désactivées',
        'ar': 'الإشعارات معطّلة',
        'hi': 'सूचनाएँ अक्षम हैं',
        'bn': 'বিজ্ঞপ্তি বন্ধ আছে',
        'ru': 'Уведомления отключены',
        'tr': 'Bildirimler devre dışı',
        'id': 'Notifikasi nonaktif',
      },
      'securitySubtitle': {
        'en': 'Protect your account and network activity',
        'zh': '保护您的账户和网络活动',
        'es': 'Protege tu cuenta y actividad en la red',
        'fr': 'Protégez votre compte et votre activité sur le réseau',
        'ar': 'احمِ حسابك ونشاطك على الشبكة',
        'hi': 'अपने खाते और नेटवर्क गतिविधि की सुरक्षा करें',
        'bn': 'আপনার অ্যাকাউন্ট ও নেটওয়ার্ক কার্যক্রম সুরক্ষিত করুন',
        'ru': 'Защищайте аккаунт и активность в сети',
        'tr': 'Hesabını ve ağ etkinliğini koru',
        'id': 'Lindungi akun dan aktivitas jaringan Anda',
      },
      'aboutSubtitle': {
        'en': 'Learn more about Power Fan Network',
        'zh': '了解更多关于 Power Fan Network 的信息',
        'es': 'Obtén más información sobre Power Fan Network',
        'fr': 'En savoir plus sur Power Fan Network',
        'ar': 'تعرف على المزيد حول Power Fan Network',
        'hi': 'Power Fan Network के बारे में और जानें',
        'bn': 'Power Fan Network সম্পর্কে আরও জানুন',
        'ru': 'Узнайте больше о Power Fan Network',
        'tr': 'Power Fan Network hakkında daha fazla bilgi edin',
        'id': 'Pelajari lebih lanjut tentang Power Fan Network',
      },
      'userFallback': {
        'en': 'User',
        'zh': '用户',
        'es': 'Usuario',
        'fr': 'Utilisateur',
        'ar': 'مستخدم',
        'hi': 'उपयोगकर्ता',
        'bn': 'ব্যবহারকারী',
        'ru': 'Пользователь',
        'tr': 'Kullanıcı',
        'id': 'Pengguna',
      },
    };

    return values[key]?[code] ??
        values[key]?['en'] ??
        key;
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _profile = null;
          _loading = false;
        });

        return;
      }

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadNotificationStatus() async {
    try {
      final enabled =
          await NotificationService.instance.areNotificationsEnabled();

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = enabled;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() {
      _loggingOut = true;
    });

    try {
      await AuthService.instance.logout();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  String _profileValue(String key) {
    final value = _profile?[key];
    return value?.toString().trim() ?? '';
  }

  String get _profileImageUrl {
    const keys = [
      'profile_image_url',
      'profile_image',
      'avatar_url',
      'avatar',
      'profileImageUrl',
      'image_url',
      'imageUrl',
    ];

    for (final key in keys) {
      final value = _profileValue(key);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String get _name {
    final name = _profileValue('name');

    if (name.isNotEmpty) {
      return name;
    }

    final username = _profileValue('username');

    if (username.isNotEmpty) {
      return username;
    }

    final user = _supabase.auth.currentUser;

    return user?.userMetadata?['name']?.toString() ??
        _localized('userFallback');
  }

  String get _email {
    return _supabase.auth.currentUser?.email ?? '';
  }

  String _initials() {
    final name = _name.trim();

    if (name.isEmpty) {
      return 'U';
    }

    final parts = name.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first
          .substring(
            0,
            parts.first.length >= 2 ? 2 : 1,
          )
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildProfileCard() {
    final imageUrl = _profileImageUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3B159B),
            Color(0xFF241064),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Center(
                        child: Text(
                          _initials(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      _initials(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? const Color(0xFF3B159B);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
      trailing: onTap == null
          ? null
          : const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
      onTap: onTap,
    );
  }

  String get _currentLanguageName {
    final code = _languageController.languageCode;

    for (final language in AppLocalizations.languages) {
      if (language.code == code) {
        return language.nativeName;
      }
    }

    return AppLocalizations.languages.first.nativeName;
  }

  Future<void> _openLanguageSelector() async {
    await _languageController.loadSavedLanguage();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final currentCode =
                  _languageController.languageCode;

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B159B)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.language,
                            color: Color(0xFF3B159B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t('language'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF241064),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('chooseLanguage'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount:
                            AppLocalizations.languages.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final language =
                              AppLocalizations.languages[index];
                          final selected =
                              language.code == currentCode;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(14),
                              onTap: () async {
                                await _languageController
                                    .setLanguage(language.code);

                                if (!mounted) return;

                                setSheetState(() {});
                                setState(() {});

                                if (Navigator.of(sheetContext)
                                    .canPop()) {
                                  Navigator.of(sheetContext).pop();
                                }

                                if (!mounted) return;

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _t('languageChanged'),
                                    ),
                                    duration:
                                        const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF3B159B)
                                          .withValues(alpha: 0.07)
                                      : const Color(0xFFF8F8FC),
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF3B159B)
                                            .withValues(alpha: 0.25)
                                        : const Color(0xFFE7E7EE),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFF3B159B)
                                                .withValues(alpha: 0.10)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        language.nativeName.isNotEmpty
                                            ? language.nativeName
                                                .substring(0, 1)
                                            : language.code
                                                .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3B159B),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            language.nativeName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: selected
                                                  ? const Color(
                                                      0xFF241064)
                                                  : const Color(
                                                      0xFF333333),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            language.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF777777),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.chevron_right,
                                      color: selected
                                          ? const Color(0xFF3B159B)
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleEnable() async {
              if (_notificationLoading) return;

              setSheetState(() {
                _notificationLoading = true;
              });

              try {
                await NotificationService.instance.requestPermission();

                final enabled = await NotificationService.instance
                    .areNotificationsEnabled();

                if (!mounted) return;

                setState(() {
                  _notificationsEnabled = enabled;
                });

                setSheetState(() {
                  _notificationLoading = false;
                });

                if (!enabled) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _localized('notificationsDisabledMessage'),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;

                setSheetState(() {
                  _notificationLoading = false;
                });

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                    ),
                  ),
                );
              }
            }

            Future<void> handleRefresh() async {
              if (_notificationLoading) return;

              setSheetState(() {
                _notificationLoading = true;
              });

              try {
                final enabled = await NotificationService.instance
                    .areNotificationsEnabled();

                if (!mounted) return;

                setState(() {
                  _notificationsEnabled = enabled;
                });

                setSheetState(() {
                  _notificationLoading = false;
                });
              } catch (_) {
                if (!mounted) return;

                setSheetState(() {
                  _notificationLoading = false;
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B159B)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_none,
                            color: Color(0xFF3B159B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _localized('notificationsTitle'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF241064),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _localized('manageNotifications'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localized('notificationDescription'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8FC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _notificationsEnabled
                              ? const Color(0xFF3B159B)
                                  .withValues(alpha: 0.15)
                              : const Color(0xFFE5E5EC),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _notificationsEnabled
                                  ? const Color(0xFF3B159B)
                                      .withValues(alpha: 0.10)
                                  : Colors.grey.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _notificationsEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_off_outlined,
                              color: _notificationsEnabled
                                  ? const Color(0xFF3B159B)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _notificationsEnabled
                                      ? _localized(
                                          'notificationsEnabled',
                                        )
                                      : _localized(
                                          'notificationsDisabled',
                                        ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF241064),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _notificationsEnabled
                                      ? _localized(
                                          'notificationsCanSend',
                                        )
                                      : _localized(
                                          'allowNotifications',
                                        ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _notificationLoading ? null : handleEnable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B159B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _notificationLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _notificationsEnabled
                                    ? Icons.refresh
                                    : Icons.notifications_active_outlined,
                              ),
                        label: Text(
                          _notificationsEnabled
                              ? _localized(
                                  'refreshNotificationStatus',
                                )
                              : _localized(
                                  'enableNotifications',
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _notificationLoading ? null : handleRefresh,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B159B),
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          side: BorderSide(
                            color: const Color(0xFF3B159B)
                                .withValues(alpha: 0.25),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.sync,
                          size: 20,
                        ),
                        label: Text(
                          _localized('checkCurrentStatus'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSecurity() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B159B)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.security_outlined,
                        color: Color(0xFF3B159B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _localized('securityTitle'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF241064),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _localized('accountSecurity'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF241064),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _localized('securityDescription'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSecurityPoint(
                  icon: Icons.person_outline,
                  title: _localized('onePersonOneAccount'),
                  text: _localized('oneAccountDescription'),
                ),
                _buildSecurityPoint(
                  icon: Icons.smart_toy_outlined,
                  title: _localized('noBots'),
                  text: _localized('noBotsDescription'),
                ),
                _buildSecurityPoint(
                  icon: Icons.shield_outlined,
                  title: _localized('rewardProtection'),
                  text: _localized('rewardProtectionDescription'),
                ),
                _buildSecurityPoint(
                  icon: Icons.verified_user_outlined,
                  title: _localized('useNetworkFairly'),
                  text: _localized('useNetworkFairlyDescription'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSecurityPoint({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3B159B)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 21,
              color: const Color(0xFF3B159B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF241064),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAbout() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3B159B),
                            Color(0xFF241064),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _localized('aboutTitle'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF241064),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'POWER FAN NETWORK',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B159B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _localized('mineFanEarnMore'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF777777),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _localized('about'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF241064),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _localized('aboutDescriptionOne'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _localized('aboutDescriptionTwo'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _localized('aboutDescriptionThree'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3B159B),
                        Color(0xFF241064),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _localized('stayActive'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _localized('stayGenuine'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _localized('stayConsistent'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${_t('version')} 1.0.0',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8F8FC),
        foregroundColor: const Color(0xFF241064),
        title: Text(
          _t('settings'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF3B159B),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF3B159B),
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  30,
                ),
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 22),
                  Text(
                    _localized('settingsApp'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF241064),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSettingTile(
                    icon: Icons.language,
                    title: _t('language'),
                    subtitle: _currentLanguageName,
                    onTap: _openLanguageSelector,
                  ),
                  _buildSettingTile(
                    icon: Icons.notifications_none,
                    title: _t('notifications'),
                    subtitle: _notificationsEnabled
                        ? _localized(
                            'notificationsEnabledSubtitle',
                          )
                        : _localized(
                            'notificationsDisabledSubtitle',
                          ),
                    onTap: _openNotifications,
                  ),
                  _buildSettingTile(
                    icon: Icons.security_outlined,
                    title: _t('security'),
                    subtitle: _localized('securitySubtitle'),
                    onTap: _openSecurity,
                  ),
                  _buildSettingTile(
                    icon: Icons.info_outline,
                    title: _localized('aboutTitle'),
                    subtitle: _localized('aboutSubtitle'),
                    onTap: _openAbout,
                  ),
                  const SizedBox(height: 18),
                  _buildSettingTile(
                    icon: Icons.logout,
                    title: _t('logout'),
                    iconColor: Colors.red,
                    onTap: _loggingOut ? null : _logout,
                  ),
                ],
              ),
            ),
    );
  }
}
