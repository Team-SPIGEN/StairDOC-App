import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'providers/auth/auth_bloc.dart';
import 'providers/notification/notification_cubit.dart';
import 'routes/app_router.dart';
import 'services/auth_service.dart';
import 'services/container_access_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const StairDocApp());
}

class StairDocApp extends StatefulWidget {
  const StairDocApp({super.key});

  @override
  State<StairDocApp> createState() => _StairDocAppState();
}

class _StairDocAppState extends State<StairDocApp> {
  late final AuthService _authService;
  late final StorageService _storageService;
  late final ContainerAccessService _containerAccessService;
  late final NotificationService _notificationService;
  late final AuthBloc _authBloc;
  late final NotificationCubit _notificationCubit;
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _storageService = StorageService();
    _containerAccessService = ContainerAccessService();
    _notificationService = NotificationService();
    _authBloc = AuthBloc(
      authService: _authService,
      storageService: _storageService,
    );
    _notificationCubit = NotificationCubit(
      notificationService: _notificationService,
    );
    _appRouter = AppRouter(_authBloc);
  }

  @override
  void dispose() {
    _authBloc.close();
    _notificationCubit.close();
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthService>.value(value: _authService),
        RepositoryProvider<StorageService>.value(value: _storageService),
        RepositoryProvider<ContainerAccessService>.value(
          value: _containerAccessService,
        ),
        RepositoryProvider<NotificationService>.value(
          value: _notificationService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _authBloc),
          BlocProvider<NotificationCubit>.value(value: _notificationCubit),
        ],
        child: MaterialApp.router(
          title: 'Delivery Robot Control',
          themeMode: ThemeMode.system,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          routerConfig: _appRouter.router,
        ),
      ),
    );
  }
}
