import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emisora_flutter/models/station_data.dart';

class DetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  const DetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    bool isEstudio = data['id'] == 'estudio';
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(expandedHeight: 300, pinned: true, flexibleSpace: FlexibleSpaceBar(background: data['isLocal'] ? Image.asset(data['img'], fit: BoxFit.cover) : Image.network(data['img'], fit: BoxFit.cover))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  if (isEstudio) Image.asset('lib/assets/logo.png', width: 80),
                  const SizedBox(height: 10),
                  Text(data['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(data['description'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.6)),
                  const SizedBox(height: 30),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: _buildFilteredSocials(data['type'])),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildFilteredSocials(String type) {
    if (type == 'business') {
      return [_socialCircle(FontAwesomeIcons.tiktok, StationData.tiktokEmisora)];
    } else {
      return [
        _socialCircle(FontAwesomeIcons.whatsapp, StationData.whatsapp),
        _socialCircle(FontAwesomeIcons.tiktok, StationData.tiktokLocutor),
        _socialCircle(FontAwesomeIcons.facebook, StationData.facebook),
        _socialCircle(FontAwesomeIcons.instagram, StationData.instagram),
      ];
    }
  }

  Widget _socialCircle(IconData icon, String url) {
    return IconButton(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: FaIcon(icon, size: 20),
      style: IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(13)),
    );
  }
}
