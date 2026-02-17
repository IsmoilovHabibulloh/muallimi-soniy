import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../core/theme/colors.dart';
import '../../core/constants.dart';
import '../../core/l10n/app_localizations.dart';
import '../../domain/providers/book_provider.dart';
import '../widgets/copyright_footer.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _detailsController = TextEditingController();
  String _feedbackType = 'taklif';
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/feedback', data: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'feedback_type': _feedbackType,
        'details': _detailsController.text.trim(),
      });

      setState(() {
        _submitted = true;
        _submitting = false;
      });
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l?.errorOccurred ?? 'Xatolik yuz berdi.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('💬 ${l.feedbackTitle}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _submitted ? _buildSuccess() : _buildForm(),
            const CopyrightFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 64, color: AppColors.success),
            ),
            const SizedBox(height: 24),
            Text(
              l.thanks,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.feedbackSent,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: Text(l.backToHome),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final l = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.feedbackSubtitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l.fillAllFields,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),

          // Name
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l.yourName,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? l.nameRequired : null,
          ),
          const SizedBox(height: 16),

          // Phone
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: l.phoneNumber,
              prefixIcon: const Icon(Icons.phone_outlined),
              hintText: '+998901234567',
            ),
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l.phoneRequired;
              final clean = v.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
              if (!RegExp(r'^\+?998\d{9}$').hasMatch(clean)) {
                return l.phoneInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Type
          Text(l.type, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TypeChip(
                  label: l.suggestion,
                  selected: _feedbackType == 'taklif',
                  onTap: () => setState(() => _feedbackType = 'taklif'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeChip(
                  label: l.bugReport,
                  selected: _feedbackType == 'xatolik',
                  onTap: () => setState(() => _feedbackType = 'xatolik'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details
          TextFormField(
            controller: _detailsController,
            decoration: InputDecoration(
              labelText: l.details,
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.edit_note_rounded),
              ),
            ),
            maxLines: 4,
            validator: (v) => (v == null || v.trim().length < 10)
                ? l.minChars
                : null,
          ),
          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l.submit),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withOpacity(0.12)
          : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : (Theme.of(context).dividerTheme.color ?? AppColors.borderLight),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.primary : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
