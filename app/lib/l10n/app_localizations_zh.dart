// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'TravelSpendPlus';

  @override
  String get categoryFood => '餐饮';

  @override
  String get categoryTransport => '交通';

  @override
  String get categoryLodging => '住宿';

  @override
  String get categoryShopping => '购物';

  @override
  String get categoryEntertainment => '娱乐';

  @override
  String get categoryOther => '其他';

  @override
  String get newTrip => '新建行程';

  @override
  String get editTrip => '编辑行程';

  @override
  String get tripName => '行程名称';

  @override
  String get startDate => '开始日期';

  @override
  String get endDate => '结束日期';

  @override
  String get totalBudget => '总预算';

  @override
  String get homeCurrency => '本位币';

  @override
  String get createTrip => '创建行程';

  @override
  String get saveChanges => '保存修改';

  @override
  String get errorEnterTripName => '请输入行程名称';

  @override
  String get errorPositiveAmount => '请输入大于0的金额';

  @override
  String get errorEndDateBeforeStart => '结束日期不能早于开始日期';

  @override
  String get errorCurrencyCode => '请输入3位货币代码';

  @override
  String get addExpense => '记一笔';

  @override
  String get category => '类别';

  @override
  String get amount => '金额';

  @override
  String get currency => '币种';

  @override
  String get description => '备注';

  @override
  String get date => '日期';

  @override
  String get statusPlanned => '计划中';

  @override
  String get statusActual => '已发生';

  @override
  String get saveExpense => '保存';

  @override
  String get errorSelectCategory => '请选择类别';

  @override
  String get errorPositiveRate => '请输入大于0的汇率';

  @override
  String exchangeRatePrompt(String currency, String homeCurrency) {
    return '1 $currency = ? $homeCurrency';
  }

  @override
  String get exchangeRates => '汇率设置';

  @override
  String get addRate => '添加汇率';

  @override
  String get newCurrency => '币种(3位代码)';

  @override
  String get rateValue => '汇率';

  @override
  String get saveRate => '保存汇率';

  @override
  String get changeHomeCurrency => '修改本位币';

  @override
  String get newHomeCurrency => '新本位币';

  @override
  String oldToNewRateLabel(String oldCurrency, String newCurrency) {
    return '1 $oldCurrency = ? $newCurrency';
  }

  @override
  String get confirmChangeCurrency => '确认修改';

  @override
  String get changeCurrencyWarning => '会按你填的换算率，重新计算总预算和所有支出的金额。';
}
