import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';
import '../models/governorate.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import 'create_job_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final Job job;
  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final _service = SupabaseService();
  bool _isLoadingApplicants = true;
  List<JobApplicant> _applicants = [];
  late Job _job;
  Governorate? _governorate;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final govs = await _service.getGovernorates();
      final applicants = await _service.getJobApplicants(_job.id!);
      
      if (mounted) {
        setState(() {
          _governorate = govs.firstWhere((g) => g.id == _job.governorateId);
          _applicants = applicants;
          _isLoadingApplicants = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingApplicants = false);
    }
  }

  Future<void> _closeJob() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('close_job'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(l10n.translate('confirm_cancel'), style: GoogleFonts.cairo()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.translate('cancel'), style: GoogleFonts.cairo())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.translate('confirm'), style: GoogleFonts.cairo(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _service.closeJob(_job.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(l10n.translate('job_details'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGreen),
        actions: [
          if (_job.isActive)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateJobScreen(jobToEdit: _job)),
                );
                if (result == true) Navigator.pop(context, true);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(l10n, darkGreen, primaryGreen, lang),
            const SizedBox(height: 24),
            Text(l10n.translate('applicants'), style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
            const SizedBox(height: 12),
            _isLoadingApplicants
                ? const Center(child: CircularProgressIndicator(color: primaryGreen))
                : _applicants.isEmpty
                    ? _buildEmptyApplicants(l10n)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _applicants.length,
                        itemBuilder: (context, index) => _buildApplicantCard(_applicants[index], l10n, darkGreen),
                      ),
            const SizedBox(height: 32),
            if (_job.isActive)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _closeJob,
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: Text(l10n.translate('close_job'), style: GoogleFonts.cairo(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(AppLocalizations l10n, Color darkGreen, Color primaryGreen, String lang) {
    String timeRange = "";
    if (_job.startTime.isNotEmpty && _job.endTime.isNotEmpty) {
      timeRange = " (${_job.startTime} - ${_job.endTime})";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_job.title, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: darkGreen)),
              if (!_job.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(l10n.translate('closed'), style: GoogleFonts.cairo(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_job.description, style: GoogleFonts.cairo(color: Colors.grey[700], height: 1.5)),
          const Divider(height: 32),
          _buildDetailRow(Icons.calendar_today_outlined, l10n.translate('date'), 
              '${DateFormat('MMM d').format(_job.startDate)} - ${DateFormat('MMM d, yyyy').format(_job.endDate)}'),
          _buildDetailRow(Icons.access_time, l10n.translate('work_hours'), _job.workHours + timeRange),
          _buildDetailRow(Icons.location_on_outlined, l10n.translate('governorate'), 
              '${_governorate?.getName(lang) ?? ""} - ${_job.locationText}'),
          _buildDetailRow(Icons.group_outlined, l10n.translate('workers_needed'), _job.workersNeeded.toString()),
          _buildDetailRow(Icons.payments_outlined, l10n.translate('payment'), 
              _job.isVolunteering ? l10n.translate('volunteering') : '${_job.paymentAmount} ${l10n.translate('jod')} (${l10n.translate(_job.paymentType ?? "")})'),
          
          const SizedBox(height: 16),
          Text(l10n.translate('benefits'), style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (_job.providesTransportation) _buildBenefitChip(l10n.translate('transportation'), Icons.directions_bus_filled_outlined, primaryGreen),
              if (_job.providesFood) _buildBenefitChip(l10n.translate('food'), Icons.restaurant_outlined, primaryGreen),
              if (_job.providesAccommodation) _buildBenefitChip(l10n.translate('accommodation'), Icons.bed_outlined, primaryGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF00C897)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: GoogleFonts.cairo(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide.none,
    );
  }

  Widget _buildEmptyApplicants(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(l10n.translate('no_applicants'), style: GoogleFonts.cairo(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(JobApplicant app, AppLocalizations l10n, Color darkGreen) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: darkGreen.withOpacity(0.1), child: Icon(Icons.person, color: darkGreen)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.fullName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(app.phone, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined, color: Color(0xFF00C897)),
                onPressed: () {}, // Implementation for calling would go here
              ),
            ],
          ),
          if (app.notes != null && app.notes!.isNotEmpty) ...[
            const Divider(),
            Text(l10n.translate('notes'), style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(app.notes!, style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey[800])),
          ],
        ],
      ),
    );
  }
}
