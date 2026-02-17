import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/l10n/app_localizations.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String type; // 'privacy', 'terms', 'about'

  const LegalScreen({
    super.key,
    required this.title,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(l)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: _buildContent(context, l, isDark),
      ),
    );
  }

  String _getTitle(AppLocalizations l) {
    switch (type) {
      case 'privacy':
        return l.privacyPolicy;
      case 'terms':
        return l.termsOfUse;
      case 'about':
        return l.about;
      default:
        return title;
    }
  }

  List<Widget> _buildContent(
      BuildContext context, AppLocalizations l, bool isDark) {
    switch (type) {
      case 'privacy':
        return _buildPrivacy(context, l, isDark);
      case 'terms':
        return _buildTerms(context, l, isDark);
      case 'about':
        return _buildAbout(context, l, isDark);
      default:
        return [];
    }
  }

  // ─── Helpers ───

  Widget _heading(BuildContext context, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
      ),
    );
  }

  Widget _body(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppColors.primary)),
          Expanded(
            child: Text(text,
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _alertBox(BuildContext context, String text, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(isDark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
      ),
    );
  }

  Widget _footer(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 20),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    )),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    )),
          ),
        ],
      ),
    );
  }

  Widget _dataTable(BuildContext context, AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).dividerTheme.color ?? AppColors.borderLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
          },
          border: TableBorder.symmetric(
            inside:
                BorderSide(color: Theme.of(context).dividerTheme.color ?? AppColors.borderLight),
          ),
          children: [
            _tableRow(context, l.privacyDataType, l.privacyDataPurpose,
                isHeader: true),
            _tableRow(
                context, l.privacyDataName, l.privacyDataNamePurpose),
            _tableRow(
                context, l.privacyDataPhone, l.privacyDataPhonePurpose),
            _tableRow(context, l.privacyDataFeedback,
                l.privacyDataFeedbackPurpose),
          ],
        ),
      ),
    );
  }

  TableRow _tableRow(BuildContext context, String c1, String c2,
      {bool isHeader = false}) {
    return TableRow(
      decoration: isHeader
          ? BoxDecoration(color: AppColors.primary.withOpacity(0.08))
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(c1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isHeader ? FontWeight.w600 : null,
                  )),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(c2,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isHeader ? FontWeight.w600 : null,
                  )),
        ),
      ],
    );
  }

  Widget _contactBlock(BuildContext context, AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(context, '🏢', l.contactCompany),
          _infoRow(context, '📧', l.contactEmail),
          _infoRow(context, '📱', l.contactApp),
        ],
      ),
    );
  }

  // ─── Privacy Policy ───

  List<Widget> _buildPrivacy(
      BuildContext context, AppLocalizations l, bool isDark) {
    return [
      Text(l.privacyTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              )),
      const SizedBox(height: 4),
      _body(context, l.privacyEffectiveDate),
      _heading(context, l.privacyIntroTitle, isDark),
      _body(context, l.privacyIntro1),
      _body(context, l.privacyIntro2),
      _heading(context, l.privacyDataTitle, isDark),
      _body(context, l.privacyVoluntary),
      _body(context, l.privacyVoluntaryDesc),
      _dataTable(context, l),
      _alertBox(context, l.privacyImportantNote, isDark),
      _body(context, l.privacyLocalStorage),
      _body(context, l.privacyLocalStorageDesc),
      _bullet(context, l.privacyLocalItem1),
      _bullet(context, l.privacyLocalItem2),
      _bullet(context, l.privacyLocalItem3),
      _body(context, l.privacyNotCollected),
      _bullet(context, l.privacyNotGps),
      _bullet(context, l.privacyNotContacts),
      _bullet(context, l.privacyNotDevice),
      _bullet(context, l.privacyNotAds),
      _bullet(context, l.privacyNotFinance),
      _bullet(context, l.privacyNotBiometric),
      _heading(context, l.privacyUsageTitle, isDark),
      _body(context, l.privacyUsageDesc),
      _bullet(context, l.privacyUsage1),
      _bullet(context, l.privacyUsage2),
      _bullet(context, l.privacyUsage3),
      _alertBox(context, l.privacyUsageNoMarketing, isDark),
      _heading(context, l.privacyThirdPartyTitle, isDark),
      _body(context, l.privacyThirdParty1),
      _body(context, l.privacyThirdParty2),
      _heading(context, l.privacySecurityTitle, isDark),
      _bullet(context, l.privacySecurity1),
      _bullet(context, l.privacySecurity2),
      _bullet(context, l.privacySecurity3),
      _bullet(context, l.privacySecurity4),
      _heading(context, l.privacyRightsTitle, isDark),
      _bullet(context, l.privacyRight1),
      _bullet(context, l.privacyRight2),
      _bullet(context, l.privacyRight3),
      _bullet(context, l.privacyRight4),
      _body(context, l.privacyRightsContact),
      _heading(context, l.privacyChildrenTitle, isDark),
      _body(context, l.privacyChildrenDesc),
      _heading(context, l.privacyThirdServicesTitle, isDark),
      _body(context, l.privacyThirdServicesDesc),
      _heading(context, l.privacyLawTitle, isDark),
      _bullet(context, l.privacyLaw1),
      _bullet(context, l.privacyLaw2),
      _bullet(context, l.privacyLaw3),
      _bullet(context, l.privacyLaw4),
      _heading(context, l.privacyContactTitle, isDark),
      _contactBlock(context, l),
      _footer(context, l.privacyFooter),
    ];
  }

  // ─── Terms of Use ───

  List<Widget> _buildTerms(
      BuildContext context, AppLocalizations l, bool isDark) {
    return [
      Text(l.termsTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              )),
      const SizedBox(height: 4),
      _body(context, l.termsEffectiveDate),
      _heading(context, l.termsGeneralTitle, isDark),
      _body(context, l.termsGeneral1),
      _body(context, l.termsGeneral2),
      _heading(context, l.termsDescTitle, isDark),
      _body(context, l.termsDesc),
      _alertBox(context, l.termsLegalBasis, isDark),
      _heading(context, l.termsRightsTitle, isDark),
      _bullet(context, l.termsRight1),
      _bullet(context, l.termsRight2),
      _bullet(context, l.termsRight3),
      _heading(context, l.termsProhibitedTitle, isDark),
      _bullet(context, l.termsProhibited1),
      _bullet(context, l.termsProhibited2),
      _bullet(context, l.termsProhibited3),
      _bullet(context, l.termsProhibited4),
      _bullet(context, l.termsProhibited5),
      _heading(context, l.termsLicenseTitle, isDark),
      _body(context, l.termsLicenseDesc),
      _body(context, l.termsLicense1),
      _body(context, l.termsLicense2),
      _body(context, l.termsLicense3),
      _body(context, l.termsLicense4),
      _heading(context, l.termsLiabilityTitle, isDark),
      _body(context, l.termsLiabilityDesc),
      _heading(context, l.termsInternetTitle, isDark),
      _body(context, l.termsInternetDesc),
      _bullet(context, l.termsInternet1),
      _bullet(context, l.termsInternet2),
      _bullet(context, l.termsInternet3),
      _heading(context, l.termsIPTitle, isDark),
      _body(context, l.termsIP1),
      _body(context, l.termsIP2),
      _heading(context, l.termsDisputeTitle, isDark),
      _body(context, l.termsDisputeDesc),
      _heading(context, l.termsContactTitle, isDark),
      _contactBlock(context, l),
      _footer(context, l.termsFooter),
    ];
  }

  // ─── About ───

  List<Widget> _buildAbout(
      BuildContext context, AppLocalizations l, bool isDark) {
    return [
      Text(l.aboutTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              )),
      const SizedBox(height: 4),
      _body(context, l.aboutSubtitle),

      // Info card
      Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _infoRow(context, '📱', l.aboutAppName),
            _infoRow(context, '📦', 'v${l.aboutVersion}'),
            _infoRow(context, '🏢', l.aboutDeveloper),
            _infoRow(context, '📂', l.aboutCategoryValue),
            _infoRow(context, '💰', l.aboutPriceValue),
            _infoRow(context, '📜', l.aboutLicense),
          ],
        ),
      ),

      _heading(context, l.aboutDescTitle, isDark),
      _body(context, l.aboutDesc),
      _alertBox(context, l.aboutLegalBasis, isDark),
      _heading(context, l.aboutAuthorTitle, isDark),
      _body(context, l.aboutAuthorDesc),
      _heading(context, l.aboutAudioTitle, isDark),
      _body(context, l.aboutAudioDesc),

      _heading(context, l.aboutFeaturesTitle, isDark),
      _bullet(context, l.aboutFeature1),
      _bullet(context, l.aboutFeature2),
      _bullet(context, l.aboutFeature3),
      _bullet(context, l.aboutFeature4),
      _bullet(context, l.aboutFeature5),
      _bullet(context, l.aboutFeature6),
      _bullet(context, l.aboutFeature7),

      _heading(context, l.aboutTechTitle, isDark),
      _body(context, 'Flutter • Dart • Riverpod • Go Router • Just Audio • Dio'),

      _heading(context, l.aboutOpenSourceTitle, isDark),
      _body(context, l.aboutOpenSource1),
      _body(context, l.aboutOpenSource2),

      _heading(context, l.aboutPublishTitle, isDark),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _infoRow(context, '✍️', l.aboutOriginalAuthor),
            _infoRow(context, '📜', l.aboutPublishBasis),
            _infoRow(context, '🎙️', l.aboutAudio),
            _infoRow(context, '💻', l.aboutDigitization),
            _infoRow(context, '📅', l.aboutPublishYear),
          ],
        ),
      ),

      _heading(context, l.aboutThanksTitle, isDark),
      _bullet(context, l.aboutThanks1),
      _bullet(context, l.aboutThanks2),
      _bullet(context, l.aboutThanks3),
      _bullet(context, l.aboutThanks4),
      _bullet(context, l.aboutThanks5),

      _heading(context, l.aboutContactTitle, isDark),
      _contactBlock(context, l),
      _footer(context, l.aboutFooter),
    ];
  }
}
