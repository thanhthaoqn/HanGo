package com.hango.hango_backend.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

/**
 * Deterministic scheduler for Feature B (Smart Time-boxing).
 *
 * v1 rules (deterministic, no external systems):
 * - Split total estimated hours evenly across nodes in order.
 * - Allocate each node its estimated hours as a contiguous block of working days.
 * - deadline for each node is the end of its last working day at 23:59.
 * - start_date is the first working day of the block at 00:00.
 *
 * Note: this class does not need DB; it only computes dates.
 */
public class PathwayTimeboxingScheduler {

  public static final LocalTime START_OF_DAY = LocalTime.MIDNIGHT;
  public static final LocalTime END_OF_DAY = LocalTime.of(23, 59);

  public static class NodeSchedule {
    private final LocalDate startDate;
    private final LocalDate deadline;
    private final int estimatedHours;

    public NodeSchedule(LocalDate startDate, LocalDate deadline, int estimatedHours) {
      this.startDate = startDate;
      this.deadline = deadline;
      this.estimatedHours = estimatedHours;
    }

    public LocalDate getStartDate() {
      return startDate;
    }

    public LocalDate getDeadline() {
      return deadline;
    }

    public int getEstimatedHours() {
      return estimatedHours;
    }
  }

  /**
   * @param targetDate final goal date (deadline for last node)
   * @param hoursPerWeek weekly planned hours
   * @param preferredStudyDays list of DayOfWeek numbers: Mon=1..Sun=7 (optional). If null/empty => Mon..Sat.
   * @param estimatedHoursPerNode total estimated hours for each node; if null/empty -> even distribution by node count
   * @param nodeCount number of nodes to schedule (order matters)
   */
  public static List<NodeSchedule> schedule(
      LocalDate targetDate,
      int hoursPerWeek,
      List<Integer> preferredStudyDays,
      List<Integer> estimatedHoursPerNode,
      int nodeCount
  ) {
    Objects.requireNonNull(targetDate, "targetDate");
    if (nodeCount <= 0) return Collections.emptyList();
    if (hoursPerWeek <= 0) {
      // No capacity: still provide deterministic deadlines = targetDate.
      List<NodeSchedule> out = new ArrayList<>();
      for (int i = 0; i < nodeCount; i++) {
        out.add(new NodeSchedule(targetDate, targetDate, 0));
      }
      return out;
    }

    List<DayOfWeek> workDays = parseWorkDays(preferredStudyDays);
    int workingDaysPerWeek = Math.max(1, workDays.size());

    // Conservative: assume capacity evenly distributed across working days.
    // hoursPerDay = hoursPerWeek / workingDaysPerWeek (floor), remaining hours spread deterministically.
    int baseHoursPerDay = Math.max(1, hoursPerWeek / workingDaysPerWeek);
    int remainderHours = hoursPerWeek - baseHoursPerDay * workingDaysPerWeek;

    List<Integer> nodeHours = resolveNodeHours(estimatedHoursPerNode, nodeCount);
    int totalHours = nodeHours.stream().mapToInt(Integer::intValue).sum();
    if (totalHours <= 0) {
      List<NodeSchedule> out = new ArrayList<>();
      for (int i = 0; i < nodeCount; i++) {
        out.add(new NodeSchedule(targetDate, targetDate, 0));
      }
      return out;
    }

    // Build a deterministic calendar going backwards from targetDate.
    // We will assign node blocks backwards, then reverse.
    List<WorkingDay> calendar = new ArrayList<>();
    calendar = buildBackwardsCalendar(targetDate, workDays, baseHoursPerDay, remainderHours, totalHours);

    // Assign blocks to nodes backwards.
    List<NodeSchedule> reversed = new ArrayList<>();
    int remainingIndex = 0; // Start at NEWEST date (targetDate)

    for (int nodeIdx = nodeCount - 1; nodeIdx >= 0; nodeIdx--) {
      int hoursNeeded = nodeHours.get(nodeIdx);
      if (hoursNeeded <= 0) {
        LocalDate d = (remainingIndex < calendar.size()) ? calendar.get(remainingIndex).date : (calendar.isEmpty() ? targetDate : calendar.get(calendar.size() - 1).date);
        reversed.add(new NodeSchedule(d, d, 0));
        continue;
      }

      int startCalIndex = remainingIndex; // NEWEST date for this node (deadline)
      int hoursTaken = 0;

      // Consume calendar working days until hoursNeeded satisfied.
      while (remainingIndex < calendar.size() && hoursTaken < hoursNeeded) {
        WorkingDay day = calendar.get(remainingIndex);
        hoursTaken += day.hoursCapacity;
        remainingIndex++; // Moves towards OLDEST date
      }

      // deadline = NEWEST date (first day we encountered in this chunk)
      if (startCalIndex >= calendar.size()) {
        startCalIndex = calendar.size() - 1;
      }
      LocalDate deadline = calendar.get(startCalIndex).date;

      // start_date = OLDEST date (last day we used in this chunk)
      int lastUsedIndex = remainingIndex - 1;
      if (lastUsedIndex < 0) lastUsedIndex = 0;
      if (lastUsedIndex >= calendar.size()) lastUsedIndex = calendar.size() - 1;

      LocalDate startDate = calendar.get(lastUsedIndex).date;

      // estimatedHours for node = hoursNeeded (deterministic from input)
      reversed.add(new NodeSchedule(startDate, deadline, hoursNeeded));
    }

    // Reverse to match node order.
    Collections.reverse(reversed);
    return reversed;
  }

