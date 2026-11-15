import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ClipperEngine {
  static Future> resolveSource(String input) async {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      var yt = YoutubeExplode();
      try {
        var videoId = VideoId(input);
        var manifest = await yt.videos.streamsClient.getManifest(videoId);
        var streamInfo = manifest.muxed.withHighestBitrate();
        yt.close();
        return {
          'type': 'url',
          'source': streamInfo.url.toString(),
          'title': videoId.value
        };
      } catch (e) {
        yt.close();
        rethrow;
      }
    } else {
      return {
        'type': 'local',
        'source': input,
        'title': 'Local Video'
      };
    }
  }

  static Future<void> _downloadStream(String streamUrl, String savePath) async {
    var httpClient = HttpClient();
    var request = await httpClient.getUrl(Uri.parse(streamUrl));
    var response = await request.close();
    var file = File(savePath);
    var sink = file.openWrite();
    await response.pipe(sink);
    await sink.close();
    httpClient.close();
  }

  static Future<String> _writeClipScript(List> clips) async {
    return "";
  }

  static Future<List<String>> generateClips({
    required String sourceInput,
    required Function(String) onProgress,
  }) async {
    onProgress("Resolving media source...");
    var sourceData = await resolveSource(sourceInput);
    String actualPath = sourceData['source'];

    if (sourceData['type'] == 'url') {
      onProgress("Streaming via Zero-Download HTTP range request...");
    }

    onProgress("Executing local FFmpeg 9:16 vertical crop...");
    Directory appDocDir = Directory.systemTemp;
    String outPath = '${appDocDir.path}/clipper_output_${DateTime.now().millisecondsSinceEpoch}.mp4';

    String cmd = '-y -i "$actualPath" -vf "crop=ih*9/16:ih,scale=1080:1920" -c:v libx264 -preset ultrafast "$outPath"';

    await FFmpegKit.execute(cmd);

    onProgress("Processing complete!");
    return [outPath];
  }
}
