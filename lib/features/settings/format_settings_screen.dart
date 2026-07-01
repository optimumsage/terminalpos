import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dynamic_fields.dart';
import '../../core/enums.dart';
import '../../data/repositories.dart';
import '../../models/app_settings.dart';
import '../../widgets/ui.dart';

/// Currency, number, date/time and invoice-numbering formatting options with
/// live previews.
class FormatSettingsScreen extends ConsumerStatefulWidget {
  const FormatSettingsScreen({super.key});

  @override
  ConsumerState<FormatSettingsScreen> createState() =>
      _FormatSettingsScreenState();
}

class _FormatSettingsScreenState extends ConsumerState<FormatSettingsScreen> {
  late final TextEditingController _symbol;
  late final TextEditingController _code;
  late final TextEditingController _prefix;
  late final TextEditingController _nextNumber;
  late final TextEditingController _padding;
  final FocusNode _nextNumberFocus = FocusNode();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider).value ?? AppSettings();
    _symbol = TextEditingController(text: s.currencySymbol);
    _code = TextEditingController(text: s.currencyCode);
    _prefix = TextEditingController(text: s.invoicePrefix);
    _nextNumber = TextEditingController(text: s.invoiceNextNumber.toString());
    _padding = TextEditingController(text: s.invoiceNumberPadding.toString());
    _initialized = true;
  }

  @override
  void dispose() {
    _symbol.dispose();
    _code.dispose();
    _prefix.dispose();
    _nextNumber.dispose();
    _padding.dispose();
    _nextNumberFocus.dispose();
    super.dispose();
  }

  SettingsController get _controller => ref.read(settingsProvider.notifier);

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = ref.watch(settingsValueProvider);
    final theme = Theme.of(context);

    // Keep the "Next number" field showing the current next id whenever the
    // user isn't actively editing it (it advances each time an invoice is made).
    if (!_nextNumberFocus.hasFocus &&
        _nextNumber.text != s.invoiceNextNumber.toString()) {
      _nextNumber.text = s.invoiceNextNumber.toString();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Currency & Format')),
      body: ListView(
        children: [
          SectionCard(
            title: 'Currency',
            icon: Icons.payments_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _symbol,
                      decoration:
                          const InputDecoration(labelText: 'Symbol'),
                      onChanged: (v) =>
                          _controller.edit((x) => x..currencySymbol = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Code'),
                      onChanged: (v) =>
                          _controller.edit((x) => x..currencyCode = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Symbol placement', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<CurrencyPlacement>(
                  segments: const [
                    ButtonSegment(
                      value: CurrencyPlacement.before,
                      label: Text('Before'),
                    ),
                    ButtonSegment(
                      value: CurrencyPlacement.after,
                      label: Text('After'),
                    ),
                  ],
                  selected: {s.currencyPlacement},
                  onSelectionChanged: (sel) => _controller
                      .edit((x) => x..currencyPlacement = sel.first),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Decimal places', style: theme.textTheme.labelLarge),
                  const Spacer(),
                  DropdownButton<int>(
                    value: s.decimalPlaces,
                    items: [
                      for (var i = 0; i <= 3; i++)
                        DropdownMenuItem(value: i, child: Text('$i')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        _controller.edit((x) => x..decimalPlaces = v);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          SectionCard(
            title: 'Amount separator',
            subtitle: 'Grouping and decimal style',
            icon: Icons.pin_outlined,
            children: [
              RadioGroup<AmountSeparator>(
                groupValue: s.amountSeparator,
                onChanged: (v) {
                  if (v != null) {
                    _controller.edit((x) => x..amountSeparator = v);
                  }
                },
                child: Column(
                  children: [
                    for (final sep in AmountSeparator.values)
                      RadioListTile<AmountSeparator>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(sep.example),
                        value: sep,
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live preview',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      s.money.format(1234567.89),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SectionCard(
            title: 'Date & time format',
            icon: Icons.schedule_outlined,
            children: [
              LabeledRow(
                'Date',
                dateFormatById(s.dateFormatId).format(DateTime(2026, 7, 1)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: s.dateFormatId,
                decoration: const InputDecoration(labelText: 'Date format'),
                items: [
                  for (final f in dateFormats)
                    DropdownMenuItem(value: f.id, child: Text(f.label)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    _controller.edit((x) => x..dateFormatId = v);
                  }
                },
              ),
              const SizedBox(height: 16),
              LabeledRow(
                'Time',
                timeFormatById(s.timeFormatId)
                    .format(DateTime(2026, 7, 1, 14, 30, 5)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: s.timeFormatId,
                decoration: const InputDecoration(labelText: 'Time format'),
                items: [
                  for (final f in timeFormats)
                    DropdownMenuItem(value: f.id, child: Text(f.label)),
                ],
                onChanged: (v) {
                  if (v != null) {
                    _controller.edit((x) => x..timeFormatId = v);
                  }
                },
              ),
            ],
          ),
          SectionCard(
            title: 'Invoice numbering',
            icon: Icons.tag,
            children: [
              TextField(
                controller: _prefix,
                decoration: const InputDecoration(labelText: 'Prefix'),
                onChanged: (v) =>
                    _controller.edit((x) => x..invoicePrefix = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nextNumber,
                      focusNode: _nextNumberFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Next number',
                          helperText: 'Used for the next invoice'),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null) {
                          _controller
                              .edit((x) => x..invoiceNextNumber = parsed);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _padding,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Digit padding'),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null) {
                          _controller.edit(
                              (x) => x..invoiceNumberPadding = parsed);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LabeledRow(
                'Next invoice',
                s.formatInvoiceNumber(s.invoiceNextNumber),
                emphasize: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
