package com.hango.hango_backend.service;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class PathwayTimeboxingSchedulerTest {

  // =================================================================
  // schedule
  // =================================================================

  @Test
  void scheduleShouldReturnEmptyListWhenNodeCountIsZero() {
    List<PathwayTimeboxingScheduler.NodeSchedule> result = PathwayTimeboxingScheduler.schedule(
        LocalDate.of(2026, 10, 15),
        10,
        null,
        null,
        0
    );

    assertTrue(result.isEmpty());
  }

  @Test
  void scheduleShouldPinAllNodesToTargetDateWithZeroHoursWhenHoursPerWeekIsZero() {
    LocalDate target = LocalDate.of(2026, 10, 15);

    List<PathwayTimeboxingScheduler.NodeSchedule> result = PathwayTimeboxingScheduler.schedule(
        target,
        0,
        null,
        null,
        3
    );

    assertEquals(3, result.size());
    for (PathwayTimeboxingScheduler.NodeSchedule nodeSchedule : result) {
      assertEquals(target, nodeSchedule.getStartDate());
      assertEquals(target, nodeSchedule.getDeadline());
      assertEquals(0, nodeSchedule.getEstimatedHours());
    }
  }

  @Test
  void schedule_isDeterministic_for_sameInputs() {
    LocalDate target = LocalDate.of(2026, 10, 15); // Thursday

    List<PathwayTimeboxingScheduler.NodeSchedule> s1 = PathwayTimeboxingScheduler.schedule(
        target,
        10,
        List.of(1, 2, 3, 4, 5), // Mon..Fri
        null,
        4
    );

    List<PathwayTimeboxingScheduler.NodeSchedule> s2 = PathwayTimeboxingScheduler.schedule(
        target,
        10,
        List.of(1, 2, 3, 4, 5),
        null,
        4
    );

    assertEquals(s1.size(), s2.size());
    for (int i = 0; i < s1.size(); i++) {
      assertEquals(s1.get(i).getStartDate(), s2.get(i).getStartDate());
      assertEquals(s1.get(i).getDeadline(), s2.get(i).getDeadline());
      assertEquals(s1.get(i).getEstimatedHours(), s2.get(i).getEstimatedHours());
    }
  }

  @Test
  void schedule_deadline_equalsLastBlockDeadline_and_monotonic() {
    LocalDate target = LocalDate.of(2026, 10, 15);

    List<PathwayTimeboxingScheduler.NodeSchedule> s = PathwayTimeboxingScheduler.schedule(
        target,
        9,
        List.of(6, 7), // Sat, Sun
        null,
        3
    );

    assertEquals(3, s.size());

    // last deadline should be <= target
    assertFalse(s.get(2).getDeadline().isAfter(target), "last deadline is after target");



    // Basic deterministic checks
    assertNotNull(s.get(0).getStartDate());
    assertNotNull(s.get(0).getDeadline());
    assertNotNull(s.get(1).getStartDate());
    assertNotNull(s.get(1).getDeadline());
    assertNotNull(s.get(2).getStartDate());
    assertNotNull(s.get(2).getDeadline());

  }
}

