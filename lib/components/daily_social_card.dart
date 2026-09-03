import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DailySocialTask {
  final String id;
  final String platform;
  final String title;
  final String description;
  final String url;
  final double reward;
  final bool completed;

  const DailySocialTask({
    required this.id,
    required this.platform,
    required this.title,
    required this.description,
    required this.url,
    required this.reward,
    this.completed = false,
  });

  DailySocialTask copyWith({
    bool? completed,
  }) {
    return DailySocialTask(
      id: id,
      platform: platform,
      title: title,
      description: description,
      url: url,
      reward: reward,
      completed: completed ?? this.completed,
    );
  }
}

class DailySocialCard extends StatelessWidget {
  final List<DailySocialTask> tasks;
  final Future<void> Function(DailySocialTask task)? onClaim;
  final bool loading;

  const DailySocialCard({
    super.key,
    required this.tasks,
    this.onClaim,
    this.loading = false,
  });

  static const Map<String, String> officialLinks = {
    'facebook': 'https://www.facebook.com/share/18ipQKYcCV/',
    'youtube': 'https://youtube.com/@powerfannetwork?si=yHAa0uXznTHB4SfN',
    'tiktok':
        'https://www.tiktok.com/@power.fan.network?_r=1&_t=ZP-98wsX6qxjV0',
    'x': 'https://x.com/Powerfannetwork',
    'telegram': 'https://t.me/PowerFannetwork',
    'instagram': 'https://www.instagram.com/powerfannetwok/',
  };

  static const List<Map<String, String>> _defaultPlatforms = [
    {
      'id': 'facebook',
      'platform': 'Facebook',
      'description':
          'Follow POWER FAN NETWORK on Facebook.',
    },
    {
      'id': 'youtube',
      'platform': 'YouTube',
      'description':
          'Subscribe to POWER FAN NETWORK on YouTube.',
    },
    {
      'id': 'tiktok',
      'platform': 'TikTok',
      'description':
          'Follow POWER FAN NETWORK on TikTok.',
    },
    {
      'id': 'x',
      'platform': 'X',
      'description':
          'Follow POWER FAN NETWORK on X.',
    },
    {
      'id': 'telegram',
      'platform': 'Telegram',
      'description':
          'Join the official POWER FAN NETWORK Telegram.',
    },
    {
      'id': 'instagram',
      'platform': 'Instagram',
      'description':
          'Follow POWER FAN NETWORK on Instagram.',
    },
  ];

  Future<void> _openSocialLink(
    BuildContext context,
    DailySocialTask task,
  ) async {
    final uri = Uri.tryParse(task.url);

    if (uri == null) {
      _showMessage(
        context,
        'Invalid social media link.',
      );
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showMessage(
          context,
          'Unable to open ${task.platform}.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(
          context,
          'Unable to open ${task.platform}.',
        );
      }
    }
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  String _normalizePlatform(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  String _getPlatformKey(DailySocialTask task) {
    final platform =
        _normalizePlatform(task.platform);

    if (platform.contains('facebook')) {
      return 'facebook';
    }

    if (platform.contains('youtube')) {
      return 'youtube';
    }

    if (platform.contains('tiktok')) {
      return 'tiktok';
    }

    if (platform == 'x' ||
        platform.contains('twitter')) {
      return 'x';
    }

    if (platform.contains('telegram')) {
      return 'telegram';
    }

    if (platform.contains('instagram')) {
      return 'instagram';
    }

    return platform;
  }

  IconData _platformIcon(String platform) {
    switch (_getPlatformKey(
      DailySocialTask(
        id: '',
        platform: platform,
        title: '',
        description: '',
        url: '',
        reward: 0,
      ),
    )) {
      case 'facebook':
        return Icons.facebook;

      case 'youtube':
        return Icons.play_circle_fill;

      case 'tiktok':
        return Icons.music_note;

      case 'x':
        return Icons.close;

      case 'telegram':
        return Icons.send;

      case 'instagram':
        return Icons.camera_alt;

      default:
        return Icons.public;
    }
  }

  Color _platformColor(String platform) {
    switch (_getPlatformKey(
      DailySocialTask(
        id: '',
        platform: platform,
        title: '',
        description: '',
        url: '',
        reward: 0,
      ),
    )) {
      case 'facebook':
        return const Color(0xFF1877F2);

      case 'youtube':
        return const Color(0xFFFF0000);

      case 'tiktok':
        return Colors.black;

      case 'x':
        return Colors.black;

      case 'telegram':
        return const Color(0xFF229ED9);

      case 'instagram':
        return const Color(0xFFE1306C);

      default:
        return const Color(0xFF3B159B);
    }
  }

  List<DailySocialTask> _buildDisplayTasks() {
    if (tasks.isEmpty) {
      return _defaultPlatforms.map((item) {
        final id = item['id']!;
        final platform = item['platform']!;

        return DailySocialTask(
          id: id,
          platform: platform,
          title: 'Follow on $platform',
          description: item['description']!,
          url: officialLinks[id]!,
          reward: 10.0,
        );
      }).toList();
    }

    return tasks.map((task) {
      final key = _getPlatformKey(task);
      final officialUrl = officialLinks[key];

      return DailySocialTask(
        id: task.id,
        platform: task.platform,
        title: task.title.isEmpty
            ? 'Follow on ${task.platform}'
            : task.title,
        description: task.description,
        url: officialUrl ?? task.url,
        reward: task.reward <= 0
            ? 10.0
            : task.reward,
        completed: task.completed,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayTasks =
        _buildDisplayTasks();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(
                    color: const Color(
                      0xFF3B159B,
                    ).withOpacity(0.10),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons.public,
                    color:
                        Color(0xFF3B159B),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Social Tasks',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Follow our official social media pages',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(
                color: const Color(
                  0xFF3B159B,
                ).withOpacity(0.06),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.card_giftcard,
                    size: 20,
                    color:
                        Color(0xFF3B159B),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete your daily social tasks and earn FAN rewards.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...displayTasks.map(
              (task) => _buildTask(
                context,
                task,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTask(
    BuildContext context,
    DailySocialTask task,
  ) {
    final platformColor =
        _platformColor(task.platform);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: platformColor
                  .withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              _platformIcon(
                task.platform,
              ),
              color: platformColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  task.platform,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  task.description,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+${task.reward.toStringAsFixed(0)} FAN',
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF159B61),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              SizedBox(
                height: 34,
                child:
                    OutlinedButton(
                  onPressed: loading
                      ? null
                      : () =>
                          _openSocialLink(
                            context,
                            task,
                          ),
                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),
                  ),
                  child:
                      const Text(
                    'OPEN',
                    style:
                        TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 34,
                child:
                    ElevatedButton(
                  onPressed: loading ||
                          task.completed
                      ? null
                      : onClaim == null
                          ? null
                          : () =>
                              onClaim!(
                                task,
                              ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF3B159B,
                    ),
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        Colors.grey.shade300,
                    disabledForegroundColor:
                        Colors.grey.shade600,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: task.completed
                      ? const Icon(
                          Icons.check,
                          size: 16,
                        )
                      : const Text(
                          'CLAIM',
                          style:
                              TextStyle(
                            fontSize: 10,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
