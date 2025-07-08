import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// 录音状态
enum RecordingState {
  /// 录音中
  recording,
  /// 暂停中
  paused,
  /// 已完成
  completed,
}

/// 自定义语音录制嵌入类型
class AudioRecordingBlockEmbed extends CustomBlockEmbed {
  static const String audioRecordingType = 'audio-recording';

  AudioRecordingBlockEmbed(String value) : super(audioRecordingType, value);

  /// 创建一个新的录音嵌入（录音中状态）
  static AudioRecordingBlockEmbed createNew() {
    final recordingData = {
      'path': '',
      'duration': '00:00:00',
      'timestamp': DateFormat('yyyy年M月d日 HH:mm:ss').format(DateTime.now()),
      'state': RecordingState.recording.index,
    };
    return AudioRecordingBlockEmbed(jsonEncode(recordingData));
  }

  /// 从已有数据创建录音嵌入
  static AudioRecordingBlockEmbed fromDocument(String path, String duration, [String? timestamp, RecordingState state = RecordingState.completed]) {
    // 构造格式: 路径|持续时间|时间戳|状态
    final recordingData = {
      'path': path,
      'duration': duration,
      'timestamp': timestamp ?? DateFormat('yyyy年M月d日 HH:mm:ss').format(DateTime.now()),
      'state': state.index,
    };
    return AudioRecordingBlockEmbed(jsonEncode(recordingData));
  }

  /// 更新录音状态
  AudioRecordingBlockEmbed updateState(RecordingState newState, {String? path, String? duration}) {
    final Map<String, dynamic> jsonData = jsonDecode(data);
    jsonData['state'] = newState.index;
    if (path != null) {
      jsonData['path'] = path;
    }
    if (duration != null) {
      jsonData['duration'] = duration;
    }
    return AudioRecordingBlockEmbed(jsonEncode(jsonData));
  }

  /// 获取音频文件路径
  String get audioPath {
    final Map<String, dynamic> jsonData = jsonDecode(data);
    return jsonData['path'] as String;
  }

  /// 获取音频持续时间
  String get duration {
    final Map<String, dynamic> jsonData = jsonDecode(data);
    return jsonData['duration'] as String;
  }

  /// 获取录制时间戳
  String get timestamp {
    final Map<String, dynamic> jsonData = jsonDecode(data);
    return jsonData['timestamp'] as String;
  }

  /// 获取录音状态
  RecordingState get state {
    final Map<String, dynamic> jsonData = jsonDecode(data);
    final stateIndex = jsonData['state'] as int? ?? RecordingState.completed.index;
    return RecordingState.values[stateIndex];
  }
}

/// 语音录制嵌入构建器
class AudioRecordingEmbedBuilder extends EmbedBuilder {
  @override
  String get key => AudioRecordingBlockEmbed.audioRecordingType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final embed = AudioRecordingBlockEmbed(embedContext.node.value.data);
    final state = embed.state;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: state == RecordingState.completed 
          ? AudioRecordingPlayerWidget(
              audioPath: embed.audioPath,
              duration: embed.duration,
              timestamp: embed.timestamp,
            )
          : InlineAudioRecordingWidget(
              initialState: state,
              initialDuration: embed.duration,
              timestamp: embed.timestamp,
              onStateChanged: (newState, path, duration) {
                // 创建一个新的嵌入块
                final newEmbed = embed.updateState(newState, path: path, duration: duration);
                
                // 尝试获取编辑器控制器
                final controller = _findQuillControllerInContext(context);
                if (controller != null) {
                  final index = embedContext.node.documentOffset;
                  
                  // 使用 replaceText 原子替换，避免先删再插导致索引偏移
                  if (index >= 0 && index < controller.document.length) {
                    // 原子替换旧嵌入为新嵌入
                    controller.replaceText(
                      index,
                      1,
                      newEmbed,
                      controller.selection,
                    );

                    // 若替换后当前位置不是换行,插入换行符保持布局一致
                    if (index + 1 >= controller.document.length ||
                        controller.document.getPlainText(index + 1, index + 2) != '\n') {
                      controller.document.insert(index + 1, '\n');
                    }
                  }
                }
                
                // 如果是完成状态，强制重新构建组件
                if (newState == RecordingState.completed) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (context.mounted) {
                      // 触发一个setState以重新构建组件
                      (context as Element).markNeedsBuild();
                    }
                  });
                }
              },
            ),
    );
  }
  
  // 尝试在上下文中查找QuillController
  QuillController? _findQuillControllerInContext(BuildContext context) {
    // 尝试从上下文中查找最近的QuillController
    // 这是一个简单的实现，可能需要根据实际情况调整
    try {
      // 向上遍历Widget树，尝试找到QuillController
      BuildContext? currentContext = context;
      while (currentContext != null) {
        final widget = currentContext.widget;
        if (widget is! StatefulWidget) {
          currentContext = currentContext.findAncestorStateOfType<State<StatefulWidget>>()?.context;
          continue;
        }
        
        final state = currentContext.findAncestorStateOfType<State<StatefulWidget>>();
        if (state != null) {
          // 尝试通过反射获取controller字段
          try {
            final controller = (state as dynamic).controller;
            if (controller is QuillController) {
              return controller;
            }
          } catch (e) {
            // 忽略错误，继续搜索
          }
        }
        
        // 继续向上查找
        currentContext = currentContext.findAncestorStateOfType<State<StatefulWidget>>()?.context;
      }
    } catch (e) {
      debugPrint('查找QuillController时出错: $e');
    }
    
    return null;
  }
}

