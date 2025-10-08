/// شاشات إرسال التقارير، الطلبات، والسلف للحارس.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/guard_advance.dart';
import '../models/guard_request.dart';
import '../services/api.dart';

/// نموذج رفع تقرير ميداني مع وصف ومرفقات.
class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  String? _selectedType;
  bool _submitting = false;
  final _picker = ImagePicker();
  final List<_PendingAttachment> _attachments = [];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedType == null || _selectedType!.isEmpty) {
      // form-level safety, the field validator should catch this
      return;
    }

    setState(() => _submitting = true);
    final t = AppLocalizations.of(context)!;

    final attachments = _attachments
        .map(
          (att) => ReportAttachmentUpload(
            file: File(att.file.path),
            contentType: att.mimeType,
          ),
        )
        .toList(growable: false);

    final result = await ApiService.submitGuardReport(
      reportType: _selectedType!,
      description: _detailsController.text.trim(),
      attachments: attachments,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.report_submit_success)));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty ? result.message : t.report_submit_error,
          ),
        ),
      );
    }
  }

  Future<void> _showAttachmentPicker() async {
    final t = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<_AttachmentAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(t.report_attachment_image_camera),
              onTap: () =>
                  Navigator.of(context).pop(_AttachmentAction.imageCamera),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(t.report_attachment_image_gallery),
              onTap: () =>
                  Navigator.of(context).pop(_AttachmentAction.imageGallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(t.report_attachment_video_camera),
              onTap: () =>
                  Navigator.of(context).pop(_AttachmentAction.videoCamera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(t.report_attachment_video_gallery),
              onTap: () =>
                  Navigator.of(context).pop(_AttachmentAction.videoGallery),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;

    switch (action) {
      case _AttachmentAction.imageCamera:
        await _pickAttachment(ImageSource.camera, isVideo: false);
        break;
      case _AttachmentAction.imageGallery:
        await _pickAttachment(ImageSource.gallery, isVideo: false);
        break;
      case _AttachmentAction.videoCamera:
        await _pickAttachment(ImageSource.camera, isVideo: true);
        break;
      case _AttachmentAction.videoGallery:
        await _pickAttachment(ImageSource.gallery, isVideo: true);
        break;
    }
  }

  Future<void> _pickAttachment(
    ImageSource source, {
    required bool isVideo,
  }) async {
    try {
      XFile? picked;
      if (isVideo) {
        picked = await _picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5),
        );
      } else {
        picked = await _picker.pickImage(
          source: source,
          imageQuality: 85,
          maxWidth: 2048,
        );
      }
      if (picked == null) return;

      final mime =
          await picked.mimeType ??
          _guessMimeType(picked.path, isVideo: isVideo);

      if (!mounted) return;
      setState(() {
        _attachments.add(
          _PendingAttachment(file: picked!, mimeType: mime, isVideo: isVideo),
        );
      });
    } catch (e) {
      if (!mounted) return;
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.report_attachment_pick_error} ($e)')),
      );
    }
  }

  String? _guessMimeType(String path, {required bool isVideo}) {
    final lower = path.toLowerCase();
    if (isVideo) {
      if (lower.endsWith('.mp4')) return 'video/mp4';
      if (lower.endsWith('.mov')) return 'video/quicktime';
      if (lower.endsWith('.mkv')) return 'video/x-matroska';
      if (lower.endsWith('.avi')) return 'video/x-msvideo';
      return 'video/mp4';
    } else {
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
        return 'image/jpeg';
      if (lower.endsWith('.gif')) return 'image/gif';
      if (lower.endsWith('.heic')) return 'image/heic';
      return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.create_report)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: [
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text(t.report_type_daily),
                    ),
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text(t.report_type_monthly),
                    ),
                    DropdownMenuItem(
                      value: 'security',
                      child: Text(t.report_type_security),
                    ),
                    DropdownMenuItem(
                      value: 'complaint',
                      child: Text(t.report_type_complaint),
                    ),
                  ],
                  decoration: InputDecoration(labelText: t.report_type_label),
                  onChanged: (value) => setState(() => _selectedType = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t.report_type_required;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _detailsController,
                  textInputAction: TextInputAction.newline,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: t.report_details),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return t.report_details_required;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _showAttachmentPicker,
                  icon: const Icon(Icons.attach_file),
                  label: Text(t.report_add_attachment),
                ),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    t.report_attachments,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_attachments.length, (index) {
                      final attachment = _attachments[index];
                      return InputChip(
                        avatar: Icon(
                          attachment.isVideo ? Icons.videocam : Icons.image,
                        ),
                        label: Text(attachment.displayName),
                        onDeleted: _submitting
                            ? null
                            : () {
                                setState(() => _attachments.removeAt(index));
                              },
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(t.submit_report),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AttachmentAction { imageCamera, imageGallery, videoCamera, videoGallery }

/// يغلّف الصورة أو الفيديو قبل الرفع مع بيانات MIME.
class _PendingAttachment {
  _PendingAttachment({
    required this.file,
    required this.mimeType,
    required this.isVideo,
  });

  final XFile file;
  final String? mimeType;
  final bool isVideo;

  String get displayName =>
      file.name.isNotEmpty ? file.name : file.path.split('/').last;
}

<<<<<<< HEAD
/// خيار متاح في قائمة الزي مع السعر التعريفي.
=======
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
class _UniformItemOption {
  _UniformItemOption({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final double price;
}

<<<<<<< HEAD
/// اختيار المستخدم من أصناف الزي مع الكمية والملاحظات.
=======
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
class _UniformSelection {
  _UniformSelection({
    required this.option,
    required this.quantity,
    this.notes,
  });

  final _UniformItemOption option;
  int quantity;
  String? notes;

  double get total => option.price * quantity;
}

<<<<<<< HEAD
/// يمكّن الحارس من إنشاء طلبات (تغطية، إجازة، نقل، مواد، زي).
=======
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key, this.initialType});

  final String? initialType;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String? _requestType;
  bool _submitting = false;
  DateTime? _leaveStart;
  DateTime? _leaveEnd;
  final List<_UniformItemOption> _uniformOptions = [];
  final List<_UniformSelection> _uniformSelections = [];
  bool _loadingUniformItems = false;
  String? _uniformItemsError;
  String _uniformPaymentMethod = 'deduction';
  bool _uniformRequestedOnce = false;

  @override
  void initState() {
    super.initState();
    _requestType = widget.initialType;
    if (_isUniformType) {
      _ensureUniformItemsLoaded();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_requestType == null || _requestType!.isEmpty) {
      return;
    }

    final t = AppLocalizations.of(context)!;

    if (_isLeaveType) {
      if (_leaveStart == null || _leaveEnd == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.leave_pick_dates_required)));
        return;
      }
      if (!_leaveEnd!.isAfter(_leaveStart!)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.leave_end_must_follow_start)));
        return;
      }
    }

    if (_isUniformType) {
      if (_uniformSelections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.uniform_items_required)),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    final result = await ApiService.submitGuardRequest(
      requestType: _requestType!,
      description: _descriptionController.text.trim(),
      leaveStart: _isLeaveType ? _leaveStart : null,
      leaveEnd: _isLeaveType ? _leaveEnd : null,
      uniformItems: _isUniformType
          ? _uniformSelections
              .map(
                (e) => {
                  'item_id': e.option.id,
                  'quantity': e.quantity,
                  if ((e.notes ?? '').trim().isNotEmpty) 'notes': e.notes!.trim(),
                },
              )
              .toList(growable: false)
          : null,
      paymentMethod: _isUniformType ? _uniformPaymentMethod : null,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.request_submit_success)));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty ? result.message : t.request_submit_error,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.create_request)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _requestType,
                  decoration: InputDecoration(labelText: t.request_type),
                  items: [
                    DropdownMenuItem(
                      value: 'coverage',
                      child: Text(t.request_type_coverage),
                    ),
                    DropdownMenuItem(
                      value: 'leave',
                      child: Text(t.request_type_leave),
                    ),
                    DropdownMenuItem(
                      value: 'transfer',
                      child: Text(t.request_type_transfer),
                    ),
                    DropdownMenuItem(
                      value: 'materials',
                      child: Text(t.request_type_materials),
                    ),
                    DropdownMenuItem(
                      value: 'uniform',
                      child: Text(t.uniform_request_title),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _requestType = value;
                      if (!_isLeaveType) {
                        _leaveStart = null;
                        _leaveEnd = null;
                      }
                      if (!_isUniformType) {
                        _uniformSelections.clear();
                        _uniformPaymentMethod = 'deduction';
                      }
                    });
                    if (value == 'uniform') {
                      _ensureUniformItemsLoaded();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t.request_type_required;
                    }
                    return null;
                  },
                ),
                if (_isLeaveType) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.play_arrow),
                          title: Text(t.leave_start_datetime),
                          subtitle: Text(
                            _leaveStart == null
                                ? t.leave_start_not_selected
                                : (_formatDateTime(_leaveStart!) ??
                                      t.leave_start_not_selected),
                          ),
                          onTap: _submitting
                              ? null
                              : () => _pickLeaveDateTime(isStart: true),
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.stop),
                          title: Text(t.leave_end_datetime),
                          subtitle: Text(
                            _leaveEnd == null
                                ? t.leave_end_not_selected
                                : (_formatDateTime(_leaveEnd!) ??
                                      t.leave_end_not_selected),
                          ),
                          onTap: _submitting
                              ? null
                              : () => _pickLeaveDateTime(isStart: false),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isUniformType) ...[
                  const SizedBox(height: 16),
                  _buildUniformSection(t, theme),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  textInputAction: TextInputAction.newline,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: t.request_description),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return t.request_description_required;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(t.submit_request),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isLeaveType => _requestType == 'leave';
  bool get _isUniformType => _requestType == 'uniform';

  double get _uniformTotal => _uniformSelections.fold(0.0, (sum, item) => sum + item.total);

  Future<void> _ensureUniformItemsLoaded() async {
    if (!_isUniformType || _loadingUniformItems) return;
    if (_uniformOptions.isNotEmpty) return;
    if (_uniformRequestedOnce && _uniformItemsError == null) return;
    _uniformRequestedOnce = true;
    setState(() {
      _loadingUniformItems = true;
      _uniformItemsError = null;
    });

    final result = await ApiService.fetchUniformItems();
    if (!mounted) return;

    if (result.ok) {
      final data = result.data;
      final List<dynamic> rawList;
      if (data != null && data['results'] is List) {
        rawList = List<dynamic>.from(data['results'] as List);
      } else {
        rawList = const [];
      }
      _uniformOptions
        ..clear()
        ..addAll(
          rawList.whereType<Map>().map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final price = double.tryParse(map['price']?.toString() ?? '') ?? 0;
            return _UniformItemOption(
              id: (map['id'] ?? '').toString(),
              name: (map['name'] ?? '').toString(),
              price: price,
            );
          }),
        );
      setState(() {
        _loadingUniformItems = false;
        _uniformItemsError = null;
      });
    } else {
      setState(() {
        _loadingUniformItems = false;
        _uniformItemsError = result.message;
      });
    }
  }

  Future<_UniformSelection?> _showUniformSelectionDialog({_UniformSelection? initial}) {
    if (_uniformOptions.isEmpty) {
      return Future.value(null);
    }

    return showDialog<_UniformSelection>(
      context: context,
      builder: (context) {
        return _UniformSelectionDialog(
          options: _uniformOptions,
          initial: initial,
        );
      },
    );
  }

  void _addUniformSelection() async {
    if (_uniformOptions.isEmpty) {
      await _ensureUniformItemsLoaded();
      if (!mounted || _uniformOptions.isEmpty) return;
    }
    final selection = await _showUniformSelectionDialog();
    if (selection == null || !mounted) return;
    setState(() {
      final existingIndex = _uniformSelections.indexWhere((s) => s.option.id == selection.option.id);
      if (existingIndex >= 0) {
        _uniformSelections[existingIndex].quantity += selection.quantity;
        if (selection.notes != null && selection.notes!.isNotEmpty) {
          _uniformSelections[existingIndex].notes = selection.notes;
        }
      } else {
        _uniformSelections.add(selection);
      }
    });
  }

  void _editUniformSelection(int index) async {
    final current = _uniformSelections[index];
    final edited = await _showUniformSelectionDialog(initial: current);
    if (edited == null || !mounted) return;
    setState(() {
      _uniformSelections[index] = edited;
    });
  }

  void _removeUniformSelection(int index) {
    setState(() {
      _uniformSelections.removeAt(index);
    });
  }

  Future<void> _pickLeaveDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_leaveStart ?? now)
        : (_leaveEnd ?? _leaveStart ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _leaveStart = combined;
        if (_leaveEnd != null && !_leaveEnd!.isAfter(_leaveStart!)) {
          _leaveEnd = _leaveStart!.add(const Duration(hours: 1));
        }
      } else {
        _leaveEnd = combined;
      }
    });
  }

  String? _formatDateTime(DateTime dateTime) {
    try {
      final locale = Localizations.localeOf(context).toString();
      return DateFormat.yMMMd(locale).add_Hm().format(dateTime.toLocal());
    } catch (_) {
      return DateFormat.yMMMd().add_Hm().format(dateTime.toLocal());
    }
  }

  Widget _buildUniformSection(AppLocalizations t, ThemeData theme) {
    if (_loadingUniformItems) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_uniformItemsError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.uniform_items_load_error,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_uniformItemsError!),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: _ensureUniformItemsLoaded,
                  child: Text(t.retry),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.uniform_request_hint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (_uniformSelections.isEmpty)
              Text(
                t.uniform_items_empty,
                style: theme.textTheme.bodySmall,
              ),
            if (_uniformOptions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.uniform_items_load_error,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (_uniformSelections.isNotEmpty)
              ..._uniformSelections.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final selection = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(selection.option.name),
                      subtitle: Text(
                        [
                          '${t.uniform_quantity}: ${selection.quantity}',
                          if (selection.notes != null && selection.notes!.isNotEmpty)
                            '${t.uniform_item_notes}: ${selection.notes}',
                        ].join('\n'),
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(selection.total.toStringAsFixed(2)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: t.uniform_item_remove,
                            onPressed: () => _removeUniformSelection(index),
                          ),
                        ],
                      ),
                      onTap: () => _editUniformSelection(index),
                    ),
                  );
                },
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: _uniformOptions.isEmpty ? null : _addUniformSelection,
                icon: const Icon(Icons.add),
                label: Text(t.uniform_add_item),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _uniformPaymentMethod,
              decoration: InputDecoration(labelText: t.uniform_payment_method),
              items: [
                DropdownMenuItem(
                  value: 'deduction',
                  child: Text(t.uniform_payment_deduction),
                ),
                DropdownMenuItem(
                  value: 'direct',
                  child: Text(t.uniform_payment_direct),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _uniformPaymentMethod = value);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                t.uniform_total_value(_uniformTotal.toStringAsFixed(2)),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
=======
}

