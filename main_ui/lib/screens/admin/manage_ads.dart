// In screens/admin/manage_ads.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:main_ui/utils/constants.dart';
import 'package:main_ui/services/api_service.dart'; // Assuming this handles auth headers

class ManageAdsScreen extends ConsumerStatefulWidget {
  const ManageAdsScreen({super.key});

  @override
  ConsumerState<ManageAdsScreen> createState() => _ManageAdsScreenState();
}

class _ManageAdsScreenState extends ConsumerState<ManageAdsScreen> {
  List<dynamic> ads = [];
  bool isLoading = true;
  PlatformFile? _selectedImageFile; // Move this to class level

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    debugPrint('[_loadAds] Start loading ads...');
    try {
      final response = await ApiService.get(
          '/admins/ads'); // Ensure ApiService adds 'Authorization: Bearer <token>'
      debugPrint('[_loadAds] Response received: ${response?.data}');
      if (mounted) {
        setState(() {
          ads = response.data ?? [];
          isLoading = false;
        });
      }
      debugPrint('[_loadAds] Loaded ${ads.length} ads');
      if (ads.isNotEmpty) {
        debugPrint('[_loadAds] First ad: ${ads.first}');
      }
    } catch (e, st) {
      debugPrint('[_loadAds] Error: $e');
      debugPrint('[_loadAds] Stack: $st');
      // Handle 401 specifically
      if (e.toString().contains('401')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unauthorized: Please log in again')),
        );
        // Redirect to login
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _createAd(
      Map<String, String> adData, PlatformFile? imageFile) async {
    debugPrint('[_createAd] Creating ad with data: $adData');
    debugPrint('[_createAd] Image file selected: ${imageFile?.name ?? 'none'}');
    debugPrint('[_createAd] Image file path: ${imageFile?.path}');
    debugPrint('[_createAd] Image file bytes: ${imageFile?.bytes?.length ?? 'null'} bytes');

    if (imageFile != null) {
      // Enhanced validation for image file
      final ext = imageFile.extension?.toLowerCase() ?? '';
      final allowedFormats = ['jpg', 'jpeg', 'png', 'heic', 'gif', 'bmp', 'webp'];
      
      if (!allowedFormats.contains(ext)) {
        debugPrint('[_createAd] Invalid extension: $ext');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid image format. Allowed: JPG, PNG, HEIC, GIF, BMP, WEBP'),
          ),
        );
        return;
      }

      if (imageFile.path == null || imageFile.bytes == null) {
        debugPrint('[_createAd] Warning: Selected file has null path or bytes');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid image file selected')),
        );
        return;
      }
    }

    try {
      final resp = await ApiService.postMultipart(
        '/admins/ads',
        data: adData,
        files: imageFile != null ? [imageFile] : [],
        fieldName: 'image_file',
      );
      
      debugPrint('[_createAd] Response: $resp');
      await _loadAds(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad created successfully')),
      );
    } catch (e, st) {
      debugPrint('[_createAd] Error: $e');
      debugPrint('[_createAd] Stack trace: $st');
      
      String errorMessage = 'Failed to create ad';
      if (e.toString().contains('format')) {
        errorMessage = 'Invalid image format';
      } else if (e.toString().contains('size')) {
        errorMessage = 'Image file too large';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorMessage: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateAd(
      int adId, Map<String, String> adData, PlatformFile? imageFile) async {
    debugPrint('[_updateAd] Updating ad id=$adId with data: $adData');
    debugPrint('[_updateAd] Image file selected: ${imageFile != null ? imageFile.name : 'none'}');
    
    if (imageFile != null) {
      // Enhanced validation for image file
      final ext = imageFile.extension?.toLowerCase() ?? '';
      final allowedFormats = ['jpg', 'jpeg', 'png', 'heic', 'gif', 'bmp', 'webp'];
      
      if (!allowedFormats.contains(ext)) {
        debugPrint('[_updateAd] Invalid extension: $ext');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid image format. Allowed: JPG, PNG, HEIC, GIF, BMP, WEBP'),
          ),
        );
        return;
      }

      if (imageFile.path == null || imageFile.bytes == null) {
        debugPrint('[_updateAd] Warning: Selected file has null path or bytes');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid image file selected')),
        );
        return;
      }
    }
    
    try {
      final resp = await ApiService.putMultipart(
        '/admins/ads/$adId',
        data: adData,
        file: imageFile,
        fileField: 'image_file',
      );
      debugPrint('[_updateAd] Response: $resp');
      _loadAds(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad updated successfully')),
      );
    } catch (e, st) {
      debugPrint('[_updateAd] Error: $e');
      debugPrint('[_updateAd] Stack: $st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update ad: $e')),
      );
    }
  }

  Future<void> _deleteAd(int adId) async {
    debugPrint('[_deleteAd] Deleting ad id=$adId');
    try {
      final resp = await ApiService.delete('/admins/ads/$adId');
      debugPrint('[_deleteAd] Response: $resp');
      _loadAds(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad deleted successfully')),
      );
    } catch (e, st) {
      debugPrint('[_deleteAd] Error: $e');
      debugPrint('[_deleteAd] Stack: $st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete ad: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Ads')),
      body: ListView.builder(
        itemCount: ads.length,
        itemBuilder: (context, index) {
          final ad = ads[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: ListTile(
              leading: ad['image_url'] != null &&
                      ad['image_url'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        '${Constants.baseUrl}/uploads/${ad['image_url']}',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported),
                      ),
                    )
                  : const Icon(Icons.image, size: 40),
              title: Text(ad['title'] ?? 'No Title',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ad['description'] != null &&
                      ad['description'].toString().isNotEmpty)
                    Text(ad['description'],
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (ad['link_url'] != null &&
                      ad['link_url'].toString().isNotEmpty)
                    Text(
                      ad['link_url'],
                      style: const TextStyle(color: Colors.blueAccent),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showAdDialog(ad: ad),
                    tooltip: 'Edit Ad',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text('Delete Ad'),
                                content: const Text(
                                    'Are you sure you want to delete this ad?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel')),
                                  ElevatedButton(
                                      onPressed: () {
                                        _deleteAd(ad['id']);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete')),
                                ],
                              ));
                    },
                    tooltip: 'Delete Ad',
                  ),
                ],
              ),
              onTap: () async {
                final url = ad['link_url'];
                debugPrint('[onTap] Ad tapped. link_url=$url');
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdDialog(), // Implement dialog for form
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAdDialog({Map<String, dynamic>? ad}) {
    final bool isEditing = ad != null;
    final titleController = TextEditingController(text: ad?['title']);
    final descriptionController = TextEditingController(text: ad?['description']);
    final linkUrlController = TextEditingController(text: ad?['link_url']);
    bool isActive = ad?['is_active'] ?? true;
    DateTime? expiresAt = ad?['expires_at'] != null
        ? DateTime.parse(ad!['expires_at'])
        : null;

    // Clear the selected file when opening dialog
    setState(() {
      _selectedImageFile = null;
    });

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Ad' : 'Create Ad'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 16),
                // --- Fixed Image Picker ---
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select Image'),
                      onPressed: () async {
                        debugPrint('[ImagePicker] Opening file picker...');
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true, // CRITICAL: Ensure bytes are available
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.first;
                          final ext = file.extension?.toLowerCase() ?? '';
                          final allowedFormats = ['jpg', 'jpeg', 'png', 'heic', 'gif', 'bmp', 'webp'];
                          
                          if (!allowedFormats.contains(ext)) {
                            debugPrint('[ImagePicker] Invalid extension: $ext');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid image format. Allowed: JPG, PNG, HEIC, GIF, BMP, WEBP'),
                              ),
                            );
                            return;
                          }

                          debugPrint('[ImagePicker] File selected: ${file.name}, bytes: ${file.bytes?.length ?? 0}');
                          setState(() {
                            _selectedImageFile = file;
                          });
                        } else {
                          debugPrint('[ImagePicker] No file selected (cancelled)');
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedImageFile?.name ?? (isEditing ? 'Keep current image' : 'No file selected'), 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _selectedImageFile != null ? Colors.green : Colors.grey,
                        ),
                      ),
                    )
                  ],
                ),
                if (_selectedImageFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${(_selectedImageFile!.size / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: linkUrlController,
                  decoration: const InputDecoration(labelText: 'Link URL'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (val) => setState(() => isActive = val),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(expiresAt == null
                      ? 'Set Expiry Date'
                      : 'Expires: ${DateFormat.yMMMd().format(expiresAt!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: expiresAt ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (pickedDate != null) {
                      setState(() => expiresAt = pickedDate);
                      debugPrint('[DatePicker] Expires at set to: $expiresAt');
                    } else {
                      debugPrint('[DatePicker] No expiry date selected');
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () {
                final adData = <String, String>{
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'link_url': linkUrlController.text.trim(),
                  'is_active': isActive.toString(),
                  if (expiresAt != null)
                    'expires_at': expiresAt!.toIso8601String(),
                };

                // Debug log each field and whether it's empty
                debugPrint('[Submit] Title: "${adData['title']}" (empty=${adData['title']!.isEmpty})');
                debugPrint('[Submit] Description: "${adData['description']}" (empty=${adData['description']!.isEmpty})');
                debugPrint('[Submit] Link URL: "${adData['link_url']}" (empty=${adData['link_url']!.isEmpty})');
                debugPrint('[Submit] Is Active: ${adData['is_active']}');
                debugPrint('[Submit] Expires At: ${adData['expires_at'] ?? 'none'}');
                debugPrint('[Submit] Selected image: ${_selectedImageFile != null ? _selectedImageFile!.name : 'none'}');

                if (adData['title']!.isNotEmpty) {
                  if (isEditing) {
                    debugPrint('[Submit] Triggering update for id=${ad!['id']}');
                    _updateAd(ad!['id'], adData, _selectedImageFile);
                  } else {
                    debugPrint('[Submit] Triggering create');
                    _createAd(adData, _selectedImageFile);
                  }
                  Navigator.pop(context);
                } else {
                  debugPrint('[Submit] Title is empty — not submitting');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title is required')),
                  );
                }
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}