  private static List<DayOfWeek> parseWorkDays(List<Integer> preferredStudyDays) {
    if (preferredStudyDays == null || preferredStudyDays.isEmpty()) {
      return List.of(
          DayOfWeek.MONDAY,
          DayOfWeek.TUESDAY,
          DayOfWeek.WEDNESDAY,
          DayOfWeek.THURSDAY,
          DayOfWeek.FRIDAY,
          DayOfWeek.SATURDAY
      );
    }

    List<DayOfWeek> out = new ArrayList<>();
    for (Integer v : preferredStudyDays) {
      if (v == null) continue;
      int n = v;
      // 1..7 => Mon..Sun
      if (n < 1 || n > 7) continue;
      DayOfWeek d = DayOfWeek.of(((n - 1) % 7) + 1);
      if (!out.contains(d)) out.add(d);
    }

    if (out.isEmpty()) {
      return List.of(
          DayOfWeek.MONDAY,
          DayOfWeek.TUESDAY,
          DayOfWeek.WEDNESDAY,
          DayOfWeek.THURSDAY,
          DayOfWeek.FRIDAY,
          DayOfWeek.SATURDAY
      );
    }

    // Deterministic: sort by Monday..Sunday order
    out.sort((a, b) -> Integer.compare(a.getValue(), b.getValue()));
    return out;
  }

  private static List<Integer> resolveNodeHours(List<Integer> estimatedHoursPerNode, int nodeCount) {
    if (estimatedHoursPerNode == null || estimatedHoursPerNode.size() != nodeCount) {
      // Even distribution (deterministic placeholder)
      int base = 3; // minimal units
      List<Integer> out = new ArrayList<>();
      for (int i = 0; i < nodeCount; i++) out.add(base);
      return out;
    }
    List<Integer> out = new ArrayList<>();
    for (Integer h : estimatedHoursPerNode) out.add(h == null ? 0 : Math.max(0, h));
    return out;
  }

  private static List<WorkingDay> buildBackwardsCalendar(
      LocalDate targetDate,
      List<DayOfWeek> workDays,
      int baseHoursPerDay,
      int remainderHoursPerWeek,
      int totalHoursNeeded
  ) {
    // We build as many working days as needed. Deterministically go backwards day-by-day.
    // Capacity per working day cycles deterministically across the set.
    List<WorkingDay> calendar = new ArrayList<>();

    // Precompute capacity per workDay index within a week.
    // If remainderHoursPerWeek > 0, spread +1 to the earliest remainder days.
    int workingDaysPerWeek = workDays.size();
    int[] capacityByWorkDayPos = new int[workingDaysPerWeek];
    for (int i = 0; i < workingDaysPerWeek; i++) {
      capacityByWorkDayPos[i] = baseHoursPerDay;
    }
    for (int i = 0; i < remainderHoursPerWeek; i++) {
      if (i < workingDaysPerWeek) capacityByWorkDayPos[i] += 1;
    }

    int hoursAccumulated = 0;
    LocalDate cursor = targetDate;

    // Safety cap to avoid infinite loops.
    int safety = 0;
    while (hoursAccumulated < totalHoursNeeded && safety < 5000) {
      safety++;
      DayOfWeek dow = cursor.getDayOfWeek();
      int pos = indexOf(workDays, dow);
      if (pos >= 0) {
        int cap = capacityByWorkDayPos[pos];
        calendar.add(new WorkingDay(cursor, cap));
        hoursAccumulated += cap;
      }
      cursor = cursor.minusDays(1);
    }

    // calendar is built backwards (latest -> earliest). We'll use indices from end.
    return calendar;
  }

