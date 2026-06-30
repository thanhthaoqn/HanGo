package com.hango.hango_backend.dto;

public class TrainerLeadDashboardStatsDto {
    private long registeredUsers;
    private double userGrowthPercentage;
    private long totalCourses;
    private long activeCourses;
    private long inactiveCourses;
    private long assignedTasks;
    private long pendingApprovals;

    public TrainerLeadDashboardStatsDto() {
    }

    public TrainerLeadDashboardStatsDto(long registeredUsers, double userGrowthPercentage, long totalCourses, long activeCourses, long inactiveCourses, long assignedTasks, long pendingApprovals) {
        this.registeredUsers = registeredUsers;
        this.userGrowthPercentage = userGrowthPercentage;
        this.totalCourses = totalCourses;
        this.activeCourses = activeCourses;
        this.inactiveCourses = inactiveCourses;
        this.assignedTasks = assignedTasks;
        this.pendingApprovals = pendingApprovals;
    }

    public long getRegisteredUsers() {
        return registeredUsers;
    }

    public void setRegisteredUsers(long registeredUsers) {
        this.registeredUsers = registeredUsers;
    }

    public double getUserGrowthPercentage() {
        return userGrowthPercentage;
    }

    public void setUserGrowthPercentage(double userGrowthPercentage) {
        this.userGrowthPercentage = userGrowthPercentage;
    }

    public long getTotalCourses() {
        return totalCourses;
    }

    public void setTotalCourses(long totalCourses) {
        this.totalCourses = totalCourses;
    }

    public long getActiveCourses() {
        return activeCourses;
    }

    public void setActiveCourses(long activeCourses) {
        this.activeCourses = activeCourses;
    }

    public long getInactiveCourses() {
        return inactiveCourses;
    }

    public void setInactiveCourses(long inactiveCourses) {
        this.inactiveCourses = inactiveCourses;
    }

    public long getAssignedTasks() {
        return assignedTasks;
    }

    public void setAssignedTasks(long assignedTasks) {
        this.assignedTasks = assignedTasks;
    }

    public long getPendingApprovals() {
        return pendingApprovals;
    }

    public void setPendingApprovals(long pendingApprovals) {
        this.pendingApprovals = pendingApprovals;
    }
}