/// 内联语音录制小部件 - 直接在编辑器中显示并处理录音
class InlineAudioRecordingWidget extends StatefulWidget {
  /// 初始录音状态
  final RecordingState initialState;
  
  /// 初始录音时长
  final String initialDuration;
  
  /// 时间戳
  final String timestamp;
  
  /// 状态变化回调
  final Function(RecordingState newState, String path, String duration) onStateChanged;

  const InlineAudioRecordingWidget({
    super.key,
    this.initialState = RecordingState.recording,
    this.initialDuration = '00:00:00',
    required this.timestamp,
    required this.onStateChanged,
  });

  @override
  State<InlineAudioRecordingWidget> createState() => _InlineAudioRecordingWidgetState();
}

class _InlineAudioRecordingWidgetState extends State<InlineAudioRecordingWidget> {
  final _audioRecorder = AudioRecorder();
  late RecordingState _recordingState;
  String _recordingPath = '';
  String _recordedDuration = '00:00:00';
  Timer? _timer;
  int _recordingDuration = 0;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _recordingState = widget.initialState;
    _recordedDuration = widget.initialDuration;
    
    // 如果初始状态是录音中，则开始录音
    if (_recordingState == RecordingState.recording) {
      _requestPermissionAndStartRecording();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopRecording(cancel: true);
    _audioRecorder.dispose();
    super.dispose();
  }

