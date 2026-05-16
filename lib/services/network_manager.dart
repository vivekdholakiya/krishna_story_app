import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:flutter/material.dart';
import 'network_dialogue.dart';

class InternetService {
  static final InternetService _instance = InternetService._internal();
  factory InternetService() => _instance;
  InternetService._internal();

  final _connectivity = Connectivity();
  final _internetChecker = InternetConnection();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<InternetStatus>? _internetSub;

  bool _isInitialized = false;
  bool _dialogVisible = false;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void init() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    _internetSub = _internetChecker.onStatusChange.listen(_onInternetStatusChanged);
    Future.delayed(const Duration(milliseconds: 500), () async {
      await initialCheck();
      _isInitialized = true;
    });
  }

  Future<void> initialCheck() async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      _showBlockingDialog();
      return;
    }
    final hasInternet = await _internetChecker.hasInternetAccess;
    hasInternet ? _closeBlockingDialog() : _showBlockingDialog();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!_isInitialized) return;
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _showBlockingDialog();
    }
  }

  void _onInternetStatusChanged(InternetStatus status) {
    if (!_isInitialized) return;
    if (status == InternetStatus.connected) {
      _closeBlockingDialog();
    } else {
      _showBlockingDialog();
    }
  }

  void _showBlockingDialog() {
    if (_dialogVisible) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    _dialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (_) => AbsorbPointer(
        child: Center(child: NoInternetConnection(onRetry: initialCheck)),
      ),
    );
  }

  void _closeBlockingDialog() {
    if (!_dialogVisible) return;
    _dialogVisible = false;
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _internetSub?.cancel();
  }
}