  public static List<NodeSchedule> scheduleForward(
      LocalDate startDate,
      int hoursPerWeek,
      List<Integer> preferredStudyDays,
      List<Integer> estimatedHoursPerNode,
      int nodeCount
  ) {
    Objects.requireNonNull(startDate, "startDate");
    if (nodeCount <= 0) return Collections.emptyList();
    if (hoursPerWeek <= 0) {
      List<NodeSchedule> out = new ArrayList<>();
      for (int i = 0; i < nodeCount; i++) {
        out.add(new NodeSchedule(startDate, startDate, 0));
      }
      return out;
    }

    List<DayOfWeek> workDays = parseWorkDays(preferredStudyDays);
    int workingDaysPerWeek = Math.max(1, workDays.size());

    int baseHoursPerDay = Math.max(1, hoursPerWeek / workingDaysPerWeek);
    int remainderHours = hoursPerWeek - baseHoursPerDay * workingDaysPerWeek;

    List<Integer> nodeHours = resolveNodeHours(estimatedHoursPerNode, nodeCount);
    int totalHours = nodeHours.stream().mapToInt(Integer::intValue).sum();
    if (totalHours <= 0) {
      List<NodeSchedule> out = new ArrayList<>();
      for (int i = 0; i < nodeCount; i++) {
        out.add(new NodeSchedule(startDate, startDate, 0));
      }
      return out;
    }

    List<WorkingDay> calendar = buildForwardsCalendar(startDate, workDays, baseHoursPerDay, remainderHours, totalHours);

    List<NodeSchedule> out = new ArrayList<>();
    int remainingIndex = 0; // Start at OLDEST date (startDate)

    for (int nodeIdx = 0; nodeIdx < nodeCount; nodeIdx++) {
      int hoursNeeded = nodeHours.get(nodeIdx);
      if (hoursNeeded <= 0) {
        LocalDate d = (remainingIndex < calendar.size()) ? calendar.get(remainingIndex).date : (calendar.isEmpty() ? startDate : calendar.get(calendar.size() - 1).date);
        out.add(new NodeSchedule(d, d, 0));
        continue;
      }

      int startCalIndex = remainingIndex;
      int hoursTaken = 0;

      while (remainingIndex < calendar.size() && hoursTaken < hoursNeeded) {
        WorkingDay day = calendar.get(remainingIndex);
        hoursTaken += day.hoursCapacity;
        remainingIndex++;
      }

      if (startCalIndex >= calendar.size()) {
        startCalIndex = calendar.size() - 1;
      }
      LocalDate nodeStartDate = calendar.get(startCalIndex).date;

      int lastUsedIndex = remainingIndex - 1;
      if (lastUsedIndex < 0) lastUsedIndex = 0;
      if (lastUsedIndex >= calendar.size()) lastUsedIndex = calendar.size() - 1;

      LocalDate nodeDeadline = calendar.get(lastUsedIndex).date;

      out.add(new NodeSchedule(nodeStartDate, nodeDeadline, hoursNeeded));
    }

    return out;
  }

  private static List<WorkingDay> buildForwardsCalendar(
      LocalDate startDate,
      List<DayOfWeek> workDays,
      int baseHoursPerDay,
      int remainderHoursPerWeek,
      int totalHoursNeeded
  ) {
    List<WorkingDay> calendar = new ArrayList<>();

    int workingDaysPerWeek = workDays.size();
    int[] capacityByWorkDayPos = new int[workingDaysPerWeek];
    for (int i = 0; i < workingDaysPerWeek; i++) {
      capacityByWorkDayPos[i] = baseHoursPerDay;
    }
    for (int i = 0; i < remainderHoursPerWeek; i++) {
      if (i < workingDaysPerWeek) capacityByWorkDayPos[i] += 1;
    }

    int hoursAccumulated = 0;
    LocalDate cursor = startDate;

    int safety = 0;
    while (hoursAccumulated < totalHoursNeeded && safety < 5000) {
      safety++;
      DayOfWeek dow = cursor.getDayOfWeek();
      int pos = indexOf(workDays, dow);
      if (pos >= 0) {
        int cap = capacityByWorkDayPos[pos];
        calendar.add(new WorkingDay(cursor, cap));
        hoursAccumulated += cap;
      }
      cursor = cursor.plusDays(1);
    }

    return calendar;
  }

  private static int indexOf(List<DayOfWeek> days, DayOfWeek d) {
    for (int i = 0; i < days.size(); i++) {
      if (days.get(i) == d) return i;
    }
    return -1;
  }

  private static class WorkingDay {
    private final LocalDate date;
    private final int hoursCapacity;

    private WorkingDay(LocalDate date, int hoursCapacity) {
      this.date = date;
      this.hoursCapacity = hoursCapacity;
    }
  }
}

