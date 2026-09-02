import 'package:flutter/material.dart';

import '../services/app_update_service.dart';

class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({
    super.key,
    required this.currentVersion,
    required this.minimumSupportedVersion,
  });

  final String currentVersion;
  final String minimumSupportedVersion;

  @override
  State<ForceUpdateScreen> createState() =>
      _ForceUpdateScreenState();
}

class _ForceUpdateScreenState
    extends State<ForceUpdateScreen> {
  bool _loading = false;

  Future<void> _updateApp() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final opened =
          await AppUpdateService.instance
              .openPlayStore();

      if (!opened && mounted) {
        _showMessage(
          'Unable to open Google Play Store.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Unable to open Google Play Store.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF8F7FC),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 28,
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          const LinearGradient(
                        begin:
                            Alignment.topLeft,
                        end:
                            Alignment.bottomRight,
                        colors: [
                          Color(0xFF6B2BDE),
                          Color(0xFF35108C),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF4217B8,
                          ).withOpacity(0.25),
                          blurRadius: 25,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Colors.white,
                      size: 62,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'POWER FAN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF2B0B78),
                      fontSize: 30,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'UPDATE APP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4217B8),
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'A new version of POWER FAN is required to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 22),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        _versionRow(
                          'Your version',
                          widget.currentVersion,
                        ),
                        const SizedBox(height: 10),
                        _versionRow(
                          'Required version',
                          widget
                              .minimumSupportedVersion,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed:
                          _loading
                              ? null
                              : _updateApp,
                      icon: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .system_update_alt_rounded,
                              size: 25,
                            ),
                      label: Text(
                        _loading
                            ? 'OPENING PLAY STORE...'
                            : 'UPDATE APP',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF4217B8,
                        ),
                        foregroundColor:
                            Colors.white,
                        disabledBackgroundColor:
                            const Color(
                          0xFF8D76CF,
                        ),
                        disabledForegroundColor:
                            Colors.white,
                        elevation: 2,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Please update to continue mining.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _versionRow(
    String title,
    String value,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF35148F),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
