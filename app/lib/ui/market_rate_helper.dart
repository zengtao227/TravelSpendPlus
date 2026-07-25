import 'package:flutter/material.dart';
import 'package:travelspendplus/l10n/app_localizations.dart';

import '../services/live_rate_service.dart';
import 'theme.dart';

/// Formats a rate for display/editing: up to 4 decimal places, trailing
/// zeros (and a trailing bare decimal point) stripped, so a round number
/// like 20.0 shows as "20" rather than "20.0000".
String formatRateForEntry(double rate) {
  var text = rate.toStringAsFixed(4);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

/// A small "check market rate" affordance dropped beside a manual rate
/// entry field: tapping it fetches today's rate from [liveRateService] and
/// displays it (never writes into [targetController] on its own); the user
/// then taps "use this" to accept it into the field, or ignores it and
/// keeps typing their own value — manual entry is always available and
/// never overridden without an explicit tap.
class MarketRateHelper extends StatefulWidget {
  final String fromCurrency;
  final String toCurrency;
  final TextEditingController targetController;
  final LiveRateService liveRateService;

  const MarketRateHelper({
    super.key,
    required this.fromCurrency,
    required this.toCurrency,
    required this.targetController,
    required this.liveRateService,
  });

  @override
  State<MarketRateHelper> createState() => _MarketRateHelperState();
}

class _MarketRateHelperState extends State<MarketRateHelper> {
  bool _loading = false;
  double? _fetchedRate;
  bool _failed = false;

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _fetchedRate = null;
      _failed = false;
    });
    final rate = await widget.liveRateService.fetchRate(
      fromCurrency: widget.fromCurrency,
      toCurrency: widget.toCurrency,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _fetchedRate = rate;
      _failed = rate == null;
    });
  }

  void _accept() {
    widget.targetController.text = formatRateForEntry(_fetchedRate!);
    setState(() => _fetchedRate = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_fetchedRate != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              l10n.marketRateFound(
                widget.fromCurrency,
                formatRateForEntry(_fetchedRate!),
                widget.toCurrency,
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            key: const Key('acceptMarketRateButton'),
            onPressed: _accept,
            child: Text(l10n.useThisRate),
          ),
        ],
      );
    }
    return Row(
      children: [
        TextButton(
          key: const Key('checkMarketRateButton'),
          onPressed: _loading ? null : _check,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.checkMarketRate),
        ),
        if (_failed)
          Expanded(
            child: Text(
              l10n.marketRateUnavailable,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
            ),
          ),
      ],
    );
  }
}
