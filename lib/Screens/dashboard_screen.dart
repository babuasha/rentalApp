import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rentalapp/Screens/FilteredApartmentsScreen.dart';
import 'package:rentalapp/Screens/countries_screen.dart';
import 'package:rentalapp/helper/currency_helper.dart';
import 'package:rentalapp/Screens/login_screen.dart'; 


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = 'Loading...';

  // Instantiate the Helper class
  final CurrencyHelper _currencyHelper = CurrencyHelper();
  bool _isLoadingRates = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _initExchangeRates();
  }

  // Load rates via CurrencyHelper
  Future<void> _initExchangeRates() async {
    await _currencyHelper.fetchExchangeRates();
    if (mounted) {
      setState(() {
        _isLoadingRates = false;
      });
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _userName = doc.data()!['fullName'] ?? 'User';
        });
      }
    }
  }

  // Parse Timestamp or String into DateTime
  DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is Timestamp) return dateValue.toDate();
    if (dateValue is String) {
      try {
        return DateFormat('d- MMM- yy').parse(dateValue);
      } catch (_) {
        try {
          return DateFormat('dd/MM/yyyy').parse(dateValue);
        } catch (_) {
          try {
            return DateTime.parse(dateValue);
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  // Format date cleanly into dd/MM/yyyy
  String _formatDate(dynamic dateValue) {
    final DateTime? dt = _parseDateTime(dateValue);
    if (dt != null) {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
    return dateValue?.toString() ?? 'N/A';
  }

  // Check if date falls within the next 90 days from today
  bool _isExpiringWithin90Days(dynamic dateValue) {
    final DateTime? toDate = _parseDateTime(dateValue);
    if (toDate == null) return false;

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime checkDate = DateTime(toDate.year, toDate.month, toDate.day);

    // 90 days from today
    final DateTime ninetyDaysLater = today.add(const Duration(days: 90));

    // True if expiry date is on/after today and on/before 90 days later
    return (checkDate.isAfter(today) || checkDate.isAtSameMomentAs(today)) &&
        (checkDate.isBefore(ninetyDaysLater) || checkDate.isAtSameMomentAs(ninetyDaysLater));
  }

  // Helper to generate list of last 13 months
  List<DateTime> _getLast12MonthsList() {
    final DateTime now = DateTime.now();
    List<DateTime> months = [];
    for (int i = 12; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return months;
  }

  // Check if a target month overlaps with [fromDate, toDate] range for Rent Estimation
  bool _isApartmentRentedInMonth(dynamic fromVal, dynamic toVal, DateTime monthStart) {
    final DateTime? fromDate = _parseDateTime(fromVal);
    final DateTime? toDate = _parseDateTime(toVal);

    if (fromDate == null) return false;

    final DateTime mStart = DateTime(monthStart.year, monthStart.month, 1);
    final DateTime mEnd = DateTime(monthStart.year, monthStart.month + 1, 0, 23, 59, 59);

    final DateTime effectiveTo = toDate ?? DateTime(2099, 12, 31);

    return (fromDate.isBefore(mEnd) || fromDate.isAtSameMomentAs(mEnd)) &&
        (effectiveTo.isAfter(mStart) || effectiveTo.isAtSameMomentAs(mStart));
  }

  // Calculate rent collection multiplier based on payment type schedule
  double _getRentCollectionAmount(
      dynamic fromVal, dynamic toVal, dynamic paymentTypeVal, double monthlyPrice, DateTime targetMonth) {
    final DateTime? fromDate = _parseDateTime(fromVal);
    final DateTime? toDate = _parseDateTime(toVal);

    if (fromDate == null) return 0.0;

    final DateTime effectiveTo = toDate ?? DateTime(2099, 12, 31);

    final DateTime targetMonthStart = DateTime(targetMonth.year, targetMonth.month, 1);
    final DateTime leaseStartMonth = DateTime(fromDate.year, fromDate.month, 1);
    final DateTime leaseEndMonth = DateTime(effectiveTo.year, effectiveTo.month, 1);

    if (targetMonthStart.isBefore(leaseStartMonth) || targetMonthStart.isAfter(leaseEndMonth)) {
      return 0.0;
    }

    final String pType = (paymentTypeVal ?? 'monthly').toString().toLowerCase();
    int intervalMonths = 1;

    if (pType.contains('year')) {
      intervalMonths = 12;
    } else if (pType.contains('3 month') || pType.contains('quarter')) {
      intervalMonths = 3;
    } else if (pType.contains('2 month')) {
      intervalMonths = 2;
    } else if (pType.contains('6 month') || pType.contains('half')) {
      intervalMonths = 6;
    } else {
      intervalMonths = 1;
    }

    int monthDifference =
        (targetMonthStart.year - leaseStartMonth.year) * 12 + (targetMonthStart.month - leaseStartMonth.month);

    if (monthDifference >= 0 && monthDifference % intervalMonths == 0) {
      return monthlyPrice * intervalMonths;
    }

    return 0.0;
  }

  // Show Dialog listing all expiring apartment agreements within 90 days
  void _showExpiringDialog(
      BuildContext context, List<QueryDocumentSnapshot> expiringDocs) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Expiring Agreements (90 Days)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: expiringDocs.isEmpty
              ? const Text('No agreements are expiring within the next 90 days.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: expiringDocs.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final data =
                          expiringDocs[index].data() as Map<String, dynamic>;
                      final title = data['title'] ?? 'Apartment';
                      final bhk = data['bhk'] ?? '';
                      final formattedToDate = _formatDate(data['toDate']);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFEBEE),
                          child: Icon(Icons.apartment, color: Colors.red),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '$bhk\nAgreement expiring on $formattedToDate.'),
                        isThreeLine: true,
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> last12Months = _getLast12MonthsList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: AppDrawer(userName: _userName), 
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('apartments')
              .snapshots(),
          builder: (context, snapshot) {
            int totalApartments = 0;
            int rentedCount = 0;
            int availableCount = 0;
            int ownUseCount = 0;
            int underConstructionCount = 0;

            List<QueryDocumentSnapshot> expiringDocs = [];

            Map<String, Map<String, double>> countryMonthlyEstimatedRent = {};
            Map<String, Map<String, double>> countryMonthlyCollectedRent = {};
            
            Map<String, double> countryTotalServiceCharge = {};

            if (snapshot.hasData) {
              final docs = snapshot.data!.docs;
              totalApartments = docs.length;

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final String country = (data['country'] ??
                        data['countryName'] ??
                        data['countryCode'] ??
                        'General')
                    .toString();

                countryMonthlyEstimatedRent.putIfAbsent(country, () => {});
                countryMonthlyCollectedRent.putIfAbsent(country, () => {});
                countryTotalServiceCharge.putIfAbsent(country, () => 0.0);
              }

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? 'Available')
                    .toString()
                    .toLowerCase();

                if (status == 'rented') {
                  rentedCount++;
                } else if (status == 'ownuse') {
                  ownUseCount++;
                } else if (status == 'under construction' || status == 'underconstruction') {
                  underConstructionCount++;
                } else {
                  availableCount++;
                }

                if (_isExpiringWithin90Days(data['toDate'])) {
                  expiringDocs.add(doc);
                }

                final String country = (data['country'] ??
                        data['countryName'] ??
                        data['countryCode'] ??
                        'General')
                    .toString();

                final double rawPrice =
                    double.tryParse((data['price'] ?? 0).toString()) ?? 0.0;
                final double rawServiceCharge =
                    double.tryParse((data['serviceCharge'] ?? 0).toString()) ?? 0.0;

                final double priceInOMR =
                    _currencyHelper.convertToOMR(rawPrice, country);
                final double serviceChargeInOMR =
                    _currencyHelper.convertToOMR(rawServiceCharge, country);

                countryTotalServiceCharge[country] =
                    (countryTotalServiceCharge[country] ?? 0.0) + serviceChargeInOMR;

                final dynamic paymentType =
                    data['paymentType'] ?? data['paymentFrequency'];

                for (var monthStart in last12Months) {
                  final String monthKey =
                      DateFormat('MMM yyyy').format(monthStart);

                  if (_isApartmentRentedInMonth(
                      data['fromDate'], data['toDate'], monthStart)) {
                    countryMonthlyEstimatedRent[country]![monthKey] =
                        (countryMonthlyEstimatedRent[country]![monthKey] ?? 0.0) +
                            priceInOMR;
                  }

                  final double collectedAmount = _getRentCollectionAmount(
                      data['fromDate'], data['toDate'], paymentType, priceInOMR, monthStart);

                  if (collectedAmount > 0) {
                    countryMonthlyCollectedRent[country]![monthKey] =
                        (countryMonthlyCollectedRent[country]![monthKey] ?? 0.0) +
                            collectedAmount;
                  }
                }
              }
            }

            List<String> sortedCountries = countryMonthlyEstimatedRent.keys.toList();
            sortedCountries.sort((a, b) {
              final isAOman = a.toUpperCase().contains('OMAN');
              final isBOman = b.toUpperCase().contains('OMAN');
              if (isAOman && !isBOman) return -1;
              if (!isAOman && isBOman) return 1;
              return a.compareTo(b);
            });

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              return IconButton(
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                icon: const Icon(Icons.menu, size: 30, color: Colors.black),
                                onPressed: () {
                                  Scaffold.of(context).openDrawer();
                                },
                              );
                            }
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $_userName 👋',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Property Overview',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none_outlined,
                              size: 28,
                            ),
                            onPressed: () =>
                                _showExpiringDialog(context, expiringDocs),
                          ),
                          if (expiringDocs.isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '${expiringDocs.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CountriesScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.apartment,
                              size: 32,
                              color: Color(0xFF0D6338),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Properties',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Manage accounts by country',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stat Cards (Row 1: Total, Rented, Available) with Navigations
                  Row(
                    children: [
                      _buildStatCard(
                        '$totalApartments',
                        'Total\nApartments',
                        const Color(0xFF2E7D32),
                        onTap: () => _navigateToFilteredList(context, 'all', 'Total Apartments'),
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        '$rentedCount',
                        'Rented\n',
                        const Color(0xFF0288D1),
                        onTap: () => _navigateToFilteredList(context, 'rented', 'Rented'),
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        '$availableCount',
                        'Available\n',
                        const Color(0xFF8E24AA),
                        onTap: () => _navigateToFilteredList(context, 'available', 'Available'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stat Cards (Row 2: Own Use, Under Construction) with Navigations
                  Row(
                    children: [
                      _buildStatCard(
                        '$ownUseCount',
                        'Own Use\n',
                        Colors.blue.shade700,
                        onTap: () => _navigateToFilteredList(context, 'ownuse', 'Own Use'),
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        '$underConstructionCount',
                        'Under\nConstruction',
                        Colors.orange.shade800,
                        onTap: () => _navigateToFilteredList(context, 'under construction', 'Under Construction'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- 1. MONTHLY RENTAL INCOME GRAPH ---
                  if (sortedCountries.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'MONTHLY RENTAL INCOME\nNo apartment data available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 290,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: sortedCountries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final country = sortedCountries[index];
                          final monthDataMap =
                              countryMonthlyEstimatedRent[country]!;

                          double maxRent = 1.0;
                          for (var month in last12Months) {
                            final mKey = DateFormat('MMM yyyy').format(month);
                            final val = monthDataMap[mKey] ?? 0.0;
                            if (val > maxRent) maxRent = val;
                          }

                          return Container(
                            width: MediaQuery.of(context).size.width - 40,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MONTHLY RENTAL INCOME ($country) - OMR',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: last12Months.map((month) {
                                        final mKey = DateFormat('MMM yyyy')
                                            .format(month);
                                        final mLabel =
                                            DateFormat('MMM').format(month);
                                        final yLabel =
                                            DateFormat('yyyy').format(month);
                                        final rentAmount =
                                            monthDataMap[mKey] ?? 0.0;

                                        final double barHeight = (rentAmount /
                                                maxRent) *
                                            110;

                                        return _buildDynamicBar(
                                          rentAmount > 0
                                              ? NumberFormat.compact()
                                                  .format(rentAmount)
                                              : '0',
                                          barHeight < 8 && rentAmount > 0
                                              ? 8
                                              : barHeight,
                                          const Color(0xFF0D6338),
                                          mLabel,
                                          yLabel,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  // --- 2. SERVICE CHARGE MONTHLY PAYMENT ---
                  if (sortedCountries.isEmpty)
                    const SizedBox.shrink()
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SERVICE CHARGE MONTHLY PAYMENT - OMR',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 210,
                            child: Builder(
                              builder: (context) {
                                double maxServiceCharge = 1.0;
                                for (var country in sortedCountries) {
                                  final val = countryTotalServiceCharge[country] ?? 0.0;
                                  if (val > maxServiceCharge) maxServiceCharge = val;
                                }

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: sortedCountries.map((country) {
                                      final scAmount = countryTotalServiceCharge[country] ?? 0.0;
                                      final double barHeight = (scAmount / maxServiceCharge) * 110;

                                      return Container(
                                        width: 65,
                                        margin: const EdgeInsets.symmetric(horizontal: 3.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              scAmount > 0
                                                  ? NumberFormat.compact().format(scAmount)
                                                  : '0',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              width: 22,
                                              height: barHeight <= 0 ? 4 : barHeight,
                                              decoration: BoxDecoration(
                                                color: barHeight <= 0
                                                    ? Colors.grey.shade300
                                                    : const Color(0xFF6A1B9A),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              height: 32,
                                              child: Text(
                                                country,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // --- 3. MONTHLY RENT COLLECTION GRAPH ---
                  if (sortedCountries.isEmpty)
                    const SizedBox.shrink()
                  else
                    SizedBox(
                      height: 290,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: sortedCountries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final country = sortedCountries[index];
                          final monthDataMap =
                              countryMonthlyCollectedRent[country] ?? {};

                          double maxRent = 1.0;
                          for (var month in last12Months) {
                            final mKey = DateFormat('MMM yyyy').format(month);
                            final val = monthDataMap[mKey] ?? 0.0;
                            if (val > maxRent) maxRent = val;
                          }

                          return Container(
                            width: MediaQuery.of(context).size.width - 40,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MONTHLY RENT COLLECTION ($country) - OMR',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: last12Months.map((month) {
                                        final mKey = DateFormat('MMM yyyy')
                                            .format(month);
                                        final mLabel =
                                            DateFormat('MMM').format(month);
                                        final yLabel =
                                            DateFormat('yyyy').format(month);
                                        final rentAmount =
                                            monthDataMap[mKey] ?? 0.0;

                                        final double barHeight = (rentAmount /
                                                maxRent) *
                                            110;

                                        return _buildDynamicBar(
                                          rentAmount > 0
                                              ? NumberFormat.compact()
                                                  .format(rentAmount)
                                              : '0',
                                          barHeight < 8 && rentAmount > 0
                                              ? 8
                                              : barHeight,
                                          const Color(0xFF1565C0),
                                          mLabel,
                                          yLabel,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text(
              'Powered by A3S Apps',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFilteredList(BuildContext context, String filterType, String headingTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilteredApartmentsScreen(
          filterType: filterType,
          headingTitle: headingTitle,
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String title, Color color, {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(20),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicBar(
      String amount, double height, Color color, String monthLabel, String yearLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            amount,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 20,
            height: height <= 0 ? 4 : height,
            decoration: BoxDecoration(
              color: height <= 0 ? Colors.grey.shade300 : color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            monthLabel,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          Text(
            yearLabel,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// --- APP DRAWER CLASS ---
class AppDrawer extends StatelessWidget {
  final String userName;

  const AppDrawer({super.key, required this.userName});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, left: 24, bottom: 30),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0D6338),
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Color(0xFF0D6338)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Property Management',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          _buildDrawerItem(
            icon: Icons.dashboard_rounded,
            title: 'Dashboard',
            onTap: () => Navigator.pop(context),
            isSelected: true,
          ),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
            },
          ),
          
          const Spacer(),
          const Divider(indent: 24, endIndent: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: Colors.red.shade50,
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.red, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: isSelected ? const Color(0xFF0D6338).withOpacity(0.1) : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF0D6338) : Colors.black87,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF0D6338) : Colors.black87,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}