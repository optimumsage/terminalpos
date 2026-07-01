import '../core/enums.dart';

/// A declarative invoice template. Customization = toggling/reordering
/// [sections] and tweaking header/footer text, font scale and alignment.
/// Templates are seeded from [presetTemplates] but can be edited and saved.
class InvoiceTemplate {
  InvoiceTemplate({
    required this.id,
    required this.name,
    required this.sections,
    this.headerText = '',
    this.footerText = 'Thank you for your business!',
    this.fontScale = 1.0,
    this.alignment = TemplateAlignment.left,
    this.showBorders = true,
    this.accentBold = true,
    this.builtIn = false,
  });

  final String id;
  String name;

  /// Ordered, each with an enabled flag.
  List<TemplateSectionConfig> sections;
  String headerText;
  String footerText;
  double fontScale;
  TemplateAlignment alignment;
  bool showBorders;
  bool accentBold;
  final bool builtIn;

  bool isEnabled(TemplateSection section) => sections
      .firstWhere(
        (s) => s.section == section,
        orElse: () => TemplateSectionConfig(section: section, enabled: false),
      )
      .enabled;

  InvoiceTemplate clone({required String id, required String name}) {
    return InvoiceTemplate(
      id: id,
      name: name,
      sections: sections.map((s) => s.copy()).toList(),
      headerText: headerText,
      footerText: footerText,
      fontScale: fontScale,
      alignment: alignment,
      showBorders: showBorders,
      accentBold: accentBold,
      builtIn: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sections': sections.map((s) => s.toJson()).toList(),
        'headerText': headerText,
        'footerText': footerText,
        'fontScale': fontScale,
        'alignment': alignment.name,
        'showBorders': showBorders,
        'accentBold': accentBold,
        'builtIn': builtIn,
      };

  factory InvoiceTemplate.fromJson(Map<String, dynamic> json) {
    return InvoiceTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      sections: (json['sections'] as List<dynamic>)
          .map((e) => TemplateSectionConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      headerText: json['headerText'] as String? ?? '',
      footerText: json['footerText'] as String? ?? '',
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      alignment:
          TemplateAlignment.values.byName(json['alignment'] as String? ?? 'left'),
      showBorders: json['showBorders'] as bool? ?? true,
      accentBold: json['accentBold'] as bool? ?? true,
      builtIn: json['builtIn'] as bool? ?? false,
    );
  }
}

class TemplateSectionConfig {
  TemplateSectionConfig({required this.section, this.enabled = true});

  final TemplateSection section;
  bool enabled;

  TemplateSectionConfig copy() =>
      TemplateSectionConfig(section: section, enabled: enabled);

  Map<String, dynamic> toJson() =>
      {'section': section.name, 'enabled': enabled};

  factory TemplateSectionConfig.fromJson(Map<String, dynamic> json) =>
      TemplateSectionConfig(
        section: TemplateSection.values.byName(json['section'] as String),
        enabled: json['enabled'] as bool? ?? true,
      );
}

List<TemplateSectionConfig> _defaultSections({bool qr = false}) => [
      TemplateSectionConfig(section: TemplateSection.logo),
      TemplateSectionConfig(section: TemplateSection.business),
      TemplateSectionConfig(section: TemplateSection.meta),
      TemplateSectionConfig(section: TemplateSection.billTo),
      TemplateSectionConfig(section: TemplateSection.items),
      TemplateSectionConfig(section: TemplateSection.totals),
      TemplateSectionConfig(section: TemplateSection.notes),
      TemplateSectionConfig(section: TemplateSection.footer),
      TemplateSectionConfig(section: TemplateSection.qr, enabled: qr),
    ];

/// The built-in templates seeded on first launch.
List<InvoiceTemplate> presetTemplates() => [
      InvoiceTemplate(
        id: 'preset-classic',
        name: 'Classic',
        sections: _defaultSections(),
        alignment: TemplateAlignment.left,
        builtIn: true,
      ),
      InvoiceTemplate(
        id: 'preset-minimal',
        name: 'Minimal',
        sections: _defaultSections()
          ..removeWhere((s) => s.section == TemplateSection.logo),
        headerText: '',
        footerText: 'Thank you!',
        showBorders: false,
        accentBold: false,
        builtIn: true,
      ),
      InvoiceTemplate(
        id: 'preset-bold',
        name: 'Bold',
        sections: _defaultSections(),
        alignment: TemplateAlignment.center,
        fontScale: 1.1,
        accentBold: true,
        builtIn: true,
      ),
      InvoiceTemplate(
        id: 'preset-compact',
        name: 'Compact',
        sections: _defaultSections()
          ..removeWhere((s) => s.section == TemplateSection.notes),
        fontScale: 0.9,
        showBorders: false,
        builtIn: true,
      ),
    ];
