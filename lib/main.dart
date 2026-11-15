import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'clipper_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ClipperApp());
}

class ClipperApp extends StatelessWidget {
  const ClipperApp({super.key});

  @override
  Widget build(BuildContext context) {
    const cyberViolet = Color(0xFF8B5CF6);
    const oledBlack = Color(0xFF0A0A0A);
    const cardDark = Color(0xFF141414);

    return MaterialApp(
      title: 'Clipper Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: oledBlack,
        primaryColor: cyberViolet,
        colorScheme: const ColorScheme.dark(
          primary: cyberViolet,
          secondary: Color(0xFFA78BFA),
          surface: cardDark,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: cyberViolet,
          thumbColor: cyberViolet,
          inactiveTrackColor: cyberViolet.withOpacity(0.25),
        ),
      ),
      home: const ClipperHomeScreen(),
    );
  }
}

class ClipperHomeScreen extends StatefulWidget {
  const ClipperHomeScreen({super.key});

  @override
  State<ClipperHomeScreen> createState() => _ClipperHomeScreenState();
}

class _ClipperHomeScreenState extends State<ClipperHomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _pickedLocalFile;
  String? _pickedFileName;

  bool _zeroDownloadMode = true;
  double _clipCount = 3;
  int _selectedDuration = 30;
  bool _burnCaptions = true;
  String _selectedFilter = 'Dark & Moody';
  String _selectedFraming = '9:16 Punch-In';

  bool _isProcessing = false;
  String _statusText = 'Ready to clip.';
  List<String> _generatedFiles = [];

  final List<int> _durations = [15, 30, 45, 60, 90];
  final List<String> _filters = [
    'Raw / Clean',
    'Dark & Moody',
    'Vibrant Punch',
    'High Contrast',
  ];
  final List<String> _framings = ['9:16 Punch-In', 'Blurred Fit'];

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _urlController.text = data!.text!;
        _pickedLocalFile = null;
        _pickedFileName = null;
      });
    }
  }

  Future<void> _pickLocalVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedLocalFile = result.files.single.path;
        _pickedFileName = result.files.single.name;
        _urlController.clear();
      });
    }
  }

  Future<void> _startClipping() async {
    await [Permission.storage, Permission.videos].request();

    setState(() {
      _isProcessing = true;
      _generatedFiles = [];
      _statusText = 'Initializing pipeline...';
    });

    try {
  final sourceInput = _pickedLocalFile ?? _urlController.text;
  
  final outputs = await ClipperEngine.generateClips(
    sourceInput: sourceInput,
    onProgress: (msg) => setState(() => _statusText = msg),
  );

  setState(() {
    _generatedFiles = outputs;
    _statusText = 'Done! Saved ${outputs.length} clips.';
  });
} catch (e) {
  setState(() {
    _statusText = 'Error: ${e.toString()}';
  });
} finally {
  setState(() => _isProcessing = false);
}

      

  @override
  Widget build(BuildContext context) {
    const cyberViolet = Color(0xFF8B5CF6);
    const cardDark = Color(0xFF141414);
    const borderDark = Color(0xFF262626);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.content_cut_rounded, color: cyberViolet, size: 22),
            SizedBox(width: 10),
            Text(
              'CLIPPER PRO',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Ingestion Mode Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ZERO-DOWNLOAD STREAM MODE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA78BFA),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Switch(
                        value: _zeroDownloadMode,
                        activeColor: cyberViolet,
                        onChanged: (val) => setState(() => _zeroDownloadMode = val),
                      ),
                    ],
                  ),
                  Text(
                    _zeroDownloadMode
                        ? 'Slices remote streams on-the-fly without saving master video.'
                        : 'Caches full HD master file locally on your 500GB storage.',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Paste YouTube / video link...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0A0A0A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: borderDark),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, color: cyberViolet),
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickLocalVideo,
                    icon: const Icon(Icons.video_file_outlined, size: 18),
                    label: Text(
                      _pickedFileName ?? 'Or Pick Local 4K / MP4 / MOV File',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: borderDark),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Clip Count & Duration Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NUMBER OF CLIPS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      Text(
                        '${_clipCount.round()} Clips',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cyberViolet,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _clipCount,
                    min: 1,
                    max: 12,
                    divisions: 11,
                    onChanged: (v) => setState(() => _clipCount = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'CLIP DURATION (SECONDS)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _durations.map((sec) {
                      final active = _selectedDuration == sec;
                      return ChoiceChip(
                        label: Text('${sec}s'),
                        selected: active,
                        selectedColor: cyberViolet,
                        backgroundColor: const Color(0xFF0A0A0A),
                        onSelected: (_) => setState(() => _selectedDuration = sec),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Captions, Framing & Filters Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Burn Auto-Captions', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('High-contrast Shorts subtitles', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: _burnCaptions,
                    activeColor: cyberViolet,
                    onChanged: (v) => setState(() => _burnCaptions = v),
                  ),
                  const Divider(color: borderDark),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Framing Layout', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: _selectedFraming,
                        dropdownColor: cardDark,
                        underline: const SizedBox(),
                        items: _framings
                            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedFraming = v!),
                      ),
                    ],
                  ),
                  const Divider(color: borderDark),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Color Filter', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: _selectedFilter,
                        dropdownColor: cardDark,
                        underline: const SizedBox(),
                        items: _filters
                            .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedFilter = v!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Generate Button
            ElevatedButton(
              onPressed: _isProcessing ? null : _startClipping,
              style: ElevatedButton.styleFrom(
                backgroundColor: cyberViolet,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'GENERATE CLIPS',
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 15),
                    ),
            ),
            const SizedBox(height: 14),

            // 5. Status & Output Paths
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusText,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  if (_generatedFiles.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._generatedFiles.map(
                      (path) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '✓ ${path.split('/').last}',
                          style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

