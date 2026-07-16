import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/network/database_service.dart';
import 'core/network/supabase_sync_service.dart';
import 'core/utils/notification_helper.dart';
import 'core/theme/theme_manager.dart';
import 'features/catalog/data/repositories/shade_matcher_repository_impl.dart';
import 'features/scanner/presentation/bloc/scanner_bloc.dart';
import 'features/home/presentation/pages/home_page.dart';

void main() async {
  // Pastikan binding Flutter terinisialisasi sebelum pengerjaan asinkron
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi pengatur tema dinamis dari berkas lokal
  await ThemeManager.init();

  // Inisialisasi klien Supabase jika kredensial lingkungan disediakan
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
      );
    } catch (e) {
      debugPrint("SUPABASE_INIT_ERROR: Gagal inisialisasi Supabase: $e");
    }
  }

  // Inisialisasi Database Isar lokal dan lakukan seeding data
  final dbService = DatabaseService();
  await dbService.init();

  // Jalankan sinkronisasi katalog luring-daring di latar belakang secara asinkron
  if (SupabaseSyncService.isInitialized) {
    SupabaseSyncService.syncCatalog(dbService.isar).then((_) {
      SupabaseSyncService.syncOfflineReviews(dbService.isar);
    });
  }

  // Inisialisasi sistem notifikasi lokal luring
  await NotificationHelper.init();

  runApp(MyApp(dbService: dbService));
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;

  const MyApp({
    super.key,
    required this.dbService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ScannerBloc>(
          create: (context) => ScannerBloc(
            shadeMatcherRepository: ShadeMatcherRepositoryImpl(dbService),
          ),
        ),
      ],
      child: ValueListenableBuilder<AppThemeType>(
        valueListenable: ThemeManager.themeNotifier,
        builder: (context, currentTheme, child) {
          final isDark = ThemeManager.isDark;
          return MaterialApp(
            title: 'GlowMatch',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: isDark ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: ThemeManager.scaffoldBgColor,
              colorScheme: ColorScheme.fromSeed(
                seedColor: ThemeManager.primaryColor,
                brightness: isDark ? Brightness.dark : Brightness.light,
                surface: ThemeManager.scaffoldBgColor,
                primary: ThemeManager.primaryColor,
                secondary: ThemeManager.secondaryColor,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: ThemeManager.scaffoldBgColor,
                elevation: 0,
                iconTheme: IconThemeData(color: ThemeManager.textColor),
                titleTextStyle: TextStyle(
                  color: ThemeManager.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
