import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';

import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/locker/screens/security/security_transaction_detail_screen.dart';
import 'features/manager/manager_shell.dart' show ManagerShell, managerShellKey;
import 'features/security/security_shell.dart';
import 'features/vendor/vendor_shell.dart';
import 'features/shell/app_shell.dart';
import 'features/notifications/notifications_page.dart';
import 'features/complaints/complaints_page.dart';
import 'features/billing/invoices_page.dart';
import 'features/amenities/amenities_page.dart';
import 'features/vehicles/vehicles_page.dart';
import 'features/contacts/contacts_page.dart';
import 'features/chat/chat_page.dart';
import 'features/chat/conversation_list_screen.dart';
import 'features/apartments/apartments_page.dart';
import 'features/marketplace/screens/marketplace_screen.dart';
import 'features/marketplace/screens/store_registration_screen.dart';
import 'features/marketplace/screens/store_dashboard_screen.dart';
import 'features/marketplace/screens/my_orders_screen.dart';
import 'features/locker/screens/security/receive_package_screen.dart';
import 'features/locker/screens/security/security_transactions_screen.dart';
import 'features/locker/screens/resident/resident_packages_screen.dart';
import 'features/billing/blockchain_history_page.dart';
import 'core/services/payment_signalr_service.dart';
import 'core/services/deep_link_service.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  debugPrint('API_BASE_URL = ${dotenv.env['API_BASE_URL']}');
  
  // Initialize deep link service
  await deepLinkService.initialize();
  
  runApp(const ICitizenApp());
}

class ICitizenApp extends StatelessWidget {
  const ICitizenApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme 5 sao: Xanh đậm + Trắng + Accent Vàng
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A4A5C), // Xanh đậm chủ đạo
      primary: const Color(0xFF0A4A5C), // Deep Teal
      secondary: const Color(0xFFF4A261), // Accent vàng/cam
      tertiary: const Color(0xFF2A9D8F), // Teal nhẹ
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFF8F9FA),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
      error: const Color(0xFFE76F51),
      brightness: Brightness.light,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ICitizen',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            builder: (context, child) => PaymentNotificationLayer(
              child: ResponsiveBreakpoints.builder(
                child: child!,
                breakpoints: const [
                  Breakpoint(start: 0, end: 450, name: MOBILE),
                  Breakpoint(start: 451, end: 800, name: TABLET),
                  Breakpoint(start: 801, end: 1920, name: DESKTOP),
                  Breakpoint(start: 1921, end: double.infinity, name: '4K'),
                ],
              ),
            ),
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const _Gate(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/home': (context) => const AppShell(),
          '/manager': (context) => ManagerShell(key: managerShellKey),
          // Feature routes (đi thẳng từ Home)
          '/notifications': (_) => const NotificationsPage(),
          '/complaints': (_) => const ComplaintsPage(),
          '/invoices': (_) => const InvoicesPage(),
          '/amenities': (_) => const AmenitiesPage(),
          '/vehicles': (_) => const VehiclesPage(),
          '/contacts': (_) => const ContactsPage(),
          '/chat': (_) => const ChatPage(),
          '/support': (_) => const SupportTicketListScreen(),
          '/apartments': (_) => const ApartmentsPage(),
          '/marketplace': (_) => const MarketplaceScreen(),
          '/store-registration': (_) => const StoreRegistrationScreen(),
          '/my-store': (_) => const StoreDashboardScreen(),
          '/my-orders': (_) => const MyOrdersScreen(),
          // Locker Management
          '/locker/receive-package': (_) => const ReceivePackageScreen(),
          '/locker/security/transactions': (_) => const SecurityTransactionsScreen(),
          '/locker/resident/packages': (_) => const ResidentPackagesScreen(),
          // Blockchain
          '/blockchain-history': (_) => const BlockchainHistoryPage(),
        },
        onGenerateRoute: (settings) {
          // Handle dynamic routes like transaction detail with ID parameter
          if (settings.name?.startsWith('/locker/security/transaction-detail') == true) {
            final args = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (_) => SecurityTransactionDetailScreen(transactionId: args ?? ''),
            );
          }
          return null;
        },
      );
        },
      ),
    );
  }
}

class PaymentNotificationLayer extends StatefulWidget {
  final Widget child;
  const PaymentNotificationLayer({super.key, required this.child});

  @override
  State<PaymentNotificationLayer> createState() => _PaymentNotificationLayerState();
}

class _PaymentNotificationLayerState extends State<PaymentNotificationLayer> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _activeUserId;
  final _currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void dispose() {
    _sub?.cancel();
    paymentSignalRService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    _syncConnection(auth);
    return widget.child;
  }

  void _syncConnection(AuthState auth) {
    final userId = auth.isLoggedIn ? auth.userId : null;
    if (_activeUserId == userId && paymentSignalRService.isConnected == auth.isLoggedIn) {
      return;
    }
    Future.microtask(() async {
      if (!mounted) return;
      if (userId == null) {
        await _sub?.cancel();
        _sub = null;
        await paymentSignalRService.disconnect();
        _activeUserId = null;
      } else {
        await paymentSignalRService.connect();
        _sub ??= paymentSignalRService.paymentStream.listen(_handlePaymentEvent);
        _activeUserId = userId;
      }
    });
  }

  void _handlePaymentEvent(Map<String, dynamic> payload) {
    final statusRaw = (payload['status'] ?? '').toString();
    final status = statusRaw.toLowerCase();
    final amount = (payload['amount'] as num?)?.toDouble();
    final month = payload['month']?.toString();
    final year = payload['year']?.toString();
    final apartment = payload['apartmentCode']?.toString();
    final invoiceLabel = [
      if (month != null && year != null) 'Hóa đơn $month/$year' else 'Hóa đơn',
      if (apartment != null && apartment.isNotEmpty) 'căn $apartment'
    ].join(' ');

    String statusText;
    if (status == 'success') {
      statusText = 'đã thanh toán thành công';
    } else if (status == 'failed') {
      statusText = 'thanh toán thất bại';
    } else if (status == 'pending') {
      statusText = 'đang chờ thanh toán';
    } else {
      statusText = 'cập nhật trạng thái $statusRaw';
    }

    final amountText = amount != null ? ' (${_currency.format(amount)})' : '';
    final message = '$invoiceLabel $statusText$amountText'.trim();

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// Gate: auto-login, sau đó điều hướng theo trạng thái/role
class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = context.read<AuthState>();
    await auth.tryAutoLogin();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Đang tải...',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final auth = context.watch<AuthState>();

    // Chưa đăng nhập -> màn Login
    if (!auth.isLoggedIn) return const LoginPage();

    // Đã đăng nhập nhưng chưa duyệt -> thông báo chờ duyệt
    if (!auth.isApproved) {
      return Scaffold(
        appBar: AppBar(title: const Text('ICitizen')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_top,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tài khoản của bạn đang chờ Ban quản lý duyệt.\n'
                      'Bạn sẽ dùng được đầy đủ tính năng sau khi được duyệt.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => auth.logout(),
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Điều hướng theo role
    if (auth.roles.contains('Manager')) return ManagerShell(key: managerShellKey);
    if (auth.roles.contains('Security')) return const SecurityShell();
    if (auth.roles.contains('Vendor')) return const VendorShell();

    // Còn lại -> shell mặc định cho cư dân
    return const AppShell();
  }
}