class _UniformSelectionDialog extends StatefulWidget {
  const _UniformSelectionDialog({
    required this.options,
    this.initial,
  });

  final List<_UniformItemOption> options;
  final _UniformSelection? initial;

  @override
  State<_UniformSelectionDialog> createState() => _UniformSelectionDialogState();
}

class _UniformSelectionDialogState extends State<_UniformSelectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late _UniformItemOption? _selectedOption;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedOption = _initialOption();
    _quantityController = TextEditingController(
      text: (widget.initial?.quantity ?? 1).toString(),
    );
    _notesController = TextEditingController(text: widget.initial?.notes ?? '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  _UniformItemOption? _initialOption() {
    if (widget.options.isEmpty) return null;
    if (widget.initial == null) {
      return widget.options.first;
    }
    final initialId = widget.initial!.option.id;
    return widget.options.firstWhere(
      (option) => option.id == initialId,
      orElse: () => widget.options.first,
    );
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final quantity = int.parse(_quantityController.text.trim());
    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      _UniformSelection(
        option: _selectedOption!,
        quantity: quantity,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(
        widget.initial == null ? t.uniform_add_item : t.uniform_edit_item,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<_UniformItemOption>(
                value: _selectedOption,
                items: widget.options
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(
                          '${option.name} • ${option.price.toStringAsFixed(2)}',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _selectedOption = value),
                validator: (value) =>
                    value == null ? t.uniform_select_item : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: false,
                ),
                decoration: InputDecoration(labelText: t.uniform_quantity),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return t.uniform_quantity_invalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(labelText: t.uniform_item_notes),
                minLines: 1,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(t.task_cancel),
        ),
        FilledButton(
          onPressed: _selectedOption == null ? null : _confirm,
          child: Text(t.task_confirm),
        ),
      ],
    );
  }
