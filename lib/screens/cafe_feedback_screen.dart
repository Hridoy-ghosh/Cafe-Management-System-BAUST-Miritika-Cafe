import 'package:flutter/material.dart';

import '../services/cafe_operations_service.dart';
import '../widgets/theme_mode_button.dart';

class CafeFeedbackScreen extends StatefulWidget {
  const CafeFeedbackScreen({super.key});

  @override
  State<CafeFeedbackScreen> createState() => _CafeFeedbackScreenState();
}

class _CafeFeedbackScreenState extends State<CafeFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await CafeOperationsService.submitFeedback(
        rating: _rating,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Thank you. Your feedback was sent to cafe management.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send feedback: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cafe feedback & complaints'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: const [ThemeModeButton(color: Colors.white)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tell us about your visit. Cafe management will review your message.',
                  ),
                  const SizedBox(height: 18),
                  const Text('Your rating'),
                  Wrap(
                    spacing: 4,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        tooltip: '${index + 1} stars',
                        onPressed: () => setState(() => _rating = index + 1),
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber.shade700,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: _subject,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a subject'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _message,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Message or complaint',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your message'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_saving ? 'Sending…' : 'Send feedback'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
