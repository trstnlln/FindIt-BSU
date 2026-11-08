import 'dart:typed_data';
import 'dart:async';

import '../../services/report_draft_store.dart';
import '../../services/photo_upload.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../utils/helpers.dart';

/// Screen where users fill out a form to report a lost or found item.
///
/// Fields: type (lost/found), title, description, category dropdown,
/// campus landmark, room/floor details, custody location (for found items),
/// verification question (for found items), date picker, and photo upload.
class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specificLocationController = TextEditingController();
  final _verificationQuestionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final _amountController = TextEditingController();
  final _conditionController = TextEditingController();
  final _q1Controller = TextEditingController();
  final _a1Controller = TextEditingController();
  final _q2Controller = TextEditingController();
  final _a2Controller = TextEditingController();

  /// Extra protection applies to found money and wallets/bags.
  bool get _needsSecurity =>
      _type == 'found' &&
      (_category == 'Money' || _category == 'Bags / Wallets');

  String _type = 'lost'; // 'lost' or 'found'
  String? _category; // selected category
  String? _campusLocation; // selected campus location
  String? _custodyLocation; // where surrendered (e.g. Guard Post)
  DateTime _date = DateTime.now(); // default to today
  XFile? _selectedImage; // picked image file
  Uint8List? _selectedImageBytes; // bytes for preview across all platforms
  String? _errorMessage;

  Timer? _draftTimer;
  final _drafts = ReportDraftStore();
  String? _draftOwner;
  bool _draftRestored = false;
  bool _submitted = false;
  String? _draftMessage;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftRestored) return;
    _draftRestored = true;
    // The form can also be embedded in isolated widget tests without auth.
    try {
      _draftOwner = context.read<AuthProvider>().currentUser?.id;
    } catch (_) {
      return;
    }
    for (final controller in [
      _titleController,
      _descriptionController,
      _specificLocationController,
    ]) {
      controller.addListener(_scheduleDraft);
    }
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final uid = _draftOwner;
    if (uid == null) return;
    try {
      final draft = await _drafts.load(uid);
      if (!mounted || draft == null || _titleController.text.isNotEmpty) return;
      setState(() {
        _type = draft['type'] == 'found' ? 'found' : 'lost';
        _titleController.text = draft['title'] as String? ?? '';
        _descriptionController.text = draft['description'] as String? ?? '';
        _specificLocationController.text =
            draft['specificLocation'] as String? ?? '';
        _category = itemCategories.contains(draft['category'])
            ? draft['category'] as String
            : null;
        _campusLocation = campusLocations.contains(draft['location'])
            ? draft['location'] as String
            : null;
        _custodyLocation = custodyLocations.contains(draft['custodyLocation'])
            ? draft['custodyLocation'] as String
            : null;
        final date = DateTime.tryParse(draft['date'] as String? ?? '');
        if (date != null && !date.isAfter(DateTime.now())) _date = date;
        _draftMessage = 'Your unfinished report was restored. Reattach photos and private verification details.';
      });
    } catch (_) {
      /* Draft storage is optional; submission remains available. */
    }
  }

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_draftOwner == null || _submitted) return;
    try {
      await _drafts.save(_draftOwner!, {
        'type': _type,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _category,
        'location': _campusLocation,
        'specificLocation': _specificLocationController.text,
        'custodyLocation': _custodyLocation,
        'date': _date.toIso8601String(),
      });
    } catch (_) {
      /* Keep the in-memory form on storage failure. */
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _saveDraft();
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _conditionController.dispose();
    _q1Controller.dispose();
    _a1Controller.dispose();
    _q2Controller.dispose();
    _a2Controller.dispose();
    _specificLocationController.dispose();
    _verificationQuestionController.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: _type == 'lost'
          ? 'When did you lose it?'
          : 'When did you find it?',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  /// Picks an image from the specified [source] and compresses it
  /// using built-in quality and dimension constraints.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75, // Compress image before upload
      );

      if (pickedFile != null) {
        if (await pickedFile.length() > 5 * 1024 * 1024) {
          throw const FormatException('Choose a photo smaller than 5 MB.');
        }
        final bytes = await pickedFile.readAsBytes();
        validateReportPhoto(bytes);
        if (!mounted) return;
        setState(() {
          _selectedImage = pickedFile;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e is FormatException ? e.message : 'Could not open a photo. Check camera or photo permissions and try again.')));
      }
    }
  }

  /// Opens a bottom sheet to let the user choose camera or gallery.
  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Upload Item Photo',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Images are automatically compressed before upload',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Use camera to photograph item'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _submit() async {
    if (context.read<ItemProvider>().isLoading) return;
    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Clear previous error
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final itemProvider = context.read<ItemProvider>();

    final user = authProvider.currentUser;
    if (user == null) {
      setState(
        () => _errorMessage = 'User session expired. Please log in again.',
      );
      return;
    }

    if (!user.email.trim().toLowerCase().endsWith('@g.batstate-u.edu.ph')) {
      setState(
        () => _errorMessage = 'Domain Restricted: Only users with a valid @g.batstate-u.edu.ph email address can post item reports.',
      );
      return;
    }

    final error = await itemProvider.reportItem(
      ownerId: authProvider.currentUser!.id,
      type: _type,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category!,
      location: _campusLocation!,
      specificLocation: _specificLocationController.text.trim().isNotEmpty
          ? _specificLocationController.text.trim()
          : null,
      custodyLocation: _type == 'found' && _custodyLocation != null
          ? _custodyLocation
          : null,
      verificationQuestion:
          _type == 'found' &&
              _verificationQuestionController.text.trim().isNotEmpty
          ? _verificationQuestionController.text.trim()
          : null,
      date: _date,
      imageFile: _selectedImage,
      secureDetails: _needsSecurity
          ? {
              'exactAmount': _amountController.text.trim(),
              'foundCondition': _conditionController.text.trim(),
              'questions': [
                _q1Controller.text.trim(),
                _q2Controller.text.trim(),
              ],
              'answers': [_a1Controller.text.trim(), _a2Controller.text.trim()],
            }
          : null,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      _submitted = true;
      _draftTimer?.cancel();
      if (_draftOwner != null) {
        try {
          await _drafts.clear(_draftOwner!);
        } catch (_) {}
      }
      if (!mounted) return;
      // Show success and pop back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _type == 'lost'
                ? 'Lost item report submitted!'
                : 'Found item report submitted!',
          ),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reportState = context.watch<ItemProvider>();
    final isLoading = reportState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Report an Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: AbsorbPointer(
          absorbing: isLoading,
          child: Form(
            key: _formKey,
            onChanged: _scheduleDraft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Type Toggle (Lost / Found) ──────────────────────────
                Text(
                  'Let’s bring it back.',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'A few details can make someone’s day.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (_draftMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_draftMessage!),
                  ),
                _buildTypeToggle(colorScheme),
                const SizedBox(height: 20),

                // ── Title ───────────────────────────────────────────────
                _sectionHeading('01', 'About the item'),
                _buildTitleField(),
                const SizedBox(height: 16),

                // ── Description ─────────────────────────────────────────
                _buildDescriptionField(),
                const SizedBox(height: 16),

                // ── Category Dropdown ───────────────────────────────────
                _buildCategoryDropdown(),
                const SizedBox(height: 16),

                // ── Campus Location Dropdown ────────────────────────────
                _sectionHeading('02', 'Where and when'),
                _buildLocationDropdown(),
                const SizedBox(height: 16),

                // ── Specific Room / Floor Field ─────────────────────────
                _buildSpecificLocationField(),
                const SizedBox(height: 16),

                // ── Found Item Specials: Custody & Blind Verification Question
                if (_type == 'found') ...[
                  _buildCustodyDropdown(),
                  const SizedBox(height: 16),
                  _buildVerificationQuestionField(colorScheme),
                  const SizedBox(height: 16),
                ],

                // ── Date Picker ─────────────────────────────────────────
                _buildDatePicker(colorScheme),
                const SizedBox(height: 16),

                // ── Photo Upload Section ────────────────────────────────
                _sectionHeading('03', 'Help it stand out'),
                _buildPhotoUploadSection(colorScheme),
                const SizedBox(height: 16),
                if (_needsSecurity) _buildSecuritySection(colorScheme),

                // ── Error Banner ────────────────────────────────────────
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 12),
                ],

                // ── Submit Button ───────────────────────────────────────
                const SizedBox(height: 8),
                if (isLoading) ...[
                  LinearProgressIndicator(value: reportState.uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    reportState.uploadProgress == null
                        ? 'Saving your report…'
                        : 'Uploading photo: ${(reportState.uploadProgress! * 100).round()}%',
                  ),
                  const SizedBox(height: 12),
                ],
                _buildSubmitButton(isLoading),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String number, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16, top: 8),
    child: Row(
      children: [
        Text(
          number,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  // ─── Widget Helpers ─────────────────────────────────────────────────────

  /// Segmented button to toggle between "Lost" and "Found".
  Widget _buildTypeToggle(ColorScheme colorScheme) {
    return SegmentedButton<String>(
      direction:
          MediaQuery.sizeOf(context).width < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 18
          ? Axis.vertical
          : Axis.horizontal,
      segments: const [
        ButtonSegment(
          value: 'lost',
          label: Text('I lost an item'),
          icon: Icon(Icons.search_rounded),
        ),
        ButtonSegment(
          value: 'found',
          label: Text('I found an item'),
          icon: Icon(Icons.inventory_2_outlined),
        ),
      ],
      selected: {_type},
      onSelectionChanged: (selection) {
        setState(() {
          _type = selection.first;
          if (_type == 'lost') {
            _custodyLocation = null;
            _verificationQuestionController.clear();
          }
        });
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      maxLength: 120,
      controller: _titleController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Item title',
        hintText: 'e.g. Blue Umbrella, Black Wallet, TI-84 Calculator',
        prefixIcon: const Icon(Icons.title_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a title for the item.';
        }
        if (value.trim().length < 3) {
          return 'Title must be at least 3 characters.';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      maxLength: 2000,
      controller: _descriptionController,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Description',
        hintText:
            'Color, brand, distinguishing marks, sticker, case details...',
        alignLabelWithHint: true,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_outlined),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please describe the item.';
        }
        if (value.trim().length < 10) {
          return 'Description must be at least 10 characters.';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _category,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: itemCategories
          .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
          .toList(),
      onChanged: (value) => setState(() => _category = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a category.';
        }
        return null;
      },
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _campusLocation,
      decoration: InputDecoration(
        labelText: 'Campus location',
        prefixIcon: const Icon(Icons.location_on_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      isExpanded: true,
      items: campusLocations
          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
          .toList(),
      onChanged: (value) => setState(() => _campusLocation = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a campus location.';
        }
        return null;
      },
    );
  }

  Widget _buildSpecificLocationField() {
    return TextFormField(
      controller: _specificLocationController,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Floor / Room / Area (Optional)',
        hintText: 'e.g. 3rd Floor Rm 304, Drafting Table 4, Canteen Table #5',
        prefixIcon: const Icon(Icons.meeting_room_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCustodyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _custodyLocation,
      decoration: InputDecoration(
        labelText: 'Custody / Where did you turn it over? (Optional)',
        prefixIcon: const Icon(Icons.shield_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      isExpanded: true,
      items: custodyLocations
          .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
          .toList(),
      onChanged: (value) => setState(() => _custodyLocation = value),
    );
  }

  Widget _buildVerificationQuestionField(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.vpn_key_rounded,
                size: 16,
                color: Colors.amber.shade900,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ownership verification (recommended)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ask something only the true owner would know to prevent fraudulent claims.',
            style: TextStyle(fontSize: 11, color: Colors.brown.shade800),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _verificationQuestionController,
            decoration: InputDecoration(
              hintText: 'e.g. What sticker/wallpaper/item inside the wallet?',
              hintStyle: const TextStyle(fontSize: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(ColorScheme colorScheme) {
    final dateText = '${_date.month}/${_date.day}/${_date.year}';

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _type == 'lost' ? 'Date lost' : 'Date found',
          prefixIcon: const Icon(Icons.calendar_today_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(dateText, style: TextStyle(color: colorScheme.onSurface)),
      ),
    );
  }

  /// Photo selection and preview container.
  Widget _buildPhotoUploadSection(ColorScheme colorScheme) {
    if (_selectedImageBytes != null) {
      // Image is selected — show preview card with remove & replace actions
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item Photo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: _showImageSourcePicker,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Remove photo',
                    onPressed: _removeImage,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // No photo selected — show tap-to-upload area
    return InkWell(
      onTap: _showImageSourcePicker,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant,
            style: BorderStyle.solid,
          ),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                size: 32,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                'Add Photo (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Photos help others identify your item faster',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Private fields shown only when reporting FOUND money / wallets.
  Widget _buildSecuritySection(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Private verification details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Only you can see the answers. Do not mention the amount in the '
            'title, description, or photo. Please hand the item over at the '
            'Security Office and check the claimer\'s school ID.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _secureField(
            _amountController,
            'Exact amount / contents',
            'e.g. 2 x P500, 1 x P100',
          ),
          const SizedBox(height: 12),
          _secureField(
            _conditionController,
            'How was it found?',
            'e.g. inside a brown envelope, folded',
          ),
          const SizedBox(height: 12),
          _secureField(
            _q1Controller,
            'Question 1 for the claimer',
            'e.g. How much money was it?',
          ),
          const SizedBox(height: 12),
          _secureField(_a1Controller, 'Correct answer 1', 'Kept private'),
          const SizedBox(height: 12),
          _secureField(
            _q2Controller,
            'Question 2 for the claimer',
            'e.g. What was it kept in?',
          ),
          const SizedBox(height: 12),
          _secureField(_a2Controller, 'Correct answer 2', 'Kept private'),
        ],
      ),
    );
  }

  Widget _secureField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return FilledButton(
      onPressed: isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(
              _type == 'lost' ? 'Submit Lost Report' : 'Submit Found Report',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
