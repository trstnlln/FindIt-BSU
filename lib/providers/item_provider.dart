import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';

import '../models/item_model.dart';
import '../services/item_service.dart';

/// Manages state for creating and listing item reports.
///
/// Used by the Report Item screen to submit lost/found reports
/// and later by feed screens to display them.
class ItemProvider extends ChangeNotifier {
  final ItemService _itemService = ItemService();

  bool _isLoading = false;
  bool _disposed = false;
  double? _uploadProgress;
  double? get uploadProgress => _uploadProgress;
  ItemModel? _lastCreatedItem;

  /// True while a create/fetch operation is in progress.
  bool get isLoading => _isLoading;

  /// The most recently created item (useful for confirmation UX).
  ItemModel? get lastCreatedItem => _lastCreatedItem;

  void _setLoading(bool value) {
    _isLoading = value;
    if (!_disposed) notifyListeners();
  }

  /// Exposes the item service instance.
  ItemService get itemService => _itemService;

  /// Provides real-time stream of items filtered by type ('lost' or 'found').
  Stream<List<ItemModel>> getItemsStream({String? type}) {
    return _itemService.getItemsStream(type: type);
  }

  // ─── Create ───────────────────────────────────────────────────────────────

  /// Submits a new item report. If [imageFile] is provided, it is uploaded
  /// to Cloudinary and attached to the report. If [secureDetails] is
  /// provided (found money / wallets), private verification details are
  /// saved separately so only the finder can read them.
  /// Returns an error message on failure, or null on success.
  Future<String?> reportItem({
    required String ownerId,
    required String type,
    required String title,
    required String description,
    required String category,
    required String location,
    String? specificLocation,
    String? custodyLocation,
    String? verificationQuestion,
    required DateTime date,
    XFile? imageFile,
    Map<String, dynamic>? secureDetails,
  }) async {
    if (_isLoading) return 'Your report is already being submitted.';
    _lastCreatedItem = null;
    _uploadProgress = null;
    _setLoading(true);
    try {
      String? photoUrl;
      if (imageFile != null) {
        photoUrl = await _itemService.uploadItemPhoto(
          imageFile,
          onProgress: (value) {
            _uploadProgress = value;
            if (!_disposed) notifyListeners();
          },
        );
      }

      _uploadProgress = null;
      if (!_disposed) notifyListeners();
      _lastCreatedItem = await _itemService.createItem(
        ownerId: ownerId,
        type: type,
        title: title,
        description: description,
        category: category,
        location: location,
        specificLocation: specificLocation,
        custodyLocation: custodyLocation,
        verificationQuestion: verificationQuestion,
        date: date,
        photoUrl: photoUrl,
        secureDetails: secureDetails,
      );

      return null; // null = success
    } on FormatException catch (error) {
      return error.message;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return 'Could not save this report. Verify your university email and sign in again.';
      }
      return 'Could not save your report. Check your connection and try again; your draft is kept.';
    } catch (_) {
      return 'Could not submit your report. Check your connection and try again; your draft is kept.';
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
