import 'package:cambus_connect_app/data/models/bus_model.dart';
import 'package:cambus_connect_app/features/student/student_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

class LiveBusTrackingScreen extends ConsumerStatefulWidget {
  const LiveBusTrackingScreen({super.key});

  @override
  ConsumerState<LiveBusTrackingScreen> createState() =>
      _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends ConsumerState<LiveBusTrackingScreen> {
  GoogleMapController? _mapController;
  String? _selectedBusId;

  // Statically cached marker descriptors (avoids re-allocating BitmapDescriptor on every frame)
  static final BitmapDescriptor _greenMarker =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  static final BitmapDescriptor _orangeMarker =
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Text('Live Tracking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF1E293B), size: 20),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: ref.watch(allBusesStreamProvider).when(
        loading: () => Center(
            child: CircularProgressIndicator(color: colorScheme.primary)),
        error: (err, stack) => Center(
            child: Text('Error loading live fleet: $err',
                style: TextStyle(color: colorScheme.error))),
        data: (buses) {
          // Default campus position
          LatLng center = const LatLng(22.7196, 75.8577); // Default Indore

          // Build markers from all buses
          final markers = <Marker>{};
          BusModel? selectedBus;

          for (final bus in buses) {
            if (bus.latitude != 0.0 && bus.longitude != 0.0) {
              final isSelected = _selectedBusId == bus.busId;
              markers.add(Marker(
                markerId: MarkerId(bus.busId),
                position: LatLng(bus.latitude, bus.longitude),
                icon: bus.status == 'On Route' ? _greenMarker : _orangeMarker,
                infoWindow: InfoWindow(
                  title: '${bus.busNumber} - ${bus.routeName}',
                  snippet: bus.status,
                ),
                onTap: () {
                  setState(() => _selectedBusId = bus.busId);
                  _mapController?.animateCamera(CameraUpdate.newLatLng(
                      LatLng(bus.latitude, bus.longitude)));
                },
              ));

              if (isSelected) {
                selectedBus = bus;
                center = LatLng(bus.latitude, bus.longitude);
              }
            }
          }

          // If no bus selected, pick the first active one
          if (selectedBus == null && buses.isNotEmpty) {
            final activeBus = buses.firstWhere(
              (b) => b.latitude != 0.0 && b.longitude != 0.0,
              orElse: () => buses.first,
            );
            if (activeBus.latitude != 0.0 && activeBus.longitude != 0.0) {
              center = LatLng(activeBus.latitude, activeBus.longitude);
              selectedBus = activeBus;
            }
          }

          return Column(
            children: [
              Expanded(
                flex: 5,
                child: GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: center, zoom: 14.0),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) =>
                      _mapController = controller,
                ),
              ),

              // Bottom Panel
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    if (buses.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No buses available.',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      )
                    else ...[
                      // Bus selector chips
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: buses.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final bus = buses[index];
                            final isSelected = _selectedBusId == bus.busId ||
                                (selectedBus?.busId == bus.busId &&
                                    _selectedBusId == null);
                            final isActive = bus.status == 'On Route';

                            return GestureDetector(
                              onTap: () {
                                setState(
                                    () => _selectedBusId = bus.busId);
                                if (bus.latitude != 0.0 &&
                                    bus.longitude != 0.0) {
                                  _mapController?.animateCamera(
                                      CameraUpdate.newLatLng(LatLng(
                                          bus.latitude,
                                          bus.longitude)));
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: isActive && !isSelected
                                      ? Border.all(
                                          color: const Color(0xFF10B981)
                                              .withValues(alpha: 0.5))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    if (isActive)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin:
                                            const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF10B981),
                                        ),
                                      ),
                                    Text(
                                      bus.busNumber,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected bus info
                      if (selectedBus != null) ...[
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedBus.routeName,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${selectedBus.registrationNumber} ${selectedBus.driverName != null ? "• ${selectedBus.driverName}" : ""}',
                                    style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: selectedBus.status == 'On Route'
                                    ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.1)
                                    : const Color(0xFF64748B)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                selectedBus.status.toUpperCase(),
                                style: TextStyle(
                                  color:
                                      selectedBus.status == 'On Route'
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Metrics
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _Metric(
                                  icon: Icons.speed_rounded,
                                  value:
                                      '${selectedBus.speed.toStringAsFixed(0)} km/h',
                                  label: 'Speed'),
                              Container(
                                  width: 1,
                                  height: 36,
                                  color: const Color(0xFFE2E8F0)),
                              _Metric(
                                  icon: Icons.people_alt_rounded,
                                  value: '${selectedBus.capacity}',
                                  label: 'Capacity'),
                              Container(
                                  width: 1,
                                  height: 36,
                                  color: const Color(0xFFE2E8F0)),
                              _Metric(
                                  icon: Icons.update_rounded,
                                  value: selectedBus.lastUpdate.isNotEmpty ? selectedBus.lastUpdate : 'Just now',
                                  label: 'Updated'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Metric(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1E293B))),
        Text(label,
            style:
                const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
      ],
    );
  }
}
