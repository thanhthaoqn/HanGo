import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/services/ticket_service.dart';
import '../../../utils/toast_helper.dart';

class CreateTicketModal extends StatefulWidget {
  final TicketModel? existingTicket;
  final VoidCallback onSuccess;

  const CreateTicketModal({
    super.key,
    this.existingTicket,
    required this.onSuccess,
  });

  @override
  State<CreateTicketModal> createState() => _CreateTicketModalState();
}

class _CreateTicketModalState extends State<CreateTicketModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ticketService = TicketService();

  String _category = 'GENERAL_ENQUIRY';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTicket != null) {
      _titleController.text = widget.existingTicket!.title;
      _descriptionController.text = widget.existingTicket!.description;
      _category = widget.existingTicket!.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ToastHelper.showError(context, 'Please enter title and description.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> res;
    if (widget.existingTicket != null) {
      res = await _ticketService.updateTicket(
        widget.existingTicket!.id,
        title: title,
        description: description,
      );
    } else {
      res = await _ticketService.createTicket(
        title: title,
        description: description,
        category: _category,
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (res['success'] == true) {
        ToastHelper.showSuccess(
          context,
          widget.existingTicket != null
              ? 'Ticket updated successfully!'
              : 'Support ticket created successfully!',
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        ToastHelper.showError(context, res['message'] ?? 'Action failed.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTicket != null;
    final codeText = isEdit ? widget.existingTicket!.ticketCode : '';

    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (event) {
        if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.enter) {
          _submit();
        }
      },
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Update Ticket' : 'Create Support Ticket',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Code: $codeText',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.existingTicket!.status,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),



                // Title Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Title *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _titleController,
                      builder: (context, value, _) {
                        return Text(
                          '${value.text.length} / 200',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Brief summary of your issue (<= 200 chars)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                // Description Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Description / Content *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _descriptionController,
                      builder: (context, value, _) {
                        return Text(
                          '${value.text.length} / 4000',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Describe your issue in detail...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
                ),
                const SizedBox(height: 12),

                // Shortcut tip
                const Text(
                  'Tip: Press Ctrl + Enter to save quickly',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 24),

                // Actions Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEdit ? 'Save Changes' : 'Submit Ticket'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
