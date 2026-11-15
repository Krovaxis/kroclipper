import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ClipperEngine {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Resolves a YouTube URL into a direct stream URL (Zero-Download) or local cached file
  static Future> resolveSource({
    required String? url,
    required String? localFilePath,
    required bool zeroDownloadMode,
    required Function(String) onStatus,
  }) async {
    if (localFilePath != null && localFilePath.isNotEmpty) {
      return {
        'videoSource': localFilePath,
        'audioSource': null,
        'durationSec': 300, // Fallback if duration not probed
        'subtitles': <ClosedCaption>[],
      };
    }

    if (url == null || url.trim().isEmpty) {
      throw Exception('Please paste a valid video URL or pick a local file.');
    }

    onStatus('Fetching stream metadata...');
    final video = await _yt.videos.get(url.trim());
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);

    // Grab highest quality MP4 video-only + M4A audio-only streams
    final videoStream = manifest.videoOnly
        .where((s) => s.container == StreamContainer.mp4)
        .withHighestBitrate();
    final audioStream = manifest.audioOnly.withHighestBitrate();

    // Fetch closed captions if available
    List<ClosedCaption> captions = [];
    try {
      final trackManifest = await _yt.videos.closedCaptions.getManifest(video.id);
      if (trackManifest.tracks.isNotEmpty) {
        final trackInfo = trackManifest.getByLanguage('en').firstOrNull ??
            trackManifest.tracks.first;
        final track = await _yt.videos.closedCaptions.get(trackInfo);
        captions = track.captions;
      }
    } catch (_) {
      // Video has no captions track; continue cleanly
    }

    if (zeroDownloadMode) {
      return {
        'videoSource': videoStream.url.toString(),
        'audioSource': audioStream.url.toString(),
        'durationSec': video.duration?.inSeconds ?? 180,
        'subtitles': captions,
      };
    } else {
      // Download locally to 500GB storage cache for fast offline batch cutting
      onStatus('Caching HD streams to device storage...');
      final cacheDir = await getTemporaryDirectory();
      final vPath = '${cacheDir.path}/src_${video.id.value}_v.mp4';
      final aPath = '${cacheDir.path}/src_${video.id.value}_a.m4a';

      await _downloadStream(videoStream, vPath);
      await _downloadStream(audioStream, aPath);

      return {
        'videoSource': vPath,
        'audioSource': aPath,
        'durationSec': video.duration?.inSeconds ?? 180,
        'subtitles': captions,
      };
    }
  }

  static Future<void> _downloadStream(StreamInfo info, String savePath) async {
    final file = File(savePath);
    if (await file.exists()) return;
    final stream = _yt.videos.streamsClient.get(info);
    final sink = file.openWrite();
    await stream.pipe(sink);
    await sink.flush();
    await sink.close();
  }

  /// Generates a temporary SRT file for the specific clip window
  static Future<String?> _writeClipSrt({
    required List<ClosedCaption> captions,
    required int startSec,
    required int durationSec,
    required int clipIndex,
  }) async {
    if (captions.isEmpty) return null;
    final endSec = startSec + durationSec;
    final buffer = StringBuffer();
    int counter = 1;

    for (final cap in captions) {
      final cStart = cap.offset.inMilliseconds / 1000.0;
      final cEnd = (cap.offset + cap.duration).inMilliseconds / 1000.0;
      if (cEnd >= startSec && cStart <= endSec) {
        final relStart = (cStart - startSec).clamp(0.0, durationSec.toDouble());
        final relEnd = (cEnd - startSec).clamp(0.0, durationSec.toDouble());
        buffer.writeln(counter++);
        buffer.writeln('${_formatSrtTime(relStart)} --> ${_formatSrtTime(relEnd)}');
        buffer.writeln(cap.text.replaceAll('\n', ' ').toUpperCase());
        buffer.writeln();
      }
    }

    if (counter == 1) return null;
    final dir = await getTemporaryDirectory();
    final srtFile = File('${dir.path}/sub_$clipIndex.srt');
    await srtFile.writeAsString(buffer.toString());
    return srtFile.path;
  }

  static String _formatSrtTime(double seconds) {
    final ms = (seconds * 1000).round();
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final remMs = (ms % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$remMs';
  }

  /// Renders vertical 9:16 clips with optional captions & color filters
  static Future<List<String>> generateClips({
    required Map<String, dynamic> sourceData,
    required int clipCount,
    required int clipDurationSec,
    required bool burnCaptions,
    required String filterPreset,
    required String framingMode,
    required Function(String) onStatus,
  }) async {
    final String videoSrc = sourceData['videoSource'];
    final String? audioSrc = sourceData['audioSource'];
    final int totalDuration = sourceData['durationSec'];
    final List<ClosedCaption> captions = sourceData['subtitles'];

    // Save directly to Android Movies/Clipper folder
    final Directory outDir = Directory('/storage/emulated/0/Movies/Clipper');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final List<String> renderedPaths = [];
    final int usableDuration = (totalDuration - 20).clamp(clipDurationSec, totalDuration);
    final int step = clipCount > 1
        ? ((usableDuration - clipDurationSec) ~/ (clipCount - 1)).clamp(clipDurationSec, 99999)
        : 0;

    for (int i = 0; i < clipCount; i++) {
      final int startSec = (10 + (i * step)).clamp(0, (totalDuration - clipDurationSec).clamp(0, 99999));
      onStatus('Rendering Clip ${i + 1} of $clipCount (${startSec}s - ${startSec + clipDurationSec}s)...');

      final String outPath =
          '${outDir.path}/clip_${DateTime.now().millisecondsSinceEpoch}_${i + 1}.mp4';

      // Build Video Filter Chain
      final List<String> vf = [];

      // 1. Framing (9:16 Center Punch-In vs Blurred Background Fit)
      if (framingMode == 'Blurred Fit') {
        vf.add(
          '[0:v]split=2[bg][fg];'
          '[bg]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=20:5[bg_b];'
          '[fg]scale=1080:-2[fg_s];'
          '[bg_b][fg_s]overlay=(W-w)/2:(H-h)/2',
        );
      } else {
        vf.add('scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920');
      }

      // 2. Color Grading Presets
      if (filterPreset == 'Dark & Moody') {
        vf.add('eq=contrast=1.18:brightness=-0.04:saturation=0.88,vignette=PI/4');
      } else if (filterPreset == 'Vibrant Punch') {
        vf.add('eq=contrast=1.12:saturation=1.28:brightness=0.02');
      } else if (filterPreset == 'High Contrast') {
        vf.add('eq=contrast=1.25:saturation=1.05,unsharp=5:5:0.8:5:5:0.0');
      }

      // 3. Kinetic-Style Burned Subtitles
      if (burnCaptions) {
        final srtPath = await _writeClipSrt(
          captions: captions,
          startSec: startSec,
          durationSec: clipDurationSec,
          clipIndex: i,
        );
        if (srtPath != null) {
          vf.add(
            "subtitles='$srtPath':force_style='Fontsize=18,PrimaryColour=&H0000FFFF,"
            "OutlineColour=&H00000000,BorderStyle=1,Outline=2,Shadow=1,Alignment=2,MarginV=65'",
          );
        }
      }

      final String filterGraph = vf.join(',');
      final String inputArgs = audioSrc != null
          ? '-ss $startSec -t $clipDurationSec -i "$videoSrc" -ss $startSec -t $clipDurationSec -i "$audioSrc" -map 0:v:0 -map 1:a:0'
          : '-ss $startSec -t $clipDurationSec -i "$videoSrc"';

      final String cmd =
          '$inputArgs -vf "$filterGraph" -c:v libx264 -preset ultrafast -crf 23 '
          '-c:a aac -b:a 128k -af loudnorm=I=-14:TP=-1.5:LRA=11 -y "$outPath"';

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();

      if (ReturnCode.isSuccess(rc)) {
        renderedPaths.add(outPath);
      } else {
        final logs = await session.getAllLogsAsString();
        throw Exception('FFmpeg failed on clip ${i + 1}: $logs');
      }
    }

    return renderedPaths;
  }
}

