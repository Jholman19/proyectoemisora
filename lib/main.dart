import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animated_background/animated_background.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:emisora_flutter/models/station_data.dart';
import 'package:emisora_flutter/pages/detail_page.dart';
import 'package:emisora_flutter/painters/water_ripple_painter.dart';

enum AdSlotType { left, right }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.zonamusic.radio.channel.audio',
    androidNotificationChannelName: 'Zona Music Radio Playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zona Music Radio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purpleAccent, brightness: Brightness.dark),
      ),
      home: const RadioPage(),
    );
  }
}

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});
  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AudioPlayer _player;
  bool isPlaying = false;
  bool _audioInitialized = false; 
  bool _isConnecting = false;

  late AnimationController _rotationController;
  late AnimationController _rippleController;

  int _retryCount = 0;
  static const int _maxRetries = 5;
  Timer? _reconnectTimer;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 15));
    _rippleController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    
    _initializeAudio();
    _setupConnectivityListener();
  }

  void _initializeAudio() async {
    try {
      _player = AudioPlayer();
      
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(StationData.streamUrl),
          tag: MediaItem(
            id: 'zonamusic-1',
            album: StationData.slogan,
            title: StationData.name,
            artist: "En Vivo",
            artUri: Uri.parse("https://tu-servidor.com/logo.png"), 
          ),
        ),
        preload: false,
      );

      _setupAudioListeners();
      if (mounted) setState(() => _audioInitialized = true);
    } catch (e) {
      _handleReconnection();
    }
  }

  void _setupAudioListeners() {
    _playerStateSub?.cancel();
    
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state.playing;
          _isConnecting = state.processingState == ProcessingState.buffering || 
                         state.processingState == ProcessingState.loading;
          
          if (isPlaying) {
            _rotationController.repeat();
            _rippleController.repeat();
            _retryCount = 0;
            _reconnectTimer?.cancel();
          } else {
            _rotationController.stop();
            _rippleController.stop();
          }

          if (state.processingState == ProcessingState.completed) {
            _handleReconnection();
          }
        });
      }
    }, onError: (Object e) {
      _handleReconnection();
    });
  }

  void _handleReconnection() {
    if (_retryCount < _maxRetries) {
      _retryCount++;
      _reconnectTimer?.cancel();
      
      int delay = _retryCount * 5; 
      
      _reconnectTimer = Timer(Duration(seconds: delay), () {
        if (mounted && !isPlaying) {
          _player.stop();
           _initializeAudio();
           _player.play();
        }
      });
      _showErrorMessage("Se perdió la señal. Reintentando en $delay s...");
    } else {
      _showErrorMessage("Conexión fallida. Reintenta manualmente.");
      setState(() => _isConnecting = false);
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final hasConnection = result != ConnectivityResult.none;
      if (!hasConnection && isPlaying) {
        _player.pause();
        _showErrorMessage("Sin conexión a internet");
      }
    });
  }

  void _togglePlayback() async {
    if (!_audioInitialized) return;
    try {
      if (isPlaying) {
        await _player.stop();
      } else {
        setState(() => _isConnecting = true);
        await _player.play();
      }
    } catch (e) {
      _handleReconnection();
    }
  }

  void _showErrorMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.purple, duration: const Duration(seconds: 3))
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showErrorMessage("No se pudo abrir el enlace");
    }
  }

  void _showAdSpaceDialog(AdSlotType slotType) {
    final String slotLabel = slotType == AdSlotType.left ? 'Izquierdo' : 'Derecho';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161616),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: const Text(
            'Espacio publicitario',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'lib/assets/logo.png',
                  height: 58,
                  width: 58,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.campaign, size: 40, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Logo DGO',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Text(
                'Este espacio $slotLabel esta disponible para pautar.\nIncluye imagen o mini video en futuras versiones.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.2, height: 1.35, color: Colors.white),
              ),
              const SizedBox(height: 14),
              const Text(
                'Contacto WhatsApp: +57 322 200 2331',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchURL(StationData.whatsapp);
              },
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('WhatsApp'),
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isPlaying) {
      if (!_player.playing) _player.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _playerStateSub?.cancel();
    _connectivitySubscription?.cancel();
    _player.dispose();
    _rotationController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBackground(
            vsync: this,
            behaviour: RandomParticleBehaviour(
              options: const ParticleOptions(baseColor: Colors.purpleAccent, particleCount: 30, spawnMaxRadius: 2)
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.purple.withOpacity(0.15), Colors.black, Colors.black]
                )
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _buildHeader()),
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),
                          SliverToBoxAdapter(child: _buildVinylSection()),
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
                          SliverToBoxAdapter(child: _buildNewsSection()),
                        ],
                      ),
                    ),
                    _buildMainSocialFooter(),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'lib/assets/logo.png', width: 50, height: 50, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(Icons.radio, color: Colors.purpleAccent),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(StationData.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(StationData.slogan, style: const TextStyle(fontSize: 10, color: Colors.purpleAccent, letterSpacing: 1.5)),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => _launchURL(StationData.whatsapp),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.greenAccent, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildVinylSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: _buildAdPlaceholder(AdSlotType.left),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                if (isPlaying)
                  AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) => CustomPaint(
                      size: const Size(320, 320), 
                      painter: WaterRipplePainter(progress: _rippleController.value)
                    ),
                  ),
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 210, height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      border: Border.all(color: Colors.white10, width: 8), 
                      image: const DecorationImage(
                        image: AssetImage('lib/assets/radio_cover.jpg'), 
                        fit: BoxFit.cover
                      ),
                      boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)]
                    ),
                  ),
                ),
                if (_isConnecting)
                  const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.purpleAccent)),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: _buildAdPlaceholder(AdSlotType.right),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: (_isConnecting || !_audioInitialized) ? null : _togglePlayback,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPlaying ? Colors.white.withOpacity(0.1) : Colors.purpleAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isConnecting ? Icons.hourglass_top : (isPlaying ? Icons.pause : Icons.play_arrow),
              size: 50, color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdPlaceholder(AdSlotType slotType) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAdSpaceDialog(slotType),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 120,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Center(
                    child: Icon(Icons.perm_media, size: 18, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Espacio publicitario\ndisponible',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 9.8,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 25), 
          child: Text("PROGRAMACION MUSICAL, CROSSOVER Y MAS...", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2))
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: StationData.news.length,
            itemBuilder: (context, index) {
              final item = StationData.news[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPage(data: item))),
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25), 
                    image: DecorationImage(
                      image: item['isLocal'] ? AssetImage(item['img']) : NetworkImage(item['img']) as ImageProvider, 
                      fit: BoxFit.cover
                    )
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25), 
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Colors.black.withOpacity(0.8), Colors.transparent])
                    ),
                    padding: const EdgeInsets.all(15),
                    alignment: Alignment.bottomLeft,
                    child: Text(item['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMainSocialFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _socialBtn(FontAwesomeIcons.whatsapp, StationData.whatsapp, Colors.greenAccent),
          _socialBtn(FontAwesomeIcons.tiktok, StationData.tiktokLocutor, Colors.white), 
          _socialBtn(FontAwesomeIcons.facebook, StationData.facebook, Colors.blueAccent),
          _socialBtn(FontAwesomeIcons.instagram, StationData.instagram, Colors.pinkAccent),
          _socialBtn(FontAwesomeIcons.youtube, StationData.tiktokEmisora, Colors.redAccent), 
        ],
      ),
    );
  }

  Widget _socialBtn(IconData icon, String url, Color color) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: FaIcon(icon, color: color, size: 22),
      ),
    );
  }
}