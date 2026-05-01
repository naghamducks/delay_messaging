import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/message.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// REAL LAYER SCHEMA (confirmed by reading the actual lebanon.pmtiles file):
//
//  roads      → kind:       highway | major_road | minor_road | path
//               kind_detail: motorway | motorway_link | primary | primary_link
//                            secondary | secondary_link | residential |
//                            service | footway | path | steps | pedestrian
//
//  buildings  → kind:       building | building_part
//               source-layer: "buildings"
//
//  landuse    → kind:       park | forest | grass | grassland | cemetery |
//                           hospital | school | university | residential |
//                           military | industrial | playground | pitch …
//
//  pois       → kind:       hospital | school | university | bank |
//                           place_of_worship | hotel | supermarket |
//                           parking | park | cinema | theatre | library …
//
//  places     → kind:       locality | neighbourhood
//               kind_detail: suburb | neighbourhood | hamlet | locality
//
//  water      → kind:       ocean | water | fountain | swimming_pool
// ─────────────────────────────────────────────────────────────────────────────

class SosMapScreen extends StatefulWidget {
  final Message sosMessage;
  const SosMapScreen({super.key, required this.sosMessage});

  @override
  State<SosMapScreen> createState() => _SosMapScreenState();
}

class _SosMapScreenState extends State<SosMapScreen> {
  MaplibreMapController? _mapController;
  String? _styleJson;

  @override
  void initState() {
    super.initState();
    _prepareMap();
  }

