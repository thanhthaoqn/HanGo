package com.hango.hango_backend.service;

import com.hango.hango_backend.dto.ProgressSnapshotDTO;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class PathwayReroutePolicyService {

    public enum PolicyAction {
        FAST_TRACK_ELIGIBLE,
        DETOUR_REQUIRED,
        NO_CHANGE
    }

    public static class PolicyDecision {
        public PolicyAction action;
        public ProgressSnapshotDTO.NodeSnapshotDTO targetNode;
        public String reason;

        public PolicyDecision(PolicyAction action, ProgressSnapshotDTO.NodeSnapshotDTO targetNode, String reason) {
            this.action = action;
            this.targetNode = targetNode;
            this.reason = reason;
        }
    }

    public PolicyDecision evaluate(ProgressSnapshotDTO snapshot) {
        if (snapshot == null || snapshot.getNodesSnapshot() == null || snapshot.getNodesSnapshot().isEmpty()) {
            return new PolicyDecision(PolicyAction.NO_CHANGE, null, null);
        }

        // Uu tien kiem tra DETOUR truoc: node dang hoc ma thi quiz that bai >= 2 lan lien tiep
        // -> can chen khoa remedial de hoc lai
        for (ProgressSnapshotDTO.NodeSnapshotDTO node : snapshot.getNodesSnapshot()) {
            if ("IN_PROGRESS".equalsIgnoreCase(node.getStatus()) && node.getFailStreak() != null && node.getFailStreak() >= 2) {
                return new PolicyDecision(
                        PolicyAction.DETOUR_REQUIRED,
                        node,
                        "Learner has failed the quizzes " + node.getFailStreak() + " times consecutively."
                );
            }
        }

        // FAST_TRACK: buoc truoc hoan thanh voi diem 100/100 va buoc ke tiep khong trung skill yeu
        // -> cho phep bo qua buoc ke tiep
        for (int i = 0; i < snapshot.getNodesSnapshot().size(); i++) {
            ProgressSnapshotDTO.NodeSnapshotDTO node = snapshot.getNodesSnapshot().get(i);
            
            if ("COMPLETED".equalsIgnoreCase(node.getStatus()) && node.getLatestScore() != null && node.getLatestScore() == 100.0) {
                // If next step exists and has no weak skill overlap
                if (i + 1 < snapshot.getNodesSnapshot().size()) {
                    ProgressSnapshotDTO.NodeSnapshotDTO nextNode = snapshot.getNodesSnapshot().get(i + 1);
                    if ("LOCKED".equalsIgnoreCase(nextNode.getStatus()) || "IN_PROGRESS".equalsIgnoreCase(nextNode.getStatus())) {
                        if (Boolean.FALSE.equals(nextNode.getHasWeakSkillOverlap())) {
                            return new PolicyDecision(
                                    PolicyAction.FAST_TRACK_ELIGIBLE,
                                    nextNode,
                                    "Excellent performance on previous step. Eligible to skip this step."
                            );
                        }
                    }
                }
            }
        }

        return new PolicyDecision(PolicyAction.NO_CHANGE, null, null);
    }
}
