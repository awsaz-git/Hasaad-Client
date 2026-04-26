import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/job.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';
import 'create_job_screen.dart';
import 'job_details_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _service = SupabaseService();
  bool _isLoading = true;
  List<Job> _jobs = [];

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    try {
      final user = _service.currentUser;
      if (user != null) {
        final jobs = await _service.getMyJobs(user.id);
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : RefreshIndicator(
              onRefresh: _fetchJobs,
              child: _jobs.isEmpty
                  ? _buildEmptyState(l10n, darkGreen)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: _jobs.length,
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        return _buildJobCard(job, l10n, darkGreen, primaryGreen);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateJobScreen()),
          );
          if (result == true) _fetchJobs();
        },
        backgroundColor: darkGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          l10n.translate('create_job'),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 80, color: color.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            l10n.translate('no_jobs'),
            style: GoogleFonts.cairo(fontSize: 18, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Job job, AppLocalizations l10n, Color darkGreen, Color primaryGreen) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)),
        );
        if (result == true) _fetchJobs();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: job.isActive ? primaryGreen.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.translate(job.isActive ? 'active' : 'closed'),
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: job.isActive ? primaryGreen : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoTag(
                  job.isVolunteering 
                      ? l10n.translate('volunteering') 
                      : '${job.paymentAmount} ${l10n.translate('jod')} / ${l10n.translate(job.paymentType ?? "")}',
                  Icons.payments_outlined,
                ),
                const SizedBox(width: 12),
                _buildInfoTag(
                  '${job.applicantCount} ${l10n.translate('applicants')}',
                  Icons.people_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