  Future<void> _prepareMap() async {
    final dir = await getApplicationDocumentsDirectory();

    // ── 1. PMTILES ─────────────────────────────────────────────────────────
    final tilesFile = File(p.join(dir.path, 'lebanon.pmtiles'));
    if (!await tilesFile.exists()) {
      final data = await rootBundle.load('assets/maps/lebanon.pmtiles');
      await tilesFile.writeAsBytes(data.buffer.asUint8List());
    }
    final tilesUri = 'pmtiles://file://${tilesFile.path}';

    // ── 2. FONTS ───────────────────────────────────────────────────────────
    final fontsDir = Directory(p.join(dir.path, 'fonts', 'Noto Sans Regular'));
    if (!await fontsDir.exists()) await fontsDir.create(recursive: true);

    const fontRanges = [
      '0-255', '256-511', '512-767',
      '768-1023', '1024-1279', '1280-1535',
    ];
    for (final range in fontRanges) {
      try {
        final data =
            await rootBundle.load('assets/fonts/Noto Sans Regular/$range.pbf');
        final fontFile = File(p.join(fontsDir.path, '$range.pbf'));
        await fontFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      } catch (e) {
        debugPrint('Missing font range $range: $e');
      }
    }
    final glyphsUri = 'asset://fonts/Noto Sans Regular/{range}.pbf';

    debugPrint('PMTiles URI : $tilesUri');
    debugPrint('Glyphs URI  : $glyphsUri');

    // ── 3. STYLE ───────────────────────────────────────────────────────────
    //
    // FILTER SYNTAX NOTE:
    //   This file uses the "kind" / "kind_detail" fields (NOT "pmap:kind").
    //   All filters use the MapLibre expression form:
    //     ["==", ["get", "field"], "value"]          — single value
    //     ["match", ["get", "field"], [...], true, false] — multi-value
    //
    // LAYER ORDER (back → front):
    //   background → earth → water → landuse fills → buildings →
    //   road casings → road fills → boundaries → road labels →
    //   POI labels → place labels
    //   (SOS marker is added programmatically on top of everything)
    //
    final style = {
      "version": 8,
      "name": "Lebanon Offline — Full",
      "glyphs": glyphsUri,
      "sources": {
        "protomaps": {
          "type": "vector",
          "url": tilesUri,
          "attribution": "© OpenStreetMap contributors",
        }
      },
      "layers": [

        // ── BACKGROUND ────────────────────────────────────────────────────
        {
          "id": "background",
          "type": "background",
          "paint": {"background-color": "#f0ebe3"},
        },

        // ── EARTH (base land polygon) ──────────────────────────────────────
        {
          "id": "earth",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "earth",
          "paint": {"fill-color": "#eae6df"},
        },

        // ── WATER ─────────────────────────────────────────────────────────
        {
          "id": "water_fill",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "water",
          "paint": {"fill-color": "#a8d4f5"},
        },
        {
          "id": "water_stroke",
          "type": "line",
          "source": "protomaps",
          "source-layer": "water",
          "paint": {"line-color": "#8ec8f0", "line-width": 0.5},
        },

        // ── LANDUSE ───────────────────────────────────────────────────────
        {
          "id": "landuse_green",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": [
            "match", ["get", "kind"],
            ["park", "forest", "grass", "grassland", "wood",
             "village_green", "garden", "pitch", "playground", "scrub"],
            true, false,
          ],
          "paint": {"fill-color": "#c9e0bb", "fill-opacity": 0.85},
        },
        {
          "id": "landuse_hospital",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": ["==", ["get", "kind"], "hospital"],
          "paint": {"fill-color": "#f7d8d8", "fill-opacity": 0.8},
        },
        {
          "id": "landuse_school",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": [
            "match", ["get", "kind"],
            ["school", "university", "college"],
            true, false,
          ],
          "paint": {"fill-color": "#f2e8c4", "fill-opacity": 0.7},
        },
        {
          "id": "landuse_industrial",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": [
            "match", ["get", "kind"],
            ["industrial", "military"],
            true, false,
          ],
          "paint": {"fill-color": "#ddd8d0", "fill-opacity": 0.6},
        },
        {
          "id": "landuse_cemetery",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": ["==", ["get", "kind"], "cemetery"],
          "paint": {"fill-color": "#d8e8d0", "fill-opacity": 0.75},
        },
        {
          "id": "landuse_pedestrian",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": [
            "match", ["get", "kind"],
            ["pedestrian", "residential"],
            true, false,
          ],
          "paint": {"fill-color": "#f0ece5", "fill-opacity": 0.5},
        },

        // ── BUILDINGS ─────────────────────────────────────────────────────
        // source-layer is "buildings" (confirmed from tile inspection)
        {
          "id": "buildings_fill",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "buildings",
          "minzoom": 13,
          "paint": {
            "fill-color": [
              "match", ["get", "kind"],
              "building_part", "#d5c8be",
              "#ddd5cc",
            ],
            "fill-outline-color": "#c4b8b0",
            "fill-opacity": 0.95,
          },
        },

        // ── ROAD CASINGS (outlines drawn first for contrast) ───────────────
        {
          "id": "road_casing_path",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "path"],
          "minzoom": 14,
          "paint": {
            "line-color": "#d0c8c0",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              14, 1.5, 18, 3],
            "line-cap": "round",
            "line-join": "round",
          },
        },
        {
          "id": "road_casing_minor",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "minor_road"],
          "minzoom": 12,
          "paint": {
            "line-color": "#c0b8b0",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              12, 1.5, 14, 2.5, 18, 7],
            "line-cap": "round",
            "line-join": "round",
          },
        },
        {
          "id": "road_casing_major",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "major_road"],
          "minzoom": 9,
          "paint": {
            "line-color": "#b8a070",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              9, 1.5, 12, 3, 18, 11],
            "line-cap": "round",
            "line-join": "round",
          },
        },
        {
          "id": "road_casing_highway",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "highway"],
          "minzoom": 6,
          "paint": {
            "line-color": "#b07020",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              6, 2, 10, 4, 18, 14],
            "line-cap": "round",
            "line-join": "round",
          },
        },

        // ── ROAD FILLS ────────────────────────────────────────────────────
        {
          "id": "road_fill_path",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "path"],
          "minzoom": 14,
          "paint": {
            "line-color": "#ece8e0",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              14, 0.8, 18, 2],
            "line-dasharray": [2, 2],
            "line-cap": "round",
          },
        },
        {
          "id": "road_fill_minor",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "minor_road"],
          "minzoom": 12,
          "paint": {
            "line-color": "#ffffff",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              12, 0.8, 14, 1.5, 18, 5],
            "line-cap": "round",
            "line-join": "round",
          },
        },
        {
          "id": "road_fill_major",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "major_road"],
          "minzoom": 9,
          "paint": {
            "line-color": "#f5edcc",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              9, 0.8, 12, 2, 18, 8],
            "line-cap": "round",
            "line-join": "round",
          },
        },
        {
          "id": "road_fill_highway",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", ["get", "kind"], "highway"],
          "minzoom": 6,
          "paint": {
            "line-color": "#fad05a",
            "line-width": ["interpolate", ["linear"], ["zoom"],
              6, 1, 10, 2.5, 18, 10],
            "line-cap": "round",
            "line-join": "round",
          },
        },

        // ── BOUNDARIES ────────────────────────────────────────────────────
        {
          "id": "boundaries",
          "type": "line",
          "source": "protomaps",
          "source-layer": "boundaries",
          "paint": {
            "line-color": "#c0a0c0",
            "line-width": 1,
            "line-dasharray": [4, 3],
          },
        },

        // ── ROAD LABELS ───────────────────────────────────────────────────
        {
          "id": "road_label_minor",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 16,
          "filter": ["==", ["get", "kind"], "minor_road"],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": 10,
            "symbol-placement": "line",
            "text-max-angle": 30,
            "text-padding": 8,
          },
          "paint": {
            "text-color": "#555555",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.2,
          },
        },
        {
          "id": "road_label_major",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 13,
          "filter": [
            "match", ["get", "kind"],
            ["major_road", "highway"],
            true, false,
          ],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": ["interpolate", ["linear"], ["zoom"],
              13, 11, 18, 15],
            "symbol-placement": "line",
            "text-max-angle": 30,
            "text-padding": 10,
          },
          "paint": {
            "text-color": "#333333",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.8,
          },
        },

        // ── POI LABELS (hospitals, schools, shops …) ──────────────────────
        // Hospital — highest priority, shown from zoom 13
        {
          "id": "poi_hospital",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "minzoom": 13,
          "filter": ["==", ["get", "kind"], "hospital"],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": 11,
            "text-anchor": "top",
            "text-offset": [0, 0.4],
            "text-max-width": 8,
            "icon-allow-overlap": false,
            "text-allow-overlap": false,
          },
          "paint": {
            "text-color": "#cc2233",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.5,
          },
        },
        // Schools & universities
        {
          "id": "poi_school",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "minzoom": 14,
          "filter": [
            "match", ["get", "kind"],
            ["school", "university", "college", "library"],
            true, false,
          ],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": 10,
            "text-anchor": "top",
            "text-offset": [0, 0.3],
            "text-max-width": 8,
          },
          "paint": {
            "text-color": "#8855aa",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.3,
          },
        },
        // Place of worship
        {
          "id": "poi_worship",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "minzoom": 14,
          "filter": ["==", ["get", "kind"], "place_of_worship"],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": 10,
            "text-anchor": "top",
            "text-offset": [0, 0.3],
            "text-max-width": 8,
          },
          "paint": {
            "text-color": "#996633",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.2,
          },
        },
        // Hotels
        {
          "id": "poi_hotel",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "minzoom": 14,
          "filter": [
            "match", ["get", "kind"],
            ["hotel", "resort"],
            true, false,
          ],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": 10,
            "text-anchor": "top",
            "text-offset": [0, 0.3],
            "text-max-width": 8,
          },
          "paint": {
            "text-color": "#2266aa",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.2,
          },
        },
        // General POIs (bank, supermarket, parking, cinema …)
        {
          "id": "poi_general",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "minzoom": 15,
          "filter": [
            "match", ["get", "kind"],
            ["bank", "supermarket", "parking", "cinema",
             "theatre", "post_office", "attraction", "monument"],
            true, false,
          ],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": 10,
            "text-anchor": "top",
            "text-offset": [0, 0.3],
            "text-max-width": 7,
          },
          "paint": {
            "text-color": "#444444",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.2,
          },
        },

        // ── PLACE LABELS (suburbs, neighbourhoods, towns, cities) ─────────
        {
          "id": "place_neighbourhood",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "places",
          "minzoom": 13,
          "filter": [
            "match", ["get", "kind_detail"],
            ["neighbourhood", "suburb"],
            true, false,
          ],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": 11,
            "text-transform": "uppercase",
            "text-letter-spacing": 0.08,
            "text-max-width": 9,
          },
          "paint": {
            "text-color": "#777777",
            "text-halo-color": "#f0ebe3",
            "text-halo-width": 1.2,
          },
        },
        {
          "id": "place_locality",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "places",
          "minzoom": 10,
          "filter": [
            "match", ["get", "kind_detail"],
            ["hamlet", "locality"],
            true, false,
          ],
          "layout": {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["Noto Sans Regular"],
            "text-size": ["interpolate", ["linear"], ["zoom"],
              10, 11, 14, 14],
            "text-max-width": 9,
          },
          "paint": {
            "text-color": "#444444",
            "text-halo-color": "#ffffff",
            "text-halo-width": 1.5,
          },
        },
      ],
    };

    if (mounted) {
      setState(() => _styleJson = jsonEncode(style));
    }
  }

  @override
  void dispose() => super.dispose();

  @override
  Widget build(BuildContext context) {
    final lat = widget.sosMessage.latitude!;
    final lng = widget.sosMessage.longitude!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Location'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Expires in ${_timeRemaining(widget.sosMessage.timestamp)}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _styleJson == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading offline map…'),
                ],
              ),
            )
          : Stack(
              children: [
                MaplibreMap(
                  styleString: _styleJson!,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(lat, lng),
                    zoom: 14,
                    bearing: 0,
                    tilt: 0,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  onStyleLoadedCallback: () => _addSosMarker(lat, lng),
                  myLocationEnabled: false,
                  trackCameraPosition: false,
                  compassEnabled: true,
                ),

                // ── Bottom info card ──────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _InfoCard(message: widget.sosMessage),
                ),

                // ── Zoom controls ─────────────────────────────────────────
                Positioned(
                  right: 16,
                  bottom: 195,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: () => _mapController
                            ?.animateCamera(CameraUpdate.zoomIn()),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: () => _mapController
                            ?.animateCamera(CameraUpdate.zoomOut()),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'center',
                        onPressed: () => _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Adds the SOS marker: pulsing halo + solid inner dot + Flutter warning widget.
  ///
  /// MapLibre GL doesn't support animated circle layers natively, so we draw
  /// three static circle layers (outer halo → mid ring → inner dot) for the
  /// "pulsing" look, and overlay a Flutter [_SosMarkerOverlay] widget on top
  /// using a [Stack] positioned to the screen coords of the marker.
  Future<void> _addSosMarker(double lat, double lng) async {
    final c = _mapController;
    if (c == null) return;

    await c.addSource(
      'sos-source',
      GeojsonSourceProperties(data: {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [lng, lat],
            },
            'properties': {},
          }
        ],
      }),
    );

    // Outer halo
    await c.addCircleLayer(
      'sos-source',
      'sos-halo-outer',
      CircleLayerProperties(
        circleRadius: 32,
        circleColor: '#ff0000',
        circleOpacity: 0.15,
      ),
    );

    // Mid ring
    await c.addCircleLayer(
      'sos-source',
      'sos-halo-mid',
      CircleLayerProperties(
        circleRadius: 20,
        circleColor: '#ff0000',
        circleOpacity: 0.30,
      ),
    );

    // Inner solid dot with white border
    await c.addCircleLayer(
      'sos-source',
      'sos-dot',
      CircleLayerProperties(
        circleRadius: 11,
        circleColor: '#cc0000',
        circleStrokeWidth: 3,
        circleStrokeColor: '#ffffff',
      ),
    );

    // Overlay the _SosMarker widget
    setState(() {
      Stack(
        children: [
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 22, // Adjust for marker size
            top: MediaQuery.of(context).size.height / 2 - 44, // Adjust for marker size
            child: _SosMarker(message: widget.sosMessage),
          ),
        ],
      );
    });
  }

  String _timeRemaining(DateTime timestamp) {
    final expiry = timestamp.add(const Duration(hours: 24));
    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

// ─── Bottom info card ─────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Message message;
  const _InfoCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final expiry = message.timestamp.add(const Duration(hours: 24));
    final remaining = expiry.difference(DateTime.now());
    final isExpiring = remaining.inHours < 2;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              if (isExpiring) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Expiring soon',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Message
          Text(message.content,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),

          // Coordinates
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${message.latitude!.toStringAsFixed(6)}, '
                '${message.longitude!.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Timestamp + expiry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatTimestamp(message.timestamp),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600)),
              ]),
              Row(children: [
                Icon(Icons.timer_outlined,
                    size: 14,
                    color: isExpiring ? Colors.orange : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Expires ${_formatExpiry(expiry)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isExpiring
                            ? Colors.orange.shade700
                            : Colors.grey.shade600,
                        fontWeight: isExpiring
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  String _formatExpiry(DateTime expiry) {
    final d = expiry.difference(DateTime.now());
    if (d.isNegative) return 'now';
    if (d.inMinutes < 60) return 'in ${d.inMinutes}m';
    return 'in ${d.inHours}h ${d.inMinutes % 60}m';
  }
}
class _SosMarker extends StatefulWidget {
  final Message message;
  const _SosMarker({required this.message});

  @override
  State<_SosMarker> createState() => _SosMarkerState();
}

class _SosMarkerState extends State<_SosMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              // Pin tail
              CustomPaint(
                size: const Size(12, 8),
                painter: _PinTailPainter(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.red;
    final path  = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

