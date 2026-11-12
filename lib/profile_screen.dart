import 'platform_capabilities.dart';
import 'package:flutter/material.dart';

import 'adaptive_form.dart';
import 'app_strings.dart';
import 'auth_api.dart';
import 'brand_assets.dart';
import 'profile_photo.dart';
import 'profile_suggest_field.dart';
import 'profile_suggestions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onSaved,
    required this.onSignOut,
    this.onCancel,
    this.onLanguageChanged,
    this.themeButton,
  });

  final AppUser user;
  final AuthApi api;
  final ValueChanged<AppUser> onSaved;
  final Future<void> Function() onSignOut;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onLanguageChanged;
  final Widget? themeButton;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _profession = TextEditingController(text: widget.user.profession);
  late final _job = TextEditingController(text: widget.user.job);
  late final _study = TextEditingController(text: widget.user.fieldOfStudy);
  late List<String> _interests = [...widget.user.interests];
  late List<String> _hobbies = [...widget.user.hobbies];
  final String? _savedPhoto = profilePhotoNotifier.value;
  late String? _photo = _savedPhoto;
  bool _photoBusy = false;
  bool _saving = false;
  String? _error;

  String _t(String text) => AppStrings.of(context).text(text);

  @override
  void dispose() {
    for (final controller in [
      _name,
      _profession,
      _job,
      _study,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // Leaving the chip fields adds any text still typed in them.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final interests = _interests;
    final hobbies = _hobbies;
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Use 2 to 80 characters for your name.');
      return;
    }
    if (interests.isEmpty && hobbies.isEmpty) {
      setState(() => _error = 'Add at least one interest or hobby.');
      return;
    }
    if ([
      interests,
      hobbies,
    ].any((list) => list.length > 12 || list.any((item) => item.length > 60))) {
      setState(
        () => _error =
            'Keep up to 12 interests or hobbies, with 60 characters per item.',
      );
      return;
    }
    if ([interests, hobbies].any(
      (list) =>
          list.map((item) => item.toLowerCase()).toSet().length != list.length,
    )) {
      setState(() => _error = 'Remove repeated interests or hobbies.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_photo != _savedPhoto) {
        await widget.api.updateProfilePhoto(_photo);
        profilePhotoNotifier.value = _photo;
      }
      final user = await widget.api.updateProfile(
        name: _name.text.trim(),
        profession: _profession.text.trim(),
        job: _job.text.trim(),
        fieldOfStudy: _study.text.trim(),
        interests: interests,
        hobbies: hobbies,
      );
      if (mounted) widget.onSaved(user);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool optional = false,
    String? hint,
    int? maxLength,
    int lines = 1,
  }) => TextField(
    controller: controller,
    maxLength: maxLength, buildCounter: quietFormCounter,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: optional ? '$label · ${_t('Optional')}' : label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;
    final muted = dark ? const Color(0xFFB5BECC) : const Color(0xFF545E6D);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 36,
            vertical: 22,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrainyMark(size: 34),
                      const SizedBox(width: 10),
                      Text(
                        'brainy',
                        style: TextStyle(
                          fontSize: 22,
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (widget.themeButton != null) widget.themeButton!,
                      LanguageMenu(onChanged: widget.onLanguageChanged),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: dark
                            ? const Color(0xFF3E4653)
                            : const Color(0xFFDDE2EA),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 22 : 38),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF26334A)
                                  : const Color(0xFFE9F0FC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _t(
                              widget.user.profileCompleted
                                  ? 'Edit profile'
                                  : 'Tell us about yourself',
                            ),
                            style: TextStyle(
                              fontSize: compact ? 27 : 36,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t(
                              'Tell Brainy about your work and interests. Meeting people with similar interests may be offered later.',
                            ),
                            style: TextStyle(color: muted, height: 1.45),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _t(
                              'Your profile is private. Any future sharing will require your choice.',
                            ),
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 26),
                          // On Vercel's free plan no picture is stored: the initial stands for the person.
                          if (!BrainyPlatform.isFrozen('mediaFiles') || _photo != null) ListenableBuilder(
                            listenable: _name,
                            builder: (context, _) => ProfilePhotoPicker(
                              name: _name.text,
                              photo: _photo,
                              onChanged: (photo) => setState(() => _photo = photo),
                              onBusy: (busy) => setState(() => _photoBusy = busy),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _field(_t('Your name'), _name, maxLength: 80),
                          const SizedBox(height: 8),
                          SuggestTextField(
                            label: _t('Profession'),
                            controller: _profession,
                            suggestions: occupationSuggestions,
                            optional: true,
                          ),
                          const SizedBox(height: 8),
                          SuggestTextField(
                            label: _t('Current job or role'),
                            controller: _job,
                            suggestions: occupationSuggestions,
                            optional: true,
                          ),
                          const SizedBox(height: 8),
                          _field(
                            _t('Field of study'),
                            _study,
                            optional: true,
                            maxLength: 100,
                          ),
                          const SizedBox(height: 8),
                          SuggestTagsField(
                            label: _t('Interests'),
                            values: _interests,
                            suggestions: interestSuggestions,
                            onChanged: (values) => setState(() => _interests = values),
                          ),
                          const SizedBox(height: 14),
                          SuggestTagsField(
                            label: _t('Hobbies'),
                            values: _hobbies,
                            suggestions: hobbySuggestions,
                            onChanged: (values) => setState(() => _hobbies = values),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                AppStrings.of(context).error(_error!),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (widget.onCancel != null)
                                OutlinedButton(
                                  onPressed: widget.onCancel,
                                  child: Text(_t('Cancel')),
                                ),
                              FilledButton.icon(
                                onPressed: _saving || _photoBusy ? null : _save,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: Text(
                                  _t(
                                    widget.user.profileCompleted
                                        ? 'Save profile'
                                        : 'Continue to workspace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.user.profileCompleted)
                    Center(
                      child: TextButton(
                        onPressed: widget.onSignOut,
                        child: Text(_t('Sign out')),
                      ),
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
