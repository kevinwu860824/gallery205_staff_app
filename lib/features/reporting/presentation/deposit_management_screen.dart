// lib/features/reporting/presentation/deposit_management_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gallery205_staff_app/l10n/app_localizations.dart';

InputDecoration _buildInputDecoration(BuildContext context, {String hintText = '', Widget? prefixIcon}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: theme.cardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    prefixIcon: prefixIcon,
  );
}

// -------------------------------------------------------------------
// 2. DepositManagementScreen (主頁面)
// -------------------------------------------------------------------

class DepositManagementScreen extends StatefulWidget {
  const DepositManagementScreen({super.key});

  @override
  State<DepositManagementScreen> createState() => _DepositManagementScreenState();
}

class _DepositManagementScreenState extends State<DepositManagementScreen> {
  String? _shopId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _deposits = [];

  @override
  void initState() {
    super.initState();
    _fetchDeposits();
  }

  Future<void> _fetchDeposits() async {
    final prefs = await SharedPreferences.getInstance();
    _shopId = prefs.getString('savedShopId');
    if (_shopId == null) {
      if (mounted) context.go('/');
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('deposits')
          .select('*')
          .eq('shop_id', _shopId!)
          .filter('transaction_id', 'is', null) 
          .order('booking_date', ascending: true); 
      
      setState(() {
        _deposits = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddOrEditDepositDialog({Map<String, dynamic>? depositData}) async {
    final l10n = AppLocalizations.of(context)!;
    bool isEdit = depositData != null;
    
    final amountController = TextEditingController(text: isEdit ? (depositData!['amount'] as num).toStringAsFixed(0) : '');
    final nameController = TextEditingController(text: isEdit ? depositData!['guest_name'] : '');
    final paxController = TextEditingController(text: isEdit ? (depositData!['guest_pax'] ?? 1).toString() : '');
    
    DateTime? bookingDate = isEdit && depositData!['booking_date'] != null 
        ? DateTime.parse(depositData['booking_date']) 
        : null; 

    TimeOfDay? bookingTime = isEdit && depositData!['booking_time'] != null
        ? TimeOfDay(hour: int.parse(depositData['booking_time'].split(':')[0]), minute: int.parse(depositData['booking_time'].split(':')[1]))
        : null; 

    DateTime? receivedDate = isEdit && depositData!['received_date'] != null 
        ? DateTime.parse(depositData['received_date']) 
        : null; 

    final now = DateTime.now();
    final todayAtMidnight = DateTime(now.year, now.month, now.day);

    await showDialog( 
      context: context,
      builder: (dialogContext) => _AddEditDepositFigmaDialog(
        isEdit: isEdit,
        amountController: amountController,
        nameController: nameController,
        paxController: paxController,
        initialBookingDate: bookingDate,
        initialBookingTime: bookingTime,
        initialReceivedDate: receivedDate,
        todayAtMidnight: todayAtMidnight,
        shopId: _shopId!,
        depositId: depositData?['id'],
        onDelete: _deleteDeposit,
        onSave: (dataToSave) async {
          try {
            if (isEdit) {
              await Supabase.instance.client.from('deposits').update(dataToSave).eq('id', depositData!['id']);
            } else {
              await Supabase.instance.client.from('deposits').insert(dataToSave);
            }
            
            Navigator.of(dialogContext).pop(); 
            _fetchDeposits(); 
          } catch (e) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.depositScreenSaveFailed(e.toString())))); 
          }
        },
      ),
    );
  }

  Future<void> _deleteDeposit(String id) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Supabase.instance.client
          .from('deposits')
          .delete()
          .eq('id', id);
      
