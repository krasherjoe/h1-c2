import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/geolocator_stub.dart';
import '../../../models/customer_model.dart';
import 'customer_utils.dart';

List<Customer> applyFilter({
  required List<Customer> customers,
  required String query,
  required bool showHidden,
  required String sortKey,
  required bool ignoreCorpPrefix,
}) {
  List<Customer> list = customers.where((c) {
    return c.displayName.toLowerCase().contains(query) ||
        c.formalName.toLowerCase().contains(query);
  }).toList();
  if (!showHidden) {
    list = list.where((c) => !c.isHidden).toList();
  }
  return list;
}

Future<void> sortCustomers({
  required List<Customer> list,
  required String sortKey,
  required bool showHidden,
  required bool ignoreCorpPrefix,
}) async {
  switch (sortKey) {
    case 'name_desc':
      list.sort((a, b) => showHidden
          ? b.id.compareTo(a.id)
          : normalizedName(b.displayName, ignoreCorpPrefix)
              .compareTo(normalizedName(a.displayName, ignoreCorpPrefix)));
      break;
    case 'nearby':
      final ownPos = await _getCurrentPosition();
      if (ownPos != null) {
        list.sort((a, b) {
          if (a.lat == null || a.lng == null) return 1;
          if (b.lat == null || b.lng == null) return -1;
          final da = _distance(ownPos.latitude, ownPos.longitude, a.lat!, a.lng!);
          final db = _distance(ownPos.latitude, ownPos.longitude, b.lat!, b.lng!);
          return da.compareTo(db);
        });
      }
      break;
    default:
      list.sort((a, b) => showHidden
          ? b.id.compareTo(a.id)
          : normalizedName(a.displayName, ignoreCorpPrefix)
              .compareTo(normalizedName(b.displayName, ignoreCorpPrefix)));
  }
}

  Future<({double latitude, double longitude})?> _getCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      return (latitude: pos['latitude']!, longitude: pos['longitude']!);
    } catch (e) {
      debugPrint('[CustomerMaster] getCurrentPosition error: $e');
      return null;
    }
  }

double _distance(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * asin(sqrt(a));
}

double _rad(double deg) => deg * 3.141592653589793 / 180;