>>>>>>> 405cf15 (توثيق الجهاز وتفعيل البصمه والتتبع للحارس)
}

/// حوار مصغّر لاختيار صنف الزي وتحديد الكمية والملاحظات.
class _UniformSelectionDialog extends StatefulWidget {
  const _UniformSelectionDialog({
    required this.options,
    this.initial,
  });

  final List<_UniformItemOption> options;
  final _UniformSelection? initial;

  @override
  State<_UniformSelectionDialog> createState() => _UniformSelectionDialogState();
}

/// يدير النموذج الداخلي للحوار ويعيد الاختيار النهائي.
class _UniformSelectionDialogState extends State<_UniformSelectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late _UniformItemOption? _selectedOption;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedOption = _initialOption();
    _quantityController = TextEditingController(
      text: (widget.initial?.quantity ?? 1).toString(),
    );
    _notesController = TextEditingController(text: widget.initial?.notes ?? '');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  _UniformItemOption? _initialOption() {
    if (widget.options.isEmpty) return null;
    if (widget.initial == null) {
      return widget.options.first;
    }
    final initialId = widget.initial!.option.id;
    return widget.options.firstWhere(
      (option) => option.id == initialId,
      orElse: () => widget.options.first,
    );
  }

  void _confirm() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final quantity = int.parse(_quantityController.text.trim());
    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      _UniformSelection(
        option: _selectedOption!,
        quantity: quantity,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(
        widget.initial == null ? t.uniform_add_item : t.uniform_edit_item,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<_UniformItemOption>(
                value: _selectedOption,
                items: widget.options
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(
                          '${option.name} • ${option.price.toStringAsFixed(2)}',
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _selectedOption = value),
                validator: (value) =>
                    value == null ? t.uniform_select_item : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: false,
                  decimal: false,
                ),
                decoration: InputDecoration(labelText: t.uniform_quantity),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return t.uniform_quantity_invalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(labelText: t.uniform_item_notes),
                minLines: 1,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(t.task_cancel),
        ),
        FilledButton(
          onPressed: _selectedOption == null ? null : _confirm,
          child: Text(t.task_confirm),
        ),
      ],
    );
  }
}