  /// 请求权限并开始录音
  Future<void> _requestPermissionAndStartRecording() async {
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      await _startRecording();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录音')),
        );
      }
    }
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'audio_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${appDir.path}/$fileName';

      // 检查录音权限
      if (await _audioRecorder.hasPermission()) {
        // 配置录音
        final config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );
        
        // 开始录音
        await _audioRecorder.start(config, path: _recordingPath);
        
        setState(() {
          _recordingState = RecordingState.recording;
          _recordingDuration = 0;
          _recordedDuration = '00:00:00';
        });
        
        // 通知父组件状态变化
        widget.onStateChanged(_recordingState, _recordingPath, _recordedDuration);
        
        // 启动计时器，更新显示的录音时长
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_recordingState == RecordingState.recording) {
            setState(() {
              _recordingDuration++;
              _updateDurationDisplay();
            });
            
            // 通知父组件时长变化
            widget.onStateChanged(_recordingState, _recordingPath, _recordedDuration);
          }
        });
      }
    } catch (e) {
      debugPrint('无法开始录音: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法开始录音，请检查麦克风权限')),
        );
      }
    }
  }

  /// 暂停录音
  Future<void> _pauseRecording() async {
    if (_recordingState == RecordingState.recording) {
      await _audioRecorder.pause();
      setState(() {
        _recordingState = RecordingState.paused;
      });
      
      // 通知父组件状态变化
      widget.onStateChanged(_recordingState, _recordingPath, _recordedDuration);
    } else if (_recordingState == RecordingState.paused) {
      await _audioRecorder.resume();
      setState(() {
        _recordingState = RecordingState.recording;
      });
      
      // 通知父组件状态变化
      widget.onStateChanged(_recordingState, _recordingPath, _recordedDuration);
    }
  }

  /// 停止录音
  Future<void> _stopRecording({bool cancel = false}) async {
    _timer?.cancel();
    
    try {
      // 检查是否正在录音
      final isRecording = await _audioRecorder.isRecording();
      
      if (isRecording) {
        // 停止录音
        final path = await _audioRecorder.stop();
        
        if (path != null && !cancel && mounted) {
          setState(() {
            _recordingState = RecordingState.completed;
            _isCompleted = true;
          });
          
          // 通知父组件录音已完成
          widget.onStateChanged(RecordingState.completed, _recordingPath, _recordedDuration);
          
          // 延迟一段时间后，强制重新构建组件以显示播放器
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {});
            }
          });
        } else if (cancel) {
          // 如果取消，删除录音文件
          try {
            final file = File(_recordingPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('删除取消的录音文件失败: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('停止录音时出错: $e');
    }
  }

  /// 更新显示的录音时长
  void _updateDurationDisplay() {
    final seconds = _recordingDuration % 60;
    final minutes = (_recordingDuration ~/ 60) % 60;
    final hours = _recordingDuration ~/ 3600;
    
    _recordedDuration = '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // 如果已完成录音，直接显示播放器
    if (_isCompleted) {
      return AudioRecordingPlayerWidget(
        audioPath: _recordingPath,
        duration: _recordedDuration,
        timestamp: widget.timestamp,
      );
    }
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间戳显示
            Text(
              widget.timestamp,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 录音图标，根据状态显示不同颜色
                Icon(
                  _recordingState == RecordingState.recording 
                      ? Icons.mic 
                      : Icons.mic_none,
                  color: _recordingState == RecordingState.recording 
                      ? Colors.redAccent 
                      : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                // 录音时长
                Text(
                  _recordedDuration,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                // 根据录音状态显示不同的按钮
                if (_recordingState == RecordingState.recording || _recordingState == RecordingState.paused)
                  IconButton(
                    icon: Icon(_recordingState == RecordingState.recording 
                        ? Icons.pause 
                        : Icons.play_arrow),
                    onPressed: _pauseRecording,
                  ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => _stopRecording(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 语音录制小部件 - 用于录制新的语音
class AudioRecordingWidget extends StatefulWidget {
  /// 录制完成回调
  final Function(String path, String duration, String timestamp) onRecordingComplete;

  const AudioRecordingWidget({
    super.key,
    required this.onRecordingComplete,
  });

  @override
  State<AudioRecordingWidget> createState() => _AudioRecordingWidgetState();
}

class _AudioRecordingWidgetState extends State<AudioRecordingWidget> {
  final _audioRecorder = AudioRecorder();
  RecordingState _recordingState = RecordingState.recording;
  String _recordingPath = '';
  String _recordedDuration = '00:00:00';
  String _timestamp = '';
  Timer? _timer;
  int _recordingDuration = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStartRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopRecording(cancel: true);
    _audioRecorder.dispose();
    super.dispose();
  }

  /// 请求权限并开始录音
  Future<void> _requestPermissionAndStartRecording() async {
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      await _startRecording();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能录音')),
        );
      }
    }
  }

  /// 开始录音
  Future<void> _startRecording() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'audio_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${appDir.path}/$fileName';
      _timestamp = DateFormat('yyyy年M月d日 HH:mm:ss').format(DateTime.now());

      // 检查录音权限
      if (await _audioRecorder.hasPermission()) {
        // 配置录音
        final config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );
        
        // 开始录音
        await _audioRecorder.start(config, path: _recordingPath);
        
        setState(() {
          _recordingState = RecordingState.recording;
          _recordingDuration = 0;
          _recordedDuration = '00:00:00';
        });
        
        // 启动计时器，更新显示的录音时长
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_recordingState == RecordingState.recording) {
            setState(() {
              _recordingDuration++;
              _updateDurationDisplay();
            });
          }
        });
      }
    } catch (e) {
      debugPrint('无法开始录音: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法开始录音，请检查麦克风权限')),
        );
      }
    }
  }

  /// 暂停录音
  Future<void> _pauseRecording() async {
    if (_recordingState == RecordingState.recording) {
      await _audioRecorder.pause();
      setState(() {
        _recordingState = RecordingState.paused;
      });
    } else if (_recordingState == RecordingState.paused) {
      await _audioRecorder.resume();
      setState(() {
        _recordingState = RecordingState.recording;
      });
    }
  }

  /// 停止录音
  Future<void> _stopRecording({bool cancel = false}) async {
    _timer?.cancel();
    
    try {
      // 检查是否正在录音
      final isRecording = await _audioRecorder.isRecording();
      
      if (isRecording) {
        // 停止录音
        final path = await _audioRecorder.stop();
        
        if (path != null && !cancel && mounted) {
          setState(() {
            _recordingState = RecordingState.completed;
          });
          
          // 通知父组件录音已完成
          widget.onRecordingComplete(_recordingPath, _recordedDuration, _timestamp);
        } else if (cancel) {
          // 如果取消，删除录音文件
          try {
            final file = File(_recordingPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint('删除取消的录音文件失败: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('停止录音时出错: $e');
    }
  }

  /// 更新显示的录音时长
  void _updateDurationDisplay() {
    final seconds = _recordingDuration % 60;
    final minutes = (_recordingDuration ~/ 60) % 60;
    final hours = _recordingDuration ~/ 3600;
    
    _recordedDuration = '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // 录音图标，根据状态显示不同颜色
            Icon(
              _recordingState == RecordingState.recording 
                  ? Icons.mic 
                  : Icons.mic_none,
              color: _recordingState == RecordingState.recording 
                  ? Colors.redAccent 
                  : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            // 录音时长
            Text(
              _recordedDuration,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // 根据录音状态显示不同的按钮
            if (_recordingState == RecordingState.recording || _recordingState == RecordingState.paused)
              IconButton(
                icon: Icon(_recordingState == RecordingState.recording 
                    ? Icons.pause 
                    : Icons.play_arrow),
                onPressed: _pauseRecording,
              ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => _stopRecording(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 语音播放小部件 - 用于播放已完成的录音
class AudioRecordingPlayerWidget extends StatefulWidget {
  /// 音频文件路径
  final String audioPath;
  
  /// 音频持续时间
  final String duration;
  
  /// 录制时间戳
  final String timestamp;

  const AudioRecordingPlayerWidget({
    super.key,
    required this.audioPath,
    required this.duration,
    required this.timestamp,
  });

  @override
  State<AudioRecordingPlayerWidget> createState() => _AudioRecordingPlayerWidgetState();
}

class _AudioRecordingPlayerWidgetState extends State<AudioRecordingPlayerWidget> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String _currentPosition = '00:00';
  double _progress = 0;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.setFilePath(widget.audioPath);
      
      // 监听播放状态
      _audioPlayer.playerStateStream.listen((state) {
        if (state.playing != _isPlaying) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
        
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _isPlaying = false;
            _progress = 0;
            _currentPosition = '00:00';
          });
          _audioPlayer.seek(Duration.zero);
        }
      });

      // 监听位置变化
      _positionSub = _audioPlayer.positionStream.listen((position) {
        final duration = _audioPlayer.duration ?? Duration.zero;
        if (duration.inMilliseconds == 0) return;

        final progress = position.inMilliseconds / duration.inMilliseconds;
        final minutes = (position.inSeconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (position.inSeconds % 60).toString().padLeft(2, '0');

        setState(() {
          _progress = progress.clamp(0.0, 1.0);
          _currentPosition = '$minutes:$seconds';
        });
      });
    } catch (e) {
      debugPrint('初始化音频播放器失败: $e');
    }
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // 若已到结尾, 从头播放
      if (_audioPlayer.position >= (_audioPlayer.duration ?? Duration.zero)) {
      await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间戳显示
            Text(
              widget.timestamp,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 录音图标和播放按钮
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _playPause,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                // 进度条
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPlaying ? _currentPosition : widget.duration,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 循环按钮
                IconButton(
                  icon: const Icon(Icons.replay),
                  onPressed: () async {
                    await _audioPlayer.seek(Duration.zero);
                    if (!_isPlaying) {
                      await _audioPlayer.play();
                    }
                  },
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 