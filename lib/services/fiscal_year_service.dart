class FiscalYearService {
  static bool isLocked(DateTime date, int startMonth, int closingDay) {
    final now = DateTime.now();
    final boundary = DateTime(now.year, startMonth, closingDay);
    final latestClosed = now.isBefore(boundary)
        ? DateTime(now.year - 1, startMonth, closingDay)
        : boundary;
    return date.isBefore(latestClosed);
  }
}