/// واجهة تقديم طلب سلفة مالية من الإدارة.
class CreateAdvanceScreen extends StatefulWidget {
  const CreateAdvanceScreen({super.key});

  @override
  State<CreateAdvanceScreen> createState() => _CreateAdvanceScreenState();
}

class _CreateAdvanceScreenState extends State<CreateAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final t = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    setState(() => _submitting = true);

    final result = await ApiService.submitGuardAdvance(
      amount: amount,
      reason: _reasonController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (result.ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.advance_submit_success)));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isNotEmpty ? result.message : t.advance_submit_error,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.create_advance)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: t.advance_amount),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return t.advance_amount_required;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  textInputAction: TextInputAction.newline,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(labelText: t.advance_reason),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(t.advance_submit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يعرض الطلبات المفتوحة مع حالات الموافقة الحالية.
class OpenRequestsScreen extends StatefulWidget {
  const OpenRequestsScreen({super.key});

  @override
  State<OpenRequestsScreen> createState() => _OpenRequestsScreenState();
}

/// يدير تحميل الطلبات وتحديثها عبر `RefreshIndicator`.
class _OpenRequestsScreenState extends State<OpenRequestsScreen> {
  late Future<List<GuardRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GuardRequest>> _load() async {
    final result = await ApiService.fetchGuardRequests();
    if (!result.ok) {
      throw Exception(result.message);
    }

    final data = result.data;
    final List<dynamic> rawList;
    if (data != null && data['results'] is List) {
      rawList = List<dynamic>.from(data['results'] as List);
    } else if (data != null && data['raw'] is List) {
      rawList = List<dynamic>.from(data['raw'] as List);
    } else {
      rawList = const [];
    }

    final requests = <GuardRequest>[];
    for (final item in rawList) {
      if (item is Map) {
        try {
          requests.add(GuardRequest.fromJson(item as Map));
        } catch (_) {
          // نتجاهل السجلات غير القابلة للتحويل
        }
      }
    }

    return requests;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Color _statusColor(ThemeData theme, GuardRequest request) {
    final value = request.status.toLowerCase();
    if (value.contains('approved') ||
        value.contains('accepted') ||
        value.contains('done')) {
      return theme.colorScheme.primary;
    }
    if (value.contains('rejected') || value.contains('cancel')) {
      return theme.colorScheme.error;
    }
    if (value.contains('pending') ||
        value.contains('open') ||
        value.contains('waiting')) {
      return theme.colorScheme.tertiary;
    }
    return theme.colorScheme.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.open_requests)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<GuardRequest>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.requests_load_error,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(snapshot.error.toString()),
                            const SizedBox(height: 12),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: FilledButton(
                                onPressed: _refresh,
                                child: Text(t.retry),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              final requests = snapshot.data ?? const [];
              if (requests.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t.requests_empty_state),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  request.primaryTitle,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Chip(
                                label: Text(
                                  request.statusDisplay.isEmpty
                                      ? '-'
                                      : request.statusDisplay,
                                ),
                                backgroundColor: _statusColor(
                                  theme,
                                  request,
                                ).withOpacity(0.12),
                                labelStyle: theme.textTheme.bodySmall?.copyWith(
                                  color: _statusColor(theme, request),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (request.requestTypeDisplay.isNotEmpty)
                            Text(
                              '${t.request_type}: ${request.requestTypeDisplay}',
                            ),
                          if (request.requestType == 'leave' &&
                              request.formattedLeaveRange != null)
                            Text(
                              '${t.leave_range}: ${request.formattedLeaveRange}',
                            ),
                          if (request.requestType == 'leave' &&
                              request.leaveHours?.isNotEmpty == true)
                            Text(
                              '${t.leave_hours_label}: ${request.leaveHours}',
                            ),
                          if (request.formattedDate != null)
                            Text(
                              '${t.request_submitted_on}: ${request.formattedDate}',
                            ),
                          if (request.description != null &&
                              request.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                request.description!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          if (request.uniformDelivery != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${t.uniform_payment_method}: ${request.uniformDelivery!.paymentMethodDisplay}',
                                  ),
                                  ...request.uniformDelivery!.items.map(
                                    (item) => Padding(
                                      padding: const EdgeInsetsDirectional.only(start: 8, top: 2),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('• ${item.itemName} × ${item.quantity} (${item.value})'),
                                          if (item.notes != null && item.notes!.isNotEmpty)
                                            Text(
                                              '${t.uniform_item_notes}: ${item.notes}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.uniform_total_value(request.uniformDelivery!.totalValue),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          if (request.approvalNotes != null &&
                              request.approvalNotes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${t.request_approval_notes}: ${request.approvalNotes!}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          if (request.approverName != null &&
                              request.approverName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${t.request_approver}: ${request.approverName!}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// قائمة السلف المفتوحة مع إمكانية إنشاء طلب جديد.
class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key});

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

/// يتحكم في تحميل السلف وعرضها كبطاقات.
class _AdvancesScreenState extends State<AdvancesScreen> {
  late Future<List<GuardAdvance>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GuardAdvance>> _load() async {
    final result = await ApiService.fetchGuardAdvances();
    if (!result.ok) {
      throw Exception(result.message);
    }

    final data = result.data;
    List<dynamic> raw = const [];
    if (data != null && data['results'] is List) {
      raw = List<dynamic>.from(data['results'] as List);
    } else if (data != null && data['raw'] is List) {
      raw = List<dynamic>.from(data['raw'] as List);
    }

    final advances = <GuardAdvance>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          advances.add(GuardAdvance.fromJson(item as Map));
        } catch (_) {
          // ignore invalid rows
        }
      }
    }
    return advances;
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.open_advances)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateAdvanceScreen()),
          );
          if (created == true) {
            await _refresh();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t.advance_submit_success)));
          }
        },
        icon: const Icon(Icons.add),
        label: Text(t.create_advance_short),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<GuardAdvance>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.advances_load_error,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(snapshot.error.toString()),
                            const SizedBox(height: 12),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: FilledButton(
                                onPressed: _refresh,
                                child: Text(t.retry),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              final advances = snapshot.data ?? const [];
              if (advances.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t.advances_empty_state),
                      ),
                    ),
                  ],
                );
              }

              final currency = NumberFormat.currency(
                symbol: t.currency_short_symbol,
                decimalDigits: 2,
              );

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: advances.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final advance = advances[index];
                  final amountText = currency.format(advance.amount);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  amountText,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Chip(
                                label: Text(
                                  advance.statusDisplay.isEmpty
                                      ? '-'
                                      : advance.statusDisplay,
                                ),
                                labelStyle: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (advance.reason != null &&
                              advance.reason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(advance.reason!),
                            ),
                          if (advance.formattedRequestedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${t.advance_requested_on}: ${advance.formattedRequestedAt}',
                              ),
                            ),
                          if (advance.formattedApprovedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${t.advance_approved_on}: ${advance.formattedApprovedAt}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
