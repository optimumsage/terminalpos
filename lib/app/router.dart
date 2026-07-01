import 'package:go_router/go_router.dart';

import '../features/invoices/invoice_editor_screen.dart';
import '../features/invoices/invoice_list_screen.dart';
import '../features/invoices/invoice_preview_screen.dart';
import '../features/products/products_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/printer_settings_screen.dart';
import '../features/settings/business_settings_screen.dart';
import '../features/settings/format_settings_screen.dart';
import '../features/settings/backup_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/templates/templates_screen.dart';
import '../features/templates/template_editor_screen.dart';

/// Central route table. Invoice id is passed as a path param; screens load the
/// invoice from the repository so deep links and clones work uniformly.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const InvoiceListScreen(),
    ),
    GoRoute(
      path: '/invoice/:id',
      builder: (context, state) =>
          InvoiceEditorScreen(invoiceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/invoice/:id/preview',
      builder: (context, state) =>
          InvoicePreviewScreen(invoiceId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/templates',
      builder: (context, state) => const TemplatesScreen(),
    ),
    GoRoute(
      path: '/templates/:id',
      builder: (context, state) =>
          TemplateEditorScreen(templateId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
      routes: [
        GoRoute(
          path: 'business',
          builder: (context, state) => const BusinessSettingsScreen(),
        ),
        GoRoute(
          path: 'printer',
          builder: (context, state) => const PrinterSettingsScreen(),
        ),
        GoRoute(
          path: 'format',
          builder: (context, state) => const FormatSettingsScreen(),
        ),
        GoRoute(
          path: 'backup',
          builder: (context, state) => const BackupScreen(),
        ),
        GoRoute(
          path: 'about',
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),
  ],
);
