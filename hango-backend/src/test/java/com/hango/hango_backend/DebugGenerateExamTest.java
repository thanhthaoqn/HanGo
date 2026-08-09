
package com.hango.hango_backend;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import com.hango.hango_backend.service.CourseManagerExamMatrixService;
@SpringBootTest
public class DebugGenerateExamTest {
    @Autowired
    private CourseManagerExamMatrixService service;
    @Test
    public void testGenerate() {
        try {
            Long examId = service.generateExamFromMatrix(21L, "Debug Exam", "Test", null, 5.0, 60, "hoanglead@hango.edu.vn");
            System.out.println("EXAM GENERATED WITH ID: " + examId);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

