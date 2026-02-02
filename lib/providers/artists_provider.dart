import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/artist_model.dart';
import 'repositories_providers.dart';

/// Provider for all artists stream
final artistsStreamProvider = StreamProvider<List<ArtistModel>>((ref) {
  final artistRepository = ref.watch(artistRepositoryProvider);
  return artistRepository.streamAllArtists();
});

/// Provider for all artists as a list (for non-stream usage)
final artistsProvider = FutureProvider<List<ArtistModel>>((ref) {
  final artistRepository = ref.watch(artistRepositoryProvider);
  return artistRepository.getAllArtists();
});

/// Provider for a specific artist by ID
final artistByIdProvider = FutureProvider.family<ArtistModel?, String>((ref, artistId) {
  final artistRepository = ref.watch(artistRepositoryProvider);
  return artistRepository.getArtistById(artistId);
});

/// Provider for multiple artists by IDs
final artistsByIdsProvider = FutureProvider.family<List<ArtistModel>, List<String>>((ref, artistIds) {
  final artistRepository = ref.watch(artistRepositoryProvider);
  return artistRepository.getArtistsByIds(artistIds);
});

/// State provider for selected artist IDs (for filtering)
final selectedArtistIdsProvider = StateProvider<List<String>>((ref) => []);

