import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/workout_item.dart';
import '../providers/user_provider.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';

class DottedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  const DottedLinePainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashLength = 4.0,
    this.gapLength = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashLength, size.height / 2),
        paint,
      );
      startX += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant DottedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'All';
  int _selectedDayIndex = -1; // -1 means defaults to current day

  static const List<String> _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const List<double> _baseCalories = [320.0, 480.0, 560.0, 410.0, 620.0, 510.0, 390.0];

  int _getTodayDayIndex() {
    // DateTime.weekday: 1=Mon, 2=Tue, ..., 7=Sun
    final weekday = DateTime.now().weekday;
    return weekday == 7 ? 0 : weekday; // 0=Sun, 1=Mon, ..., 6=Sat
  }

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = _getTodayDayIndex();
  }

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(workoutListProvider);
    final userProfile = ref.watch(userProfileProvider);

    final filteredWorkouts = _selectedCategory == 'All'
        ? workouts
        : workouts.where((w) => w.category == _selectedCategory).toList();

    // Summary calculations
    final todayLiveCalories = workouts.fold<double>(
      0.0,
      (sum, item) => sum + item.calculatedCalories,
    );
    final totalSets = workouts.fold<int>(
      0,
      (sum, item) => sum + item.targetSets,
    );
    final completedSets = workouts.fold<int>(
      0,
      (sum, item) => sum + item.completedSets,
    );

    final todayIndex = _getTodayDayIndex();

    // Compute weekly calories array: past days + today's live workouts; future days are 0.0
    final List<double> weeklyData = List.generate(7, (i) {
      if (i < todayIndex) {
        return _baseCalories[i];
      } else if (i == todayIndex) {
        return _baseCalories[i] + todayLiveCalories;
      } else {
        return 0.0; // Future days after today
      }
    });

    final double totalWeeklyBurn = weeklyData.take(todayIndex + 1).fold(0.0, (a, b) => a + b);
    final double maxCalorie = weeklyData.reduce((a, b) => a > b ? a : b).clamp(600.0, 2000.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting (Name only, no age/roll number)
                  Text(
                    userProfile.name.isNotEmpty
                        ? 'Hey, ${userProfile.name} 👋'
                        : 'Hey, Athlete 👋',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Let's crush today's fitness goals & log your sets",
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Weekly Calories Burn Bar Graph Component with Y-axis and Dotted Line
                  _buildWeeklyCalorieGraph(
                    weeklyData: weeklyData,
                    maxCalorie: maxCalorie,
                    todayIndex: todayIndex,
                    totalWeeklyBurn: totalWeeklyBurn,
                  ),

                  const SizedBox(height: 18),

                  // Metric Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppTheme.primary,
                          label: "Today's Burn",
                          value: '${(todayLiveCalories + _baseCalories[todayIndex]).toInt()} kcal',
                          sublabel: 'Active + base load',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.checklist_rounded,
                          iconColor: AppTheme.primary,
                          label: 'Sets Progress',
                          value: '$completedSets / $totalSets',
                          sublabel: '${workouts.length} exercises logged',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Section Header: Workout Logs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Workout Entries',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${filteredWorkouts.length} logged',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Category Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        'Chest',
                        'Back',
                        'Legs',
                        'Shoulders',
                        'Arms',
                        'Core',
                        'Cardio',
                      ].map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            },
                            selectedColor: AppTheme.primary,
                            checkmarkColor: const Color(0xFF000000),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF000000)
                                  : AppTheme.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                            backgroundColor: AppTheme.surfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primary : AppTheme.border,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Workout Items List
          if (filteredWorkouts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fitness_center_outlined,
                      size: 56,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No workout entries found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/add'),
                      icon: const Icon(Icons.add),
                      label: const Text('Log First Exercise'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filteredWorkouts[index];
                    return _buildWorkoutCard(context, item);
                  },
                  childCount: filteredWorkouts.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color(0xFF000000),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Log Workout',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  // Weekly Calorie Burn Bar Graph Component with Y-axis & Dotted lines
  Widget _buildWeeklyCalorieGraph({
    required List<double> weeklyData,
    required double maxCalorie,
    required int todayIndex,
    required double totalWeeklyBurn,
  }) {
    final currentSelected = (_selectedDayIndex >= 0 && _selectedDayIndex < 7)
        ? _selectedDayIndex
        : todayIndex;
    final selectedCal = weeklyData[currentSelected];
    final selectedDayName = _days[currentSelected];
    final isFutureSelected = currentSelected > todayIndex;

    // Calculate Y-axis top ceiling and steps (e.g. 1000, 750, 500, 250, 0 or 800, 600, 400, 200, 0)
    final double yCeiling = (((maxCalorie / 200).ceil() * 200).toDouble()).clamp(600.0, 1600.0);
    final List<int> yLabels = [
      yCeiling.toInt(),
      (yCeiling * 0.75).toInt(),
      (yCeiling * 0.50).toInt(),
      (yCeiling * 0.25).toInt(),
      0,
    ];

    const double chartBarHeight = 110.0;
    final double selectedRatio = isFutureSelected
        ? 0.0
        : (selectedCal / yCeiling).clamp(0.0, 1.0);
    final double activeLineTop = (chartBarHeight * (1.0 - selectedRatio)).clamp(0.0, chartBarHeight);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graph Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Calorie Burn',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${totalWeeklyBurn.toInt()} kcal total this week',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$selectedDayName: ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isFutureSelected ? 'Upcoming' : '${selectedCal.toInt()} kcal',
                      style: TextStyle(
                        fontSize: 12,
                        color: isFutureSelected ? AppTheme.textSecondary : AppTheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Chart Body: Y-Axis Labels + Dotted Grid Lines + Bar Columns
          SizedBox(
            height: 145,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Y-Axis Labels Column
                SizedBox(
                  width: 34,
                  height: chartBarHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yLabels.map((val) {
                      return Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary.withValues(alpha: 0.65),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: 8),

                // Main Graph Area (Dotted Lines + Active Dotted Line + Bars)
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background Dotted Grid Lines (4 levels)
                      Positioned.fill(
                        bottom: 35,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) {
                            return CustomPaint(
                              size: const Size(double.infinity, 1),
                              painter: DottedLinePainter(
                                color: AppTheme.border.withValues(alpha: 0.7),
                                dashLength: 3.0,
                                gapLength: 3.0,
                              ),
                            );
                          }),
                        ),
                      ),

                      // Active Dynamic Dotted Projection Line from Bar to Y-axis
                      if (!isFutureSelected && selectedCal > 0)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          top: activeLineTop,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  size: const Size(double.infinity, 2),
                                  painter: const DottedLinePainter(
                                    color: AppTheme.primary,
                                    strokeWidth: 1.5,
                                    dashLength: 4.0,
                                    gapLength: 3.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 7 Day Bars (Sun - Sat)
                      Positioned.fill(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (index) {
                            final dayCal = weeklyData[index];
                            final isToday = index == todayIndex;
                            final isFuture = index > todayIndex;
                            final isSelected = index == currentSelected;
                            final double barRatio = isFuture
                                ? 0.0
                                : (dayCal / yCeiling).clamp(0.08, 1.0);

                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDayIndex = index;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Vertical Bar Container Track
                                    Container(
                                      height: chartBarHeight,
                                      alignment: Alignment.bottomCenter,
                                      child: isFuture
                                          ? Container(
                                              width: 14,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: AppTheme.surfaceVariant,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            )
                                          : AnimatedContainer(
                                              duration: const Duration(milliseconds: 400),
                                              curve: Curves.easeOutCubic,
                                              height: chartBarHeight * barRatio,
                                              width: 16,
                                              decoration: BoxDecoration(
                                                color: isSelected || isToday
                                                    ? AppTheme.primary
                                                    : AppTheme.primary.withValues(alpha: 0.35),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: (isSelected || isToday)
                                                    ? [
                                                        BoxShadow(
                                                          color: AppTheme.primary.withValues(alpha: 0.45),
                                                          blurRadius: 8,
                                                          spreadRadius: 1,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                            ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Day Name Label (Sun - Sat)
                                    Text(
                                      _days[index],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isToday || isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: isToday || (isSelected && !isFuture)
                                            ? AppTheme.primary
                                            : isFuture
                                                ? AppTheme.textSecondary.withValues(alpha: 0.35)
                                                : AppTheme.textSecondary,
                                      ),
                                    ),

                                    // Active Day Indicator Dot
                                    Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isToday ? AppTheme.primary : Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sublabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context, WorkoutLoggerItem item) {
    final progress = item.targetSets > 0
        ? (item.completedSets / item.targetSets).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/details/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Category tag + Calories
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      item.category.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.calculatedCalories.toInt()} kcal',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Exercise Name
              Text(
                item.exerciseName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              // Metrics row (Sets, Reps, Weight load)
              Row(
                children: [
                  _buildCardBadge(Icons.repeat, '${item.targetSets} Sets'),
                  const SizedBox(width: 8),
                  _buildCardBadge(Icons.numbers, '${item.repetitions} Reps'),
                  const SizedBox(width: 8),
                  _buildCardBadge(Icons.fitness_center, '${item.weightLoad} kg'),
                ],
              ),

              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: ${item.completedSets}/${item.targetSets} sets done',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
