/// Pinned first in every currency picker — the traveler's own most-used
/// currencies, ahead of the alphabetical rest.
const List<String> kCommonCurrencyCodes = ['EUR', 'CHF', 'USD', 'CNY', 'JPY', 'SGD'];

/// Everything else a traveler is realistically likely to need, alphabetical.
/// Not the full ISO-4217 list (170+ codes) — YAGNI; add codes here as they
/// come up rather than front-loading every currency in the world.
const List<String> kOtherCurrencyCodes = [
  'AED', 'ARS', 'AUD', 'BRL', 'CAD', 'CZK', 'DKK', 'EGP', 'GBP', 'HKD',
  'HUF', 'IDR', 'ILS', 'INR', 'KRW', 'MAD', 'MXN', 'MYR', 'NOK', 'NZD',
  'PHP', 'PLN', 'RUB', 'SAR', 'SEK', 'THB', 'TRY', 'TWD', 'VND', 'ZAR',
];

const List<String> kAllCurrencyCodesOrdered = [...kCommonCurrencyCodes, ...kOtherCurrencyCodes];
