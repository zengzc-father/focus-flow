import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// 白噪音类型
enum WhiteNoiseType {
  rain('雨声', Icons.water_drop, 'assets/audio/rain.mp3'),
  forest('森林', Icons.forest, 'assets/audio/forest.mp3'),
  cafe('咖啡厅', Icons.coffee, 'assets/audio/cafe.mp3'),
  waves('海浪', Icons.waves, 'assets/audio/waves.mp3'),
  wind('风声', Icons.air, 'assets/audio/wind.mp3'),
  fire('篝火', Icons.local_fire_department, 'assets/audio/fire.mp3'),
  white('白噪音', Icons.volume_up, 'assets/audio/white.mp3'),
  none('无声', Icons.volume_off, '');

  final String label;
  final IconData icon;
  final String assetPath;

  const WhiteNoiseType(this.label, this.icon, this.assetPath);
}

/// 白噪音播放器（完整版）
class WhiteNoisePlayerWidget extends StatefulWidget {
  const WhiteNoisePlayerWidget({super.key});

  @override
  State<WhiteNoisePlayerWidget> createState() => _WhiteNoisePlayerWidgetState();
}

class _WhiteNoisePlayerWidgetState extends State<WhiteNoisePlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  WhiteNoiseType _currentType = WhiteNoiseType.none;
  double _volume = 0.5;
  bool _isPlaying = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> _playNoise(WhiteNoiseType type) async {
    if (type == WhiteNoiseType.none) {
      await _audioPlayer.stop();
      setState(() {
        _currentType = type;
        _isPlaying = false;
      });
      return;
    }

    try {
      // TODO: 实际项目中需要添加音频资源
      // await _audioPlayer.play(AssetSource(type.assetPath));
      setState(() {
        _currentType = type;
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('播放白噪音失败: $e');
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else if (_currentType != WhiteNoiseType.none) {
      await _playNoise(_currentType);
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _setVolume(double value) async {
    await _audioPlayer.setVolume(value);
    setState(() => _volume = value);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return _buildCollapsedView();
    }
    return _buildExpandedView();
  }

  Widget _buildCollapsedView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _currentType == WhiteNoiseType.none
                ? Icons.volume_off
                : Icons.volume_up,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentType == WhiteNoiseType.none
                  ? '白噪音'
                  : _currentType.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isExpanded = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.expand_more,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Row(
            children: [
              const Icon(
                Icons.headphones,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '白噪音',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = false),
                child: const Icon(
                  Icons.expand_less,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 白噪音选择网格
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: WhiteNoiseType.values.map((type) {
              final isSelected = _currentType == type;
              return GestureDetector(
                onTap: () => _playNoise(type),
                child: Container(
                  width: 70,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF00BFA5), width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        type.icon,
                        color: isSelected ? Colors.white : Colors.white70,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // 音量控制
          if (_currentType != WhiteNoiseType.none)
            Row(
              children: [
                const Icon(
                  Icons.volume_mute,
                  color: Colors.white70,
                  size: 16,
                ),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: _setVolume,
                    activeColor: const Color(0xFF00BFA5),
                    inactiveColor: Colors.white.withOpacity(0.2),
                  ),
                ),
                const Icon(
                  Icons.volume_up,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 白噪音预览（设置页面用）
class WhiteNoisePlayerPreview extends StatelessWidget {
  const WhiteNoisePlayerPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '专注环境',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildNoiseChip('雨声', Icons.water_drop, const Color(0xFF4A90D9)),
              const SizedBox(width: 8),
              _buildNoiseChip('森林', Icons.forest, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildNoiseChip('海浪', Icons.waves, const Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              _buildNoiseChip('咖啡厅', Icons.coffee, const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoiseChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
