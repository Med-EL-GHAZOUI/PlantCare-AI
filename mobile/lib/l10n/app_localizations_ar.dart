// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'AgriScan AI';

  @override
  String get tagline => 'مساعدة على الكشف الأولي عن أمراض أوراق الطماطم';

  @override
  String get emptyHint =>
      'صوّر ورقة طماطم واحدة جيدة الإضاءة وواضحة، أو اختر صورة من المعرض.';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get chooseFromGallery => 'اختيار من المعرض';

  @override
  String get analyzing => 'جارٍ التحليل…';

  @override
  String get language => 'اللغة';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageArabic => 'العربية';

  @override
  String get selectedImage => 'الصورة المحددة';

  @override
  String get resultTitle => 'نتيجة الكشف الأولي';

  @override
  String modelScore(String percent) {
    return 'درجة النموذج: $percent';
  }

  @override
  String get modelScoreNote =>
      'هذه الدرجة ليست احتمالًا معايَرًا: إنها تدل فقط على الثقة النسبية للنموذج.';

  @override
  String get otherClassesTitle => 'أقرب الفئات';

  @override
  String get uncertainTitle => 'نتيجة غير مؤكدة';

  @override
  String get uncertainBody =>
      'النموذج غير متأكد بما يكفي لاقتراح فئة. أعد التصوير بصورة أوضح وإضاءة أفضل لورقة طماطم واحدة، أو اطلب رأي مختص.';

  @override
  String get disclaimer =>
      'نتيجة كشف أولي بالذكاء الاصطناعي وليست تشخيصًا مؤكدًا. اعرضها على مختص (تقني أو مهندس زراعي) قبل اتخاذ أي قرار للعلاج.';

  @override
  String get limitsTitle => 'الحدود';

  @override
  String get limitsBody =>
      'يعرف النموذج 10 فئات فقط من أوراق الطماطم (9 أمراض أو آفات و«سليمة»). لا يكتشف الصور غير ذات الصلة ولا الأمراض الأخرى، وقد جرى تقييمه على صور في ظروف مضبوطة وليس في الحقول.';

  @override
  String get newAnalysis => 'تحليل جديد';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get errorNetwork =>
      'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت ثم أعد المحاولة.';

  @override
  String get errorTimeout =>
      'الخادم يستغرق وقتًا طويلًا للرد. أعد المحاولة بعد قليل.';

  @override
  String get errorFileTooLarge =>
      'حجم الصورة كبير جدًا (5 ميغابايت كحد أقصى). اختر صورة أخف.';

  @override
  String get errorUnsupportedFormat =>
      'الصيغة غير مدعومة. استخدم صورة JPEG أو PNG.';

  @override
  String get errorInvalidImage =>
      'هذه الصورة غير قابلة للقراءة أو تالفة. اختر صورة أخرى.';

  @override
  String get errorEmptyFile => 'الملف فارغ. اختر صورة أخرى.';

  @override
  String get errorImageTooSmall => 'الصورة صغيرة جدًا. اقترب من الورقة.';

  @override
  String get errorImageTooLarge => 'أبعاد الصورة كبيرة جدًا. اختر صورة أصغر.';

  @override
  String get errorModelUnavailable =>
      'خدمة التحليل غير متاحة مؤقتًا. أعد المحاولة لاحقًا.';

  @override
  String get errorServer => 'واجه الخادم مشكلة. أعد المحاولة لاحقًا.';

  @override
  String get errorInvalidResponse =>
      'ردّ غير متوقع من الخادم. أعد المحاولة لاحقًا.';

  @override
  String get errorPickFailed =>
      'تعذّر الوصول إلى الكاميرا أو المعرض. تحقق من أذونات التطبيق.';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع. أعد المحاولة.';

  @override
  String get classBacterialSpot => 'التبقع البكتيري';

  @override
  String get classEarlyBlight => 'اللفحة المبكرة';

  @override
  String get classLateBlight => 'اللفحة المتأخرة (الميلديو)';

  @override
  String get classLeafMold => 'عفن الأوراق';

  @override
  String get classSeptoriaLeafSpot => 'تبقع أوراق السبتوريا';

  @override
  String get classSpiderMites => 'العنكبوت الأحمر ذو البقعتين';

  @override
  String get classTargetSpot => 'التبقع الهدفي';

  @override
  String get classYellowLeafCurlVirus =>
      'فيروس تجعد واصفرار أوراق الطماطم (TYLCV)';

  @override
  String get classMosaicVirus => 'فيروس موزاييك الطماطم';

  @override
  String get classHealthy => 'ورقة سليمة';

  @override
  String classUnknown(String name) {
    return 'فئة غير معروفة ($name)';
  }

  @override
  String get account => 'الحساب';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get history => 'السجل';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordHint => '10 أحرف على الأقل';

  @override
  String get signInTitle => 'تسجيل الدخول';

  @override
  String get registerTitle => 'إنشاء حساب';

  @override
  String get switchToRegister => 'ليس لديك حساب؟ أنشئ حسابًا';

  @override
  String get switchToSignIn => 'لديك حساب؟ سجّل الدخول';

  @override
  String signedInAs(String email) {
    return 'مسجَّل الدخول: $email';
  }

  @override
  String get signedInUnknown => 'مسجَّل الدخول';

  @override
  String get signInToSaveHint => 'سجّل الدخول للاحتفاظ بتحليلاتك في السجل.';

  @override
  String get savedToHistory =>
      'تم حفظ النتيجة في سجلك (لا يتم الاحتفاظ بالصورة).';

  @override
  String get sessionExpired =>
      'انتهت جلستك. سجّل الدخول من جديد لاستعادة سجلك.';

  @override
  String get validationEmail => 'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get validationPassword =>
      'يجب أن تحتوي كلمة المرور على 10 أحرف على الأقل.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get deleteAccount => 'حذف حسابي';

  @override
  String get deleteAccountTitle => 'حذف حسابك؟';

  @override
  String get deleteAccountBody =>
      'سيتم حذف حسابك وجميع تحليلاتك المحفوظة نهائيًا.';

  @override
  String get historyTitle => 'تحليلاتي';

  @override
  String get historyEmpty =>
      'لا توجد تحليلات محفوظة. التحليلات التي تجريها وأنت مسجَّل الدخول تظهر هنا.';

  @override
  String get historyPrivacy => 'تُحفظ النتائج فقط ولا تُحفظ الصور أبدًا.';

  @override
  String get historyUncertainItem => 'نتيجة غير مؤكدة';

  @override
  String get loadMore => 'عرض المزيد';

  @override
  String get detailTitle => 'تفاصيل التحليل';

  @override
  String analyzedOn(String date) {
    return 'تم التحليل في $date';
  }

  @override
  String modelVersionLabel(String version) {
    return 'إصدار النموذج: $version';
  }

  @override
  String get deleteAnalysis => 'حذف هذا التحليل';

  @override
  String get deleteAnalysisTitle => 'حذف هذا التحليل؟';

  @override
  String get deleteAnalysisBody => 'هذا الإجراء نهائي.';

  @override
  String get analysisDeleted => 'تم حذف التحليل.';

  @override
  String get errorUnauthorized => 'لم تعد جلستك صالحة. سجّل الدخول من جديد.';

  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errorEmailTaken => 'هذا البريد الإلكتروني مستخدم بالفعل.';

  @override
  String get errorTooManyAttempts =>
      'محاولات كثيرة. أعد المحاولة بعد بضع دقائق.';

  @override
  String get errorNotFound =>
      'تعذّر العثور على هذا التحليل (ربما حُذف سابقًا).';

  @override
  String get errorInvalidInput => 'المعلومات المدخلة غير صالحة.';

  @override
  String get errorAccountsUnavailable => 'الحسابات والسجل غير متاحة مؤقتًا.';

  @override
  String get exportTitle => 'تصدير النتيجة';

  @override
  String get exportButton => 'تصدير الصورة مع الشرح';

  @override
  String get exportingLabel => 'جارٍ تجهيز الصورة…';

  @override
  String get exportWatermarkOption => 'إضافة علامة «AgriScan AI» المائية';

  @override
  String get exportNote =>
      'تحتوي الصورة المصدَّرة على الصورة والنتيجة ودرجة النموذج وعبارة «ليست تشخيصًا مؤكدًا». تدل العلامة المائية على المصدر ولا تثبت الأصالة. نص الصورة بالفرنسية (من دون الحروف المُعلَّمة) واسم الفئة بالإنجليزية. لا يحتفظ الخادم بالصورة، وأنت من يختار وجهة المشاركة.';

  @override
  String get exportShareText =>
      'نتيجة كشف أولي من AgriScan AI (مساعدة على الكشف وليست تشخيصًا مؤكدًا)';

  @override
  String get errorShareFailed =>
      'تعذّر فتح المشاركة على هذا الجهاز. أعد المحاولة.';
}
