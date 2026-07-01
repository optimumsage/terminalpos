import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';
import '../../models/app_settings.dart';
import '../../widgets/ui.dart';

/// Settings hub: grouped navigation into the detail screens plus quick
/// appearance and tax-default controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<Color> _brandColors = [
    Color(0xFF3D5AFE),
    Color(0xFF00897B),
    Color(0xFF6D4C41),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFFE64A19),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? AppSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SectionCard(
            title: 'Configuration',
            icon: Icons.tune,
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _NavTile(
                icon: Icons.storefront_outlined,
                title: 'Business & Branding',
                subtitle: 'Name, contact details and logo',
                onTap: () => context.push('/settings/business'),
              ),
              _NavTile(
                icon: Icons.print_outlined,
                title: 'Printer',
                subtitle: 'Connection, paper and print behaviour',
                onTap: () => context.push('/settings/printer'),
              ),
              _NavTile(
                icon: Icons.attach_money,
                title: 'Currency & Format',
                subtitle: 'Currency, numbers, dates and invoice numbering',
                onTap: () => context.push('/settings/format'),
              ),
              _NavTile(
                icon: Icons.backup_outlined,
                title: 'Backup & Export',
                subtitle: 'Export/restore data and CSV',
                onTap: () => context.push('/settings/backup'),
              ),
            ],
          ),
          _AppearanceCard(settings: settings, brandColors: _brandColors),
          _TaxDefaultsCard(settings: settings),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.settings, required this.brandColors});

  final AppSettings settings;
  final List<Color> brandColors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Appearance',
      subtitle: 'Theme mode and brand color',
      icon: Icons.palette_outlined,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'system',
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: 'light',
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: 'dark',
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) {
              ref
                  .read(settingsProvider.notifier)
                  .edit((s) => s..themeMode = selection.first);
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('Brand color', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in brandColors)
              _ColorSwatch(
                color: color,
                selected: settings.seedColor == color.toARGB32(),
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .edit((s) => s..seedColor = color.toARGB32());
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

class _TaxDefaultsCard extends ConsumerStatefulWidget {
  const _TaxDefaultsCard({required this.settings});

  final AppSettings settings;

  @override
  ConsumerState<_TaxDefaultsCard> createState() => _TaxDefaultsCardState();
}

class _TaxDefaultsCardState extends ConsumerState<_TaxDefaultsCard> {
  late final TextEditingController _rate;
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(
        text: widget.settings.taxRateDefault.toString());
    _label = TextEditingController(text: widget.settings.taxLabel);
  }

  @override
  void dispose() {
    _rate.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.settings.taxEnabledDefault;
    return SectionCard(
      title: 'Tax defaults',
      subtitle: 'Applied to new invoices',
      icon: Icons.receipt_long_outlined,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable tax by default'),
          value: enabled,
          onChanged: (v) {
            ref
                .read(settingsProvider.notifier)
                .edit((s) => s..taxEnabledDefault = v);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _rate,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Default tax rate',
            suffixText: '%',
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null) {
              ref
                  .read(settingsProvider.notifier)
                  .edit((s) => s..taxRateDefault = parsed);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Tax label',
            hintText: 'Tax, GST, VAT…',
          ),
          onChanged: (v) {
            ref
                .read(settingsProvider.notifier)
                .edit((s) => s..taxLabel = v);
          },
        ),
      ],
    );
  }
}
