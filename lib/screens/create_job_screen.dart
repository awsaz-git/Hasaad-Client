import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/job.dart';
import '../models/governorate.dart';
import '../services/supabase_service.dart';
import '../utils/app_localizations.dart';

class CreateJobScreen extends StatefulWidget {
  final Job? jobToEdit;
  const CreateJobScreen({super.key, this.jobToEdit});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SupabaseService();
  bool _isLoading = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _workersController = TextEditingController(text: '1');
  final _paymentController = TextEditingController();

  int? _selectedGovId;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isVolunteering = false;
  String _paymentType = 'daily';
  
  bool _transportation = false;
  bool _food = false;
  bool _accommodation = false;

  List<Governorate> _governorates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.jobToEdit != null) {
      final j = widget.jobToEdit!;
      _titleController.text = j.title;
      _descController.text = j.description;
      _locationController.text = j.locationText;
      _workersController.text = j.workersNeeded.toString();
      _selectedGovId = j.governorateId;
      _startDate = j.startDate;
      _endDate = j.endDate;
      
      if (j.startTime.isNotEmpty) {
        final parts = j.startTime.split(':');
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (j.endTime.isNotEmpty) {
        final parts = j.endTime.split(':');
        _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }

      _isVolunteering = j.isVolunteering;
      _paymentType = j.paymentType ?? 'daily';
      _paymentController.text = j.paymentAmount?.toString() ?? '';
      _transportation = j.providesTransportation;
      _food = j.providesFood;
      _accommodation = j.providesAccommodation;
    }
  }

  Future<void> _loadData() async {
    final govs = await _service.getGovernorates();
    setState(() {
      _governorates = govs;
      if (widget.jobToEdit == null && _selectedGovId == null) {
        _service.getProfile(_service.currentUser!.id).then((p) {
          if (p != null && mounted) setState(() => _selectedGovId = p.governorateId);
        });
      }
    });
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return "";
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  String _calculateDuration() {
    if (_startTime == null || _endTime == null) return "";
    int startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    int endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    int diff = endMinutes - startMinutes;
    if (diff <= 0) diff += 24 * 60; // Handle overnight

    int hours = diff ~/ 60;
    int mins = diff % 60;
    
    if (mins == 0) return "$hours ${AppLocalizations.of(context)!.translate('hours')}";
    return "${hours}h ${mins}m";
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('select_date'))));
      return;
    }

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.translate('select_time'))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _service.currentUser;
      final job = Job(
        id: widget.jobToEdit?.id,
        farmerId: user!.id,
        title: _titleController.text,
        description: _descController.text,
        governorateId: _selectedGovId!,
        locationText: _locationController.text,
        startDate: _startDate!,
        endDate: _endDate!,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
        workHours: _calculateDuration(),
        workersNeeded: int.parse(_workersController.text),
        isVolunteering: _isVolunteering,
        paymentAmount: _isVolunteering ? null : double.tryParse(_paymentController.text),
        paymentType: _isVolunteering ? null : _paymentType,
        providesTransportation: _transportation,
        providesFood: _food,
        providesAccommodation: _accommodation,
      );

      if (widget.jobToEdit == null) {
        await _service.createJob(job);
      } else {
        await _service.updateJob(job);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    const darkGreen = Color(0xFF005E4D);
    const primaryGreen = Color(0xFF00C897);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.translate(widget.jobToEdit == null ? 'create_job' : 'edit_job'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: darkGreen)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkGreen),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryGreen))
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(l10n.translate('personal_info'), darkGreen),
                  _buildTextField(_titleController, l10n.translate('job_title'), Icons.title, placeholder: l10n.translate('placeholder_job_title')),
                  const SizedBox(height: 16),
                  _buildTextField(_descController, l10n.translate('job_description'), Icons.description, maxLines: 3, placeholder: l10n.translate('placeholder_job_desc')),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle(l10n.translate('governorate'), darkGreen),
                  _buildDropdown(l10n, lang),
                  const SizedBox(height: 16),
                  _buildTextField(_locationController, l10n.translate('location_details'), Icons.location_on_outlined, placeholder: l10n.translate('placeholder_location')),

                  const SizedBox(height: 32),
                  _buildSectionTitle(l10n.translate('work_details'), darkGreen),
                  _buildDatePicker(l10n, true),
                  const SizedBox(height: 16),
                  _buildDatePicker(l10n, false),
                  const SizedBox(height: 16),
                  _buildTimePicker(l10n, true),
                  const SizedBox(height: 16),
                  _buildTimePicker(l10n, false),
                  const SizedBox(height: 16),
                  _buildTextField(_workersController, l10n.translate('workers_needed'), Icons.group_add_outlined, keyboardType: TextInputType.number, placeholder: l10n.translate('placeholder_workers')),

                  const SizedBox(height: 32),
                  _buildSectionTitle(l10n.translate('benefits'), darkGreen),
                  CheckboxListTile(
                    title: Text(l10n.translate('transportation'), style: GoogleFonts.cairo()),
                    value: _transportation,
                    onChanged: (v) => setState(() => _transportation = v!),
                    activeColor: primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: Text(l10n.translate('food'), style: GoogleFonts.cairo()),
                    value: _food,
                    onChanged: (v) => setState(() => _food = v!),
                    activeColor: primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: Text(l10n.translate('accommodation'), style: GoogleFonts.cairo()),
                    value: _accommodation,
                    onChanged: (v) => setState(() => _accommodation = v!),
                    activeColor: primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle(l10n.translate('payment'), darkGreen),
                  SwitchListTile(
                    title: Text(l10n.translate('volunteering'), style: GoogleFonts.cairo()),
                    value: _isVolunteering,
                    onChanged: (v) => setState(() => _isVolunteering = v),
                    activeColor: primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!_isVolunteering) ...[
                    const SizedBox(height: 16),
                    _buildTextField(_paymentController, l10n.translate('payment_amount'), Icons.money, keyboardType: TextInputType.number, placeholder: l10n.translate('placeholder_payment')),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _paymentType,
                      decoration: _inputDecoration(l10n.translate('payment_type'), Icons.merge_type),
                      items: ['daily', 'hourly', 'total'].map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(l10n.translate(type), style: GoogleFonts.cairo()),
                      )).toList(),
                      onChanged: (v) => setState(() => _paymentType = v!),
                    ),
                  ],

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text(
                        l10n.translate('submit'),
                        style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? placeholder}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(),
      decoration: _inputDecoration(label, icon, hint: placeholder),
      validator: (v) => v == null || v.isEmpty ? AppLocalizations.of(context)!.translate('required_field') : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.cairo(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF005E4D)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF00C897))),
      labelStyle: GoogleFonts.cairo(color: Colors.grey),
    );
  }

  Widget _buildDropdown(AppLocalizations l10n, String lang) {
    return DropdownButtonFormField<int>(
      value: _selectedGovId,
      decoration: _inputDecoration(l10n.translate('select_governorate'), Icons.map_outlined),
      items: _governorates.map((gov) => DropdownMenuItem(
        value: gov.id,
        child: Text(gov.getName(lang), style: GoogleFonts.cairo()),
      )).toList(),
      onChanged: (v) => setState(() => _selectedGovId = v),
      validator: (v) => v == null ? l10n.translate('required_field') : null,
    );
  }

  Widget _buildDatePicker(AppLocalizations l10n, bool isStart) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) setState(() => isStart ? _startDate = date : _endDate = date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: const Color(0xFF005E4D), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.translate(isStart ? 'start_date' : 'end_date'), style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                  Text(
                    (isStart ? _startDate : _endDate) == null 
                      ? l10n.translate('select_date') 
                      : DateFormat('yyyy-MM-dd').format(isStart ? _startDate! : _endDate!),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(AppLocalizations l10n, bool isStart) {
    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null) setState(() => isStart ? _startTime = time : _endTime = time);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: const Color(0xFF005E4D), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.translate(isStart ? 'start_time' : 'end_time'), style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                  Text(
                    (isStart ? _startTime : _endTime) == null 
                      ? l10n.translate('select_time') 
                      : (isStart ? _startTime! : _endTime!).format(context),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
