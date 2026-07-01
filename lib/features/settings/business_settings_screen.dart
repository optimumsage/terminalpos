import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories.dart';
import '../../models/app_settings.dart';
import '../../widgets/ui.dart';

/// Edits business identity, contact details and the logo used on printouts.
class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _taxId;

  String _logoPath = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider).value ?? AppSettings();
    _name = TextEditingController(text: s.businessName);
    _address = TextEditingController(text: s.businessAddress);
    _phone = TextEditingController(text: s.businessPhone);
    _email = TextEditingController(text: s.businessEmail);
    _website = TextEditingController(text: s.businessWebsite);
    _taxId = TextEditingController(text: s.businessTaxId);
    _logoPath = s.logoPath;
    _initialized = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    _taxId.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(
        dir.path, 'logo_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(picked.path).copy(dest);
    if (!mounted) return;
    setState(() => _logoPath = dest);
    showSnack(context, 'Logo updated');
  }

  void _removeLogo() {
    setState(() => _logoPath = '');
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).edit((s) => s
      ..businessName = _name.text.trim()
      ..businessAddress = _address.text.trim()
      ..businessPhone = _phone.text.trim()
      ..businessEmail = _email.text.trim()
      ..businessWebsite = _website.text.trim()
      ..businessTaxId = _taxId.text.trim()
      ..logoPath = _logoPath);
    if (!mounted) return;
    showSnack(context, 'Business details saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Business & Branding')),
      body: ListView(
        children: [
          SectionCard(
            title: 'Logo',
            subtitle: 'Shown at the top of printed receipts',
            icon: Icons.image_outlined,
            children: [
              _LogoPreview(logoPath: _logoPath),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Change logo'),
                  ),
                  const SizedBox(width: 12),
                  if (_logoPath.isNotEmpty)
                    TextButton.icon(
                      onPressed: _removeLogo,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove logo'),
                    ),
                ],
              ),
            ],
          ),
          SectionCard(
            title: 'Business details',
            icon: Icons.storefront_outlined,
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Business name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _website,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                    labelText: 'Website', hintText: 'www.example.com'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taxId,
                decoration:
                    const InputDecoration(labelText: 'Tax / registration ID'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.logoPath});

  final String logoPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = logoPath.isNotEmpty && File(logoPath).existsSync();
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: hasLogo
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(logoPath), fit: BoxFit.contain),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('No logo set',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
    );
  }
}
