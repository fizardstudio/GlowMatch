import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/network/database_service.dart';
import 'core/theme/theme_manager.dart';
import 'features/catalog/data/repositories/shade_matcher_repository_impl.dart';
import 'features/scanner/presentation/bloc/scanner_bloc.dart';
import 'features/home/presentation/pages/home_page.dart';

void main() async {
  // Pastikan binding Flutter terinisialisasi sebelum pengerjaan asinkron
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi pengatur tema dinamis dari berkas lokal
  await ThemeManager.init();

  // Inisialisasi Database Isar lokal dan lakukan seeding data
  final dbService = DatabaseService();
  await dbService.init();

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