      _fetchDeposits(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.depositScreenDeleteSuccess)), 
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.depositScreenDeleteFailed(e.toString()))), 
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: CupertinoNavigationBar(middle: Text(l10n.depositScreenTitle)), 
        body: Center(child: CupertinoActivityIndicator(color: colorScheme.onSurface)),
      );
    }

    final currencyFormat = NumberFormat('#,###', 'zh_TW');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        middle: Text(l10n.depositScreenTitle, style: TextStyle(color: colorScheme.onSurface)), 
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.add, color: colorScheme.onSurface),
          onPressed: () => _showAddOrEditDepositDialog(), 
        ),
      ),
      body: SafeArea(
        child: _deposits.isEmpty
            ? Center(child: Text(l10n.depositScreenNoRecords, style: TextStyle(color: colorScheme.onSurface))) 
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                itemCount: _deposits.length,
                itemBuilder: (context, index) {
                  final deposit = _deposits[index];
                  final bookingDate = DateTime.tryParse(deposit['booking_date'] ?? '');
                  final bookingTime = deposit['booking_time']?.substring(0, 5) ?? 'N/A';
                  final amount = (deposit['amount'] as num? ?? 0.0);
                  final pax = deposit['guest_pax'] ?? 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n.depositScreenLabelName(deposit['guest_name'] ?? 'No Name'), 
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                                ),
                                Text(
                                  '\$${currencyFormat.format(amount)}',
                                  style: TextStyle(fontSize: 16, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.depositScreenLabelReservationDate(bookingDate != null ? DateFormat('yyyy/MM/dd').format(bookingDate) : 'N/A'), 
                              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                            ),
                            Text(
                              l10n.depositScreenLabelReservationTime(bookingTime), 
                              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                            ),
                            Text(
                              l10n.depositScreenLabelGroupSize(pax.toString()), 
                              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                            ),
                            
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  onPressed: () => _showAddOrEditDepositDialog(depositData: deposit),
                                  child: Icon(CupertinoIcons.pencil, size: 22, color: colorScheme.onSurface),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  onPressed: () async {
                                    final confirmed = await _showDeleteConfirmationDialog(context);
                                    if (confirmed == true && deposit['id'] != null) {
                                        _deleteDeposit(deposit['id']);
                                    }
                                  },
                                  child: Icon(CupertinoIcons.delete, size: 22, color: colorScheme.onSurface),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}


// -------------------------------------------------------------------
// 3. 輔助 Widget (Figma 樣式 Dialogs)
// -------------------------------------------------------------------

class _CustomDialogBase extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Widget? bottomContent;
  final bool isScrollable;

  const _CustomDialogBase({
    required this.title,
    required this.content,
    required this.actions,
    this.bottomContent,
    this.isScrollable = false, 
  });

  @override
  Widget build(BuildContext context) {
    const double dialogWidth = 361.0; 
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final contentWidget = isScrollable
      ? Flexible(
          child: SingleChildScrollView(
            child: content,
          ),
        )
      : content;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
              mainAxisSize: isScrollable ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                contentWidget, 
                if (bottomContent != null) ...[
                  const SizedBox(height: 16),
                  bottomContent!,
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: actions,
                ),
              ],
            ),
      ),
    );
  }
}

class _DialogWhiteButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? child; 
  final bool isDestructive;

  const _DialogWhiteButton({required this.text, this.onPressed, this.child, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 109.6,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? colorScheme.error : colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          padding: EdgeInsets.zero,
        ),
        child: child ?? Text(
          text,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TextCancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color? color;
  const _TextCancelButton({required this.onPressed, this.text = 'Cancel', this.color}); 

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayText = text == 'Cancel' ? l10n.commonCancel : text;
    
    return TextButton(
      onPressed: onPressed,
      child: Text(
        displayText,
        style: TextStyle(
          color: color ?? colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _WhiteDropdown extends StatelessWidget {
  final String? value;
  final VoidCallback? onTap; 
  final String? hint;
  final IconData icon;

  const _WhiteDropdown({
    required this.value, 
    this.onTap,
    this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 54, 
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: CupertinoButton( 
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        onPressed: onTap, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.onSurface, size: 22),
                const SizedBox(width: 8),
                Text(
                  value ?? hint ?? '',
                  style: TextStyle(
                    color: value != null ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 16, 
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
             Icon(CupertinoIcons.chevron_down, color: colorScheme.onSurface, size: 20),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _showDeleteConfirmationDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return await showDialog<bool>(
    context: context,
    builder: (_) => _CustomDialogBase(
      title: l10n.depositScreenDeleteConfirm, 
      content: Text(
        l10n.depositScreenDeleteContent, 
        textAlign: TextAlign.center,
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      actions: [
        _TextCancelButton(onPressed: () => Navigator.of(context).pop(false)),
        _DialogWhiteButton(text: l10n.commonDelete, onPressed: () => Navigator.of(context).pop(true), isDestructive: true), 
      ],
    ),
  );
}

class _AddEditDepositFigmaDialog extends StatefulWidget {
  final bool isEdit;
  final TextEditingController amountController;
  final TextEditingController nameController;
  final TextEditingController paxController;
  final Function(Map<String, dynamic>) onSave;
  final String? depositId;
  final Function(String) onDelete;
  final String shopId;

  final DateTime? initialBookingDate; 
  final TimeOfDay? initialBookingTime; 
  final DateTime? initialReceivedDate; 
  final DateTime todayAtMidnight;

  const _AddEditDepositFigmaDialog({
    required this.isEdit, 
    required this.amountController, 
    required this.nameController,
    required this.paxController, 
    required this.initialBookingDate, 
    required this.initialBookingTime,
    required this.initialReceivedDate, 
    required this.todayAtMidnight, 
    required this.onSave,
    required this.depositId,
    required this.onDelete,
    required this.shopId,
  });

  @override
  State<_AddEditDepositFigmaDialog> createState() => _AddEditDepositFigmaDialogState();
}

class _AddEditDepositFigmaDialogState extends State<_AddEditDepositFigmaDialog> {
  late DateTime? receivedDate; 
  late DateTime? bookingDate; 
  late TimeOfDay? bookingTime; 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    receivedDate = widget.initialReceivedDate;
    bookingDate = widget.initialBookingDate;
    bookingTime = widget.initialBookingTime;
  }
  
  Future<void> _selectDate(BuildContext context, DateTime? initial, ValueChanged<DateTime> onSelected, {DateTime? minDate}) async {
    final initialDateToUse = initial ?? DateTime.now();
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDateToUse,
      firstDate: minDate ?? DateTime(DateTime.now().year - 1), 
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked != null) {
      if (mounted) setState(() => onSelected(picked));
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: bookingTime ?? TimeOfDay.now(), 
    );
    if (picked != null) {
      if (mounted) setState(() => bookingTime = picked);
    }
  }

  void _onSavePressed() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSaving) return;
    
    final amount = double.tryParse(widget.amountController.text.trim());
    
    if (amount == null || amount <= 0 || widget.nameController.text.trim().isEmpty || 
        receivedDate == null || bookingDate == null || bookingTime == null) {
        _showLocalNotice(l10n.depositScreenInputError); 
        return;
    }
    
    final pax = int.tryParse(widget.paxController.text.trim()) ?? 1;

    final selectedBookingDateTime = DateTime(
      bookingDate!.year, bookingDate!.month, bookingDate!.day,
      bookingTime!.hour, bookingTime!.minute
    );
    
    if (selectedBookingDateTime.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))) {
       _showLocalNotice(l10n.depositScreenTimeError); 
      return;
    }
    
    if (mounted) setState(() => _isSaving = true);
    
    final dataToSave = {
      'shop_id': widget.shopId,
      'received_date': DateFormat('yyyy-MM-dd').format(receivedDate!),
      'booking_date': DateFormat('yyyy-MM-dd').format(bookingDate!),
      'booking_time': '${bookingTime!.hour.toString().padLeft(2, '0')}:${bookingTime!.minute.toString().padLeft(2, '0')}',
      'guest_name': widget.nameController.text.trim(),
      'guest_pax': pax,
      'amount': amount,
    };
    
    widget.onSave(dataToSave);
  }
  
  void _showLocalNotice(String message) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
      );
     }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _CustomDialogBase(
      title: widget.isEdit ? l10n.depositDialogTitleEdit : l10n.depositDialogTitleAdd, 
      isScrollable: true,
      content: Column(
        children: [
          _WhiteDropdown( 
              value: receivedDate == null ? null : DateFormat('yyyy/MM/dd').format(receivedDate!),
              hint: l10n.depositDialogHintPaymentDate, 
              icon: CupertinoIcons.calendar,
              onTap: () => _selectDate(context, receivedDate, (date) => receivedDate = date),
            ),
            const SizedBox(height: 12),
            
            _WhiteDropdown( 
              value: bookingDate == null ? null : DateFormat('yyyy/MM/dd').format(bookingDate!),
              hint: l10n.depositDialogHintReservationDate, 
              icon: CupertinoIcons.calendar,
              onTap: () => _selectDate(
                context, 
                bookingDate, 
                (date) => bookingDate = date,
                minDate: widget.todayAtMidnight, 
              ),
            ),
            const SizedBox(height: 12),
            
             _WhiteDropdown( 
              value: bookingTime == null ? null : bookingTime!.format(context),
              hint: l10n.depositDialogHintReservationTime, 
              icon: CupertinoIcons.clock,
              onTap: () => _selectTime(context),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              height: 54,
              child: TextFormField(
                controller: widget.nameController,
                decoration: _buildInputDecoration(context, hintText: l10n.depositDialogHintName),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                textAlignVertical: TextAlignVertical.center,
              ),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              height: 54,
              child: TextFormField(
                controller: widget.paxController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(context, hintText: l10n.depositDialogHintGroupSize),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                textAlignVertical: TextAlignVertical.center,
              ),
            ),
            const SizedBox(height: 12),
            
            SizedBox(
              height: 54,
              child: TextFormField(
                controller: widget.amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _buildInputDecoration(context, hintText: l10n.depositDialogHintAmount),
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
                textAlignVertical: TextAlignVertical.center,
              ),
            ),
        ],
      ),
      actions: [
        _TextCancelButton(text: l10n.commonCancel, onPressed: () => Navigator.of(context).pop()), 
        
        _DialogWhiteButton(
          text: l10n.commonSave, 
          onPressed: _isSaving ? null : _onSavePressed,
          child: _isSaving ? CupertinoActivityIndicator(color: colorScheme.onPrimary) : null,
        ),
      ],
    );
  }
